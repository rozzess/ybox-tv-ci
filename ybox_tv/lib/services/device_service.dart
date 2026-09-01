import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Answers "is this a TV?" once at startup (`ybox/device` channel,
/// MainActivity.kt). TVs get a landscape-locked app; phones keep the
/// portrait shell. Real Android TV reports itself, and boxes that don't
/// are caught by having no touchscreen.
class DeviceService {
  static const _channel = MethodChannel('ybox/device');

  /// Baked into the TV-box APK (`--dart-define=YBOX_TV=true`): runtime
  /// detection can't be trusted — cheap AOSP boxes report themselves as
  /// touch phones — so the dedicated TV build never asks.
  static const bool _tvBuild = bool.fromEnvironment('YBOX_TV');

  /// Resolved by [init] before runApp; false on iOS and on any error.
  static bool isTv = _tvBuild;

  static Future<void> init() async {
    if (_tvBuild ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      isTv = await _channel.invokeMethod('isTv') == true;
    } catch (_) {
      // Old native shell — treat as a phone.
    }
  }
}
