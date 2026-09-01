import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // media_kit renders into a texture, so iOS doesn't know video is playing
    // and would dim/lock the screen mid-stream. The player screen holds this
    // flag while it's open.
    if let controller = window?.rootViewController as? FlutterViewController {
      let wakeChannel = FlutterMethodChannel(
        name: "ybox/wake", binaryMessenger: controller.binaryMessenger)
      wakeChannel.setMethodCallHandler { call, result in
        if call.method == "keepOn" {
          UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
