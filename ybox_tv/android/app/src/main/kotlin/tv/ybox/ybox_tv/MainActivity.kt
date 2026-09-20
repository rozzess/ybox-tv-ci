package tv.ybox.ybox_tv

import android.app.PictureInPictureParams
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.PowerManager
import android.util.Rational
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var wakeChannel: MethodChannel? = null

    // True while the player screen is open and playing — pressing Home then
    // shrinks the app into a floating mini-window instead of stopping.
    private var pipWanted = false

    // True while the player screen is open. Re-applied on resume (below).
    private var wakeWanted = false
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ybox/pip")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setActive" -> {
                    pipWanted = call.arguments as? Boolean ?: false
                    result.success(null)
                }
                "enter" -> result.success(enterPip())
                else -> result.notImplemented()
            }
        }
        // media_kit renders into a texture, so Android doesn't know video is
        // playing and would dim/sleep the screen mid-stream. The player
        // screen holds this while it's open. Cheap set-top boxes sometimes
        // ignore the window flag alone, so we belt-and-suspenders it with a
        // PowerManager wake lock (WAKE_LOCK permission) too.
        wakeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ybox/wake")
        wakeChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "keepOn" -> {
                    wakeWanted = call.arguments as? Boolean ?: false
                    applyWake(wakeWanted)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ybox/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTv" -> result.success(isTvDevice())
                    else -> result.notImplemented()
                }
            }
    }

    // Real Android TV reports TELEVISION ui-mode / leanback, but cheap AOSP
    // set-top boxes often report neither — "no touchscreen" catches those.
    private fun isTvDevice(): Boolean {
        val uiMode = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        if (uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) return true
        return packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            !packageManager.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
    }

    // Two mechanisms keep the screen on while the player is open:
    // FLAG_KEEP_SCREEN_ON is the recommended one, but some box firmware
    // ignores it — the FULL_WAKE_LOCK covers those. Idempotent, so the Dart
    // watchdog can re-assert safely. The lock is dropped on pause (Home/PiP)
    // so the box can sleep normally when we're not on screen, and re-applied
    // on resume if the player still wants it.
    private fun applyWake(on: Boolean) {
        if (on) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val lock = wakeLock
            if (lock == null || !lock.isHeld) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(PowerManager.FULL_WAKE_LOCK, "ybox::player")
                    .apply { acquire() }
            }
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            wakeLock?.let { if (it.isHeld) it.release() }
            wakeLock = null
        }
    }

    override fun onPause() {
        super.onPause()
        wakeLock?.let { if (it.isHeld) it.release() }
    }

    override fun onResume() {
        super.onResume()
        if (wakeWanted) applyWake(true)
    }

    private fun enterPip(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            enterPictureInPictureMode(
                PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(16, 9))
                    .build()
            )
        } catch (e: Exception) {
            false
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (pipWanted) enterPip()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channel?.invokeMethod("pipChanged", isInPictureInPictureMode)
    }
}
