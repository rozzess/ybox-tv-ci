import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to the Android picture-in-picture mini-window (MainActivity).
///
/// While [setActive] is true, pressing Home with the player open shrinks the
/// app into a floating window (like TikTok/YouTube) instead of stopping
/// playback. iOS has no PiP surface for this engine — there the app keeps
/// the AUDIO playing in the background instead (UIBackgroundModes).
class PipService {
  static const _channel = MethodChannel('ybox/pip');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Set by the player screen; fired when the OS moves the app in/out of
  /// the mini-window so the UI can hide/restore its controls.
  static void Function(bool inPip)? onChanged;

  static void init() {
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pipChanged') onChanged?.call(call.arguments == true);
    });
  }

  static Future<void> setActive(bool active) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('setActive', active);
    } catch (_) {}
  }

  /// Immediately enter the mini-window. Returns false when unsupported.
  static Future<bool> enter() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod('enter') == true;
    } catch (_) {
      return false;
    }
  }
}
