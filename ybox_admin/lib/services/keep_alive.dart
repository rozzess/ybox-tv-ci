import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// iOS background keep-alive (SPEC 6.3): loop a silent audio asset at zero
/// volume so iOS keeps the app — and its realtime Firestore listeners
/// (devices, chat, playlists) — alive when the screen is off or the app is
/// backgrounded. Requires UIBackgroundModes: [audio].
///
/// No-op on other platforms: backgrounding a desktop window doesn't kill
/// Firestore listeners, and just_audio has no desktop implementation anyway
/// (constructing [AudioPlayer] there throws, which would crash the admin app
/// at startup on Windows). The player is created lazily so the import stays
/// available on all platforms.
class KeepAlive {
  AudioPlayer? _player;
  bool _configured = false;
  bool active = false;

  Future<void> start() async {
    if (active) return;
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      if (!_configured) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.media,
          ),
        ));
        _player ??= AudioPlayer();
        await _player!.setAsset('assets/silence.wav');
        await _player!.setLoopMode(LoopMode.one);
        await _player!.setVolume(0);
        _configured = true;
      }
      _player?.play();
      active = true;
    } catch (_) {
      // Keep-alive is best-effort; the server still runs in the foreground.
      active = false;
    }
  }

  Future<void> stop() async {
    if (!active) return;
    try {
      await _player?.pause();
    } catch (_) {}
    active = false;
  }

  Future<void> dispose() async {
    await _player?.dispose();
  }
}
