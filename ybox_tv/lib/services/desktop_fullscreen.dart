import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop-only fullscreen for the player (Windows/macOS/Linux). On Android,
/// iOS and web the player route already covers the whole app or tab, so every
/// call is a guarded no-op there — no channel exists to talk to.
class DesktopFullscreen {
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static Future<bool> isFullscreen() async {
    if (!supported) return false;
    try {
      return await windowManager.isFullScreen();
    } catch (_) {
      return false;
    }
  }

  static Future<void> setFullscreen(bool value) async {
    if (!supported) return;
    try {
      await windowManager.setFullScreen(value);
    } catch (_) {
      // Window manager not wired up (e.g. spawned in a test) — ignore.
    }
  }
}