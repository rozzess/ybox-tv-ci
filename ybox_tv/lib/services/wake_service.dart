import 'dart:async';

import 'package:flutter/services.dart';

/// Keeps the screen awake while the player is open.
///
/// media_kit renders into a texture, so the OS has no idea video is playing
/// and dims/sleeps the screen mid-stream (worst on TV boxes with short sleep
/// timers). Android sets FLAG_KEEP_SCREEN_ON *and* holds a PowerManager wake
/// lock (some box firmware only honors the lock) and re-applies both on
/// resume; iOS disables the idle timer. Both sides are in the native shells
/// (MainActivity.kt / AppDelegate.swift) on the `ybox/wake` channel.
class WakeService {
  static const _channel = MethodChannel('ybox/wake');
  static Timer? _watchdog;

  static Future<void> keepOn(bool on) async {
    await _send(on);
    _watchdog?.cancel();
    if (on) {
      // Some boxes drop the keep-awake state when the window is recreated or
      // a vendor power-saver pokes it mid-stream (mpv-android hit the same
      // bug — the flag can silently fail to apply on first playback). Re-assert
      // every 30s so the screen stays on for the whole stream even if an
      // earlier call was lost.
      _watchdog =
          Timer.periodic(const Duration(seconds: 30), (_) => _send(true));
    } else {
      _watchdog = null;
    }
  }

  static Future<void> _send(bool on) async {
    try {
      await _channel.invokeMethod('keepOn', on);
    } catch (_) {
      // Best-effort — the screen may just sleep on an old native shell.
    }
  }
}
