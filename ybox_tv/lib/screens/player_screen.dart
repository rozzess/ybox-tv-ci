import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/models.dart';
import '../services/device_service.dart';
import '../services/pip_service.dart';
import '../services/subtitle_service.dart';
import '../services/wake_service.dart';
import '../services/xtream_api.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/cast_sheet.dart';
import '../widgets/tv_focusable.dart';

/// How the video is laid out inside the screen.
enum _FitMode { fit, fill, stretch, zoom }

extension _FitModeX on _FitMode {
  String get label {
    switch (this) {
      case _FitMode.fit:
        return 'Fit';
      case _FitMode.fill:
        return 'Fill';
      case _FitMode.stretch:
        return 'Stretch';
      case _FitMode.zoom:
        return 'Zoom 1.3×';
    }
  }

  IconData get icon {
    switch (this) {
      case _FitMode.fit:
        return Icons.fit_screen_rounded;
      case _FitMode.fill:
        return Icons.zoom_out_map_rounded;
      case _FitMode.stretch:
        return Icons.aspect_ratio_rounded;
      case _FitMode.zoom:
        return Icons.zoom_in_rounded;
    }
  }
}

/// Orientation lock cycled by the rotate button.
enum _RotationMode { auto, landscape, portrait }

extension _RotationModeX on _RotationMode {
  String get label {
    switch (this) {
      case _RotationMode.auto:
        return 'Auto rotate';
      case _RotationMode.landscape:
        return 'Landscape locked';
      case _RotationMode.portrait:
        return 'Portrait locked';
    }
  }

  IconData get icon {
    switch (this) {
      case _RotationMode.auto:
        return Icons.screen_rotation_rounded;
      case _RotationMode.landscape:
        return Icons.screen_lock_landscape_rounded;
      case _RotationMode.portrait:
        return Icons.screen_lock_portrait_rounded;
    }
  }

  List<DeviceOrientation> get orientations {
    switch (this) {
      case _RotationMode.auto:
        return const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
      case _RotationMode.landscape:
        return const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
      case _RotationMode.portrait:
        return const [DeviceOrientation.portraitUp];
    }
  }
}

/// Full-screen player with auto-hiding Xbox-styled controls.
///
/// Playback runs on media_kit (libmpv/FFmpeg) so raw MPEG-TS, HLS, MKV and
/// the other containers IPTV servers actually serve all play on both
/// platforms — the stock AVPlayer/ExoPlayer path choked on most of them.
class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final String? overrideUrl; // for series episodes
  final String? overrideTitle;

  const PlayerScreen({
    super.key,
    required this.channel,
    this.overrideUrl,
    this.overrideTitle,
  });

  static Future<void> open(BuildContext context, Channel channel,
      {String? url, String? title}) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PlayerScreen(
            channel: channel, overrideUrl: url, overrideTitle: title),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final Player _player = Player(
    // Generous demuxer buffer: weak IPTV connections stutter less. TV boxes
    // get half — many have 1 GB RAM total and the OS kills the app under
    // memory pressure; 16 MB still holds ~10s+ of a typical stream.
    configuration: PlayerConfiguration(
        bufferSize: (DeviceService.isTv ? 16 : 32) * 1024 * 1024),
  );
  late final VideoController _video = VideoController(
    _player,
    // Attach the Android surface immediately: waiting for video-params
    // leaves a black screen with working audio on some devices/GPUs.
    //
    // On TV boxes (typically weak Amlogic CPU/GPU) media_kit's default
    // `hwdec=auto-safe` keeps falling back to SOFTWARE decoding for HEVC,
    // which can't keep up — every channel plays in slow motion. Force the
    // MediaCodec surface path (`hwdec=mediacodec`, zero-copy, no CPU
    // copyback) up front, before the render context exists, so hardware
    // is engaged from the first frame. Phones/iOS/web keep the stock
    // auto/auto-safe scheme (see also _tunePlayer's comment).
    configuration: VideoControllerConfiguration(
      hwdec: DeviceService.isTv ? 'mediacodec' : null,
      androidAttachSurfaceAfterVideoParameters: false,
    ),
  );
  final List<StreamSubscription> _subs = [];

  bool _ready = false; // first video frame dimensions arrived
  // High-frequency playback state lives in notifiers so a position tick
  // (several per second) repaints only the widgets that show it — a full
  // setState rebuild of the player stack on every tick visibly stutters
  // weak devices like TV boxes.
  final ValueNotifier<bool> _buffering = ValueNotifier(true);
  final ValueNotifier<bool> _playing = ValueNotifier(false);
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);
  bool _error = false;
  String? _errorMessage;
  int? _pendingResumeMs;
  Timer? _openTimeout;
  // Embedded audio/subtitle tracks reported by the demuxer (MKV VOD etc.).
  // Empty on web/hls.js — the pickers hide themselves then.
  Tracks _tracks = const Tracks();

  bool _showControls = true;
  bool _inPip = false; // Android mini-window: render video only
  Timer? _hideTimer;
  AppState? _appState;

  /// TV remote: requested when the controls are revealed so D-pad traversal
  /// lands on the control buttons (audio/subtitle included) instead of
  /// wandering from the root node.
  final FocusNode _controlsFocus = FocusNode(debugLabel: 'player-controls');

  /// TV remote entry point into the seek bar (VOD only). On TV, controls open
  /// straight onto this so left/right = jump 30s instead of the player
  /// landing on the top bar and burying the transport.
  final FocusNode _transportFocus = FocusNode(debugLabel: 'player-transport');

  /// When set, replaces the channel URL (used by "Try alternate format").
  String? _formatOverrideUrl;
  bool _autoTriedAlternate = false;

  // ---- Online subtitles (OpenSubtitles) ----

  /// The content is a movie or a TV episode (not a live channel) — the only
  /// kind worth downloading subtitle tracks for.
  bool get _isVod => !_isLive;

  /// A clean title to search OpenSubtitles with. Series episodes come in as
  /// "Show · S1 E5" from the series detail screen; movies may carry a year.
  String _subtitleQuery() {
    var t = _title;
    if (t.contains(' · S')) t = t.split(' · ').first;
    t = t.replaceFirst(RegExp(r'\[S\d+E\d+\]\s*$', caseSensitive: false), '');
    t = t.replaceFirst(RegExp(r'\s*\(\d{4}\)\s*$'), '');
    return t.trim();
  }

  void _showSubtitleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141416),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SubtitleSheet(
        query: _subtitleQuery(),
        player: _player,
      ),
    );
  }

  _FitMode _fitMode = _FitMode.fit;
  _RotationMode _rotationMode = _RotationMode.auto;

  /// Transient centered label ("Fill", "Landscape locked", ...).
  String? _overlayLabel;
  Timer? _overlayTimer;

  // Pinch zoom / pan.
  final TransformationController _viewCtrl = TransformationController();
  late final AnimationController _zoomAnim;
  Animation<Matrix4>? _zoomTween;
  Offset _doubleTapPos = Offset.zero;
  bool _zoomed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = AppScope.read(context);
  }

  String get _url =>
      _formatOverrideUrl ?? widget.overrideUrl ?? widget.channel.streamUrl;

  /// Swaps .ts <-> .m3u8 on the current URL, if it ends with either.
  String? get _alternateUrl {
    final u = _url;
    if (u.endsWith('.m3u8')) {
      return '${u.substring(0, u.length - 5)}.ts';
    }
    if (u.endsWith('.ts')) {
      return '${u.substring(0, u.length - 3)}.m3u8';
    }
    return null;
  }

  void _tryAlternateFormat() {
    final alt = _alternateUrl;
    if (alt == null) return;
    _formatOverrideUrl = alt;
    _init();
  }

  String get _title => widget.overrideTitle ?? widget.channel.name;
  bool get _isLive => widget.channel.type == ContentType.live;

  @override
  void initState() {
    super.initState();
    // TVs are landscape-locked at app level — never touch orientation there.
    if (!DeviceService.isTv) {
      SystemChrome.setPreferredOrientations(_rotationMode.orientations);
    }
    _zoomAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        final t = _zoomTween;
        if (t != null) _viewCtrl.value = t.value;
      });
    _viewCtrl.addListener(_onViewChanged);
    // Home button → floating mini-window (Android); controls hide in PiP.
    PipService.onChanged = (inPip) {
      if (mounted) {
        setState(() {
          _inPip = inPip;
          if (inPip) _showControls = false;
        });
      }
    };
    unawaited(PipService.setActive(true));
    // Screen must not dim/sleep while watching — held until dispose.
    unawaited(WakeService.keepOn(true));
    _listenPlayer();
    unawaited(_tunePlayer());
    unawaited(_openWithAudioSession());
  }

  /// iOS: a *playback* AVAudioSession must be active before the stream
  /// opens — the default ambient category is silenced by the ring/silent
  /// switch, which reads as "video plays but no sound". Also keeps audio
  /// running when the app is minimized (with UIBackgroundModes audio).
  /// Android: the same configure() claims audio focus, so another app
  /// holding it (common on TV boxes) can't keep the stream silent.
  Future<void> _openWithAudioSession() async {
    if (!kIsWeb) {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
        await session.setActive(true);
      } catch (_) {
        // Playback still works; audio focus / silent switch may mute it.
      }
    }
    await _init();
  }

  /// mpv tuning: open streams faster and survive flaky IPTV servers.
  Future<void> _tunePlayer() async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    // `dynamic` here on purpose: the web build swaps NativePlayer for a stub
    // class without setProperty (mpv doesn't exist in the browser), and the
    // is-check above already guarantees we only ever run on native.
    final native = platform as dynamic;
    try {
      // Hardware-accelerated decode: media_kit never sets `hwdec`, so libmpv
      // would default to SOFTWARE decoding — TV boxes can't software-decode
      // HEVC live streams in real time and playback runs in slow motion.
      // `auto` picks `mediacodec-copy` on `vo=gpu`, whose CPU copyback is
      // still too slow on Amlogic boxes, so the TV build forces the surface
      // path `mediacodec` (matches the VideoControllerConfiguration above);
      // phones/iOS/web keep the safe `auto` (mediacodec/videotoolbox/d3d11va,
      // falling back to software when a hardware path can't init).
      await native
          .setProperty('hwdec', DeviceService.isTv ? 'mediacodec' : 'auto');
      await native.setProperty('hwdec-codecs',
          DeviceService.isTv ? 'h264,hevc,av1' : 'all');
      // Never let a decoding/rendering bottleneck turn playback into slow
      // motion: if the box can't present every frame, drop them instead of
      // crawling (audio stays in sync, video just skips frames).
      await native.setProperty('framedrop', 'vo');
      // Probe less before starting — streams open in a fraction of the time.
      await native.setProperty('demuxer-lavf-analyzeduration', '1');
      await native.setProperty('demuxer-lavf-probesize', '500000');
      // Read ahead so brief bandwidth dips don't pause playback.
      await native.setProperty('cache', 'yes');
      await native.setProperty('demuxer-readahead-secs', '15');
      // Reconnect dropped HTTP streams automatically.
      await native.setProperty('stream-lavf-o',
          'reconnect=1,reconnect_streamed=1,reconnect_delay_max=4');
      await native.setProperty('network-timeout', '15');
    } catch (_) {
      // Tuning is best-effort — playback works without it.
    }
  }

  void _listenPlayer() {
    _subs.add(_player.stream.playing.listen((v) {
      _playing.value = v;
      if (v) _markReady();
    }));
    _subs.add(_player.stream.buffering.listen((v) => _buffering.value = v));
    _subs.add(_player.stream.position.listen((v) => _position.value = v));
    _subs.add(_player.stream.duration.listen(_onDuration));
    _subs.add(_player.stream.width.listen((w) {
      if (w != null && w > 0) _markReady();
    }));
    _subs.add(_player.stream.error.listen((message) {
      // Errors after the stream is up (brief network blips) are non-fatal —
      // mpv keeps retrying. Only a failure to open counts.
      if (!_ready) _onLoadFailure(message);
    }));
    _subs.add(_player.stream.tracks.listen((t) {
      if (mounted) setState(() => _tracks = t);
    }));
  }

  /// A stream is "up" once we know its video dimensions, its duration, or
  /// that it is actually playing. On web the dimension event can lag or
  /// never fire for some media, which would otherwise leave a playing movie
  /// without its seek bar — playing/duration are just as good a signal.
  void _markReady() {
    if (_ready || !mounted) return;
    setState(() => _ready = true);
    _openTimeout?.cancel();
    // Some devices start the audio output muted — force it audible.
    unawaited(_player.setVolume(100));
    unawaited(_appState?.adminSync.reportWatching(_title));
    _scheduleHide();
  }

  void _onDuration(Duration v) {
    // media_kit's web player reports an "unknown" duration (live streams,
    // chunked files without a length) as a huge negative sentinel — treat it
    // as unknown instead of feeding the seek bar a broken value.
    if (v <= Duration.zero) {
      _duration.value = Duration.zero;
      return;
    }
    _duration.value = v;
    _markReady();
    final resume = _pendingResumeMs;
    if (resume != null) {
      _pendingResumeMs = null;
      _player.seek(Duration(milliseconds: resume));
    }
  }

  void _onLoadFailure(String message) {
    if (!mounted || _error) return;
    _openTimeout?.cancel();
    if (!_autoTriedAlternate && _alternateUrl != null && !kIsWeb) {
      // Many panels serve only one live container (.ts or .m3u8) — try the
      // other one automatically before bothering the user. Browsers cannot
      // play raw MPEG-TS, so on web the alternate is a guaranteed second
      // failure that only delays the real error — skip it.
      _autoTriedAlternate = true;
      _formatOverrideUrl = _alternateUrl;
      _init();
      return;
    }
    setState(() {
      _error = true;
      _errorMessage = message;
    });
    unawaited(_explainFailure());
    if (kIsWeb) unawaited(_probeWebFailure());
  }

  /// The browser's HLS player reports almost nothing on failure (the video
  /// element's error message is empty), so probe the stream URL directly and
  /// replace the generic text with the real cause: the proxy worker's status
  /// and upstream error body, or a network failure. Web only — native mpv
  /// already reports meaningful errors.
  Future<void> _probeWebFailure() async {
    final url = _url;
    if (url.isEmpty) return;
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (!mounted || !_error) return;
      final body = res.body.trim();
      final snippet = body.length > 200 ? body.substring(0, 200) : body;
      String msg;
      if (res.statusCode == 200) {
        msg = snippet.startsWith('#EXTM3U')
            ? 'The stream playlist loads, but playback could not start in '
                'this browser (codec or connection issue).'
            : 'The stream server returned HTTP 200 but no playable playlist.';
      } else {
        msg = snippet.isNotEmpty
            ? 'Stream server error (HTTP ${res.statusCode}): $snippet'
            : 'Stream server refused the request (HTTP ${res.statusCode}).';
      }
      setState(() => _errorMessage = msg);
    } catch (_) {
      if (!mounted || !_error) return;
      setState(() => _errorMessage = 'Could not reach the stream server '
          'from your location. Check your internet connection and try again.');
    }
  }

  /// Replaces the generic engine error with the real reason when the panel
  /// can tell us — nearly always a shared account already streaming
  /// elsewhere (most accounts allow 1 concurrent device).
  Future<void> _explainFailure() async {
    final p = _appState?.active;
    if (p == null || p.kind != PlaylistKind.xtream) return;
    final s = await XtreamApi.fromPlaylist(p).accountStatus();
    if (!mounted || s == null || !_error) return;
    if (s.busy) {
      setState(() => _errorMessage =
          'This playlist is already streaming on another device '
              '(${s.activeCons}/${s.maxConnections} connections in use). '
              'Stop playback there and retry, or ask your admin for a '
              'personal account.');
    } else if (!s.authed || (s.status.isNotEmpty && s.status != 'Active')) {
      setState(() =>
          _errorMessage = 'The playlist account is not active on the server '
              '(${s.status.isEmpty ? 'not authorized' : s.status}). '
              'Contact your admin.');
    }
  }

  Future<void> _init() async {
    setState(() {
      _error = false;
      _errorMessage = null;
      _ready = false;
    });
    _buffering.value = true;
    _openTimeout?.cancel();
    _openTimeout = Timer(const Duration(seconds: 30), () {
      if (!_ready && !_error) _onLoadFailure('Timed out opening the stream');
    });
    _pendingResumeMs = null;
    if (!_isLive) {
      final resume = _appState?.resumePositionFor(widget.channel);
      if (resume != null && resume > 10000) _pendingResumeMs = resume;
    }
    try {
      await _player.open(
        Media(_url, httpHeaders: XtreamApi.uaHeaders),
        play: true,
      );
    } catch (e) {
      _onLoadFailure(e.toString());
    }
  }

  void _onViewChanged() {
    final zoomed = _viewCtrl.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed && mounted) setState(() => _zoomed = zoomed);
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    if (_showControls) {
      setState(() => _showControls = false);
    } else {
      _revealControls();
    }
  }

  /// Shows the controls and (on TV) pulls focus into them so the next D-pad
  /// press navigates the buttons (play/pause, skip, audio/subtitle, fit)
  /// instead of being swallowed by the root focus node.
  void _revealControls() {
    setState(() => _showControls = true);
    _scheduleHide();
    if (DeviceService.isTv && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_showControls) return;
        if (_isVod && _duration.value > Duration.zero) {
          // Movie/show: land on the seek bar so the remote scrubs right
          // away; live streams have nothing to seek so keep audio/subtitle
          // controls the entry point instead.
          _transportFocus.requestFocus();
        } else {
          _controlsFocus.requestFocus();
        }
      });
    }
  }

  /// Relative seek used by the TV remote skip buttons (and any caller that
  /// wants a fixed jump). Clamped to [0, duration] and ignored when the
  /// duration is unknown/zero.
  void _seekBy(Duration delta) {
    // Any seek counts as activity: keep the controls up while scrubbing
    // (seek-bar arrows are handled inside the bar and never re-reach the
    // player's root key handler).
    _scheduleHide();
    final durMs = _duration.value.inMilliseconds;
    if (durMs <= 0) return;
    final cur = _position.value.inMilliseconds.clamp(0, durMs);
    final target = (cur + delta.inMilliseconds).clamp(0, durMs);
    if (target > 0 && target < durMs) {
      _player.seek(Duration(milliseconds: target));
    }
  }

  /// TV remote / D-pad support: media keys always act, select toggles
  /// play/pause, and any other key reveals the controls (arrows then
  /// traverse the control buttons via normal focus navigation).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      _player.playOrPause();
      // Reveal the controls too, or nothing appears to navigate to after
      // pausing with the remote's media key — subtitles/audio become
      // unreachable while playing.
      _revealControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaRewind ||
        key == LogicalKeyboardKey.mediaFastForward) {
      _seekBy(key == LogicalKeyboardKey.mediaRewind
          ? const Duration(seconds: -30)
          : const Duration(seconds: 30));
      _revealControls();
      return KeyEventResult.handled;
    }
    final isSelect = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space;
    if (!_showControls) {
      if (isSelect) _player.playOrPause();
      _revealControls();
      return KeyEventResult.handled;
    }
    if (isSelect && node.hasPrimaryFocus) {
      // Controls visible but focus hasn't moved into a button yet.
      _player.playOrPause();
      _scheduleHide();
      return KeyEventResult.handled;
    }
    _scheduleHide(); // keep controls up while navigating them
    return KeyEventResult.ignored;
  }

  void _flashLabel(String label) {
    _overlayTimer?.cancel();
    setState(() => _overlayLabel = label);
    _overlayTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _overlayLabel = null);
    });
  }

  /// The audio/subtitles button only makes sense when there is something to
  /// switch: more than one audio track, or any embedded subtitle track.
  bool get _hasTrackChoices =>
      _tracks.audio.length > 1 || _tracks.subtitle.isNotEmpty;

  void _showTracksSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141416),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TracksSheet(player: _player, tracks: _tracks),
    );
  }

  void _cycleFitMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _fitMode = _FitMode.values[(_fitMode.index + 1) % _FitMode.values.length];
    });
    _flashLabel(_fitMode.label);
    _scheduleHide();
  }

  void _cycleRotationMode() {
    if (DeviceService.isTv) return; // button is hidden on TV anyway
    HapticFeedback.selectionClick();
    setState(() {
      _rotationMode = _RotationMode
          .values[(_rotationMode.index + 1) % _RotationMode.values.length];
    });
    SystemChrome.setPreferredOrientations(_rotationMode.orientations);
    _flashLabel(_rotationMode.label);
    _scheduleHide();
  }

  void _animateViewTo(Matrix4 target) {
    _zoomTween = Matrix4Tween(begin: _viewCtrl.value, end: target).animate(
      CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOutCubic),
    );
    _zoomAnim.forward(from: 0);
  }

  void _resetZoom() {
    HapticFeedback.selectionClick();
    _animateViewTo(Matrix4.identity());
  }

  void _onDoubleTap() {
    if (_viewCtrl.value.getMaxScaleOnAxis() > 1.01) {
      _resetZoom();
    } else {
      HapticFeedback.selectionClick();
      const s = 2.0;
      final p = _doubleTapPos;
      _animateViewTo(
        Matrix4.identity()
          ..translate(-p.dx * (s - 1), -p.dy * (s - 1))
          ..scale(s),
      );
    }
  }

  @override
  void dispose() {
    PipService.onChanged = null;
    unawaited(PipService.setActive(false));
    unawaited(WakeService.keepOn(false));
    _hideTimer?.cancel();
    _overlayTimer?.cancel();
    _openTimeout?.cancel();
    _controlsFocus.dispose();
    _transportFocus.dispose();
    _viewCtrl.removeListener(_onViewChanged);
    _viewCtrl.dispose();
    _zoomAnim.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    // Save "continue watching" position for VOD.
    if (!_isLive && _ready && widget.channel.isPlayable) {
      _appState?.recordRecent(widget.channel, _position.value.inMilliseconds);
    } else if (_isLive) {
      _appState?.recordRecent(widget.channel, 0);
    }
    _buffering.dispose();
    _playing.dispose();
    _position.dispose();
    _duration.dispose();
    _player.dispose();
    unawaited(_appState?.adminSync.reportWatching(''));
    SystemChrome.setPreferredOrientations(DeviceService.isTv
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  /// The video laid out according to the current fit mode.
  Widget _videoSurface() {
    final video = Video(
      controller: _video,
      controls: NoVideoControls,
      fill: Colors.black,
      fit: switch (_fitMode) {
        _FitMode.fit || _FitMode.zoom => BoxFit.contain,
        _FitMode.fill => BoxFit.cover,
        _FitMode.stretch => BoxFit.fill,
      },
    );
    if (_fitMode == _FitMode.zoom) {
      return Transform.scale(scale: 1.3, child: video);
    }
    return video;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          // Web/desktop: keep the controls up while the pointer is over the
          // player (hover shows them; any movement resets the hide timer).
          // Touch/TV never emit hover, so this is inert there.
          onEnter: (_) {
            if (!_showControls && mounted) setState(() => _showControls = true);
            _scheduleHide();
          },
          onHover: (_) => _scheduleHide(),
          onExit: (_) => _scheduleHide(),
          child: GestureDetector(
          onTap: _toggleControls,
          onDoubleTapDown: (d) => _doubleTapPos = d.localPosition,
          onDoubleTap: _ready ? _onDoubleTap : null,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Always mounted (not gated on _ready): the render texture must
              // exist from the start or some devices never show video.
              ClipRect(
                child: InteractiveViewer(
                  transformationController: _viewCtrl,
                  minScale: 1.0,
                  maxScale: 4.0,
                  panEnabled: _ready,
                  scaleEnabled: _ready,
                  clipBehavior: Clip.none,
                  child: _videoSurface(),
                ),
              ),
              if (_error)
                _ErrorView(
                  message: _errorMessage,
                  onRetry: _init,
                  onAlternate:
                      _alternateUrl != null && !kIsWeb ? _tryAlternateFormat : null,
                )
              else if (!_ready)
                const Center(
                    child: CircularProgressIndicator(color: Ybox.accent))
              else
                // Only overlay the spinner when playback is actually stalled —
                // live streams flag transient buffering while playing fine.
                AnimatedBuilder(
                  animation: Listenable.merge([_buffering, _playing]),
                  builder: (context, _) => _buffering.value && !_playing.value
                      ? const Center(
                          child:
                              CircularProgressIndicator(color: Ybox.accent))
                      : const SizedBox.shrink(),
                ),
              if (!_inPip)
                AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: _Controls(
                      title: _title,
                      isLive: _isLive,
                      ready: _ready,
                      playing: _playing,
                      position: _position,
                      duration: _duration,
                      fitIcon: _fitMode.icon,
                      rotationIcon: _rotationMode.icon,
                      controlsFocus: _controlsFocus,
                      transportFocus: _transportFocus,
                      onPlayPause: () => _player.playOrPause(),
                      onSeek: (d) => _player.seek(d),
                      onSeekBy: _seekBy,
                      onFit: _cycleFitMode,
                      onRotate: DeviceService.isTv ? null : _cycleRotationMode,
                      onTracks: _hasTrackChoices ? _showTracksSheet : null,
                      onSubtitle: _isVod ? _showSubtitleSheet : null,
                      onPip: PipService.supported && _ready
                          ? () => PipService.enter()
                          : null,
                      onCast: kIsWeb
                          ? null
                          : () => CastSheet.show(context, _url, _title),
                      onClose: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              // "Reset zoom" pill — shown whenever pinch-zoomed in.
              if (!_inPip)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 56),
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _zoomed ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: IgnorePointer(
                            ignoring: !_zoomed,
                            child: _PillButton(
                              icon: Icons.center_focus_strong_rounded,
                              label: 'Reset zoom',
                              onTap: _resetZoom,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Transient mode label ("Fill", "Landscape locked", ...).
              IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _overlayLabel != null ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xCC141416),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Ybox.accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _overlayLabel ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Ybox.textHigh,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC141416),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Ybox.accent.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Ybox.accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Ybox.textHigh,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final String title;
  final bool isLive;
  final bool ready;
  // Listenables (not values) so ticks repaint only the icon/seek bar.
  final ValueListenable<bool> playing;
  final ValueListenable<Duration> position;
  final ValueListenable<Duration> duration;
  final IconData fitIcon;
  final IconData rotationIcon;
  final FocusNode controlsFocus;
  final FocusNode transportFocus;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration> onSeekBy;
  final VoidCallback onFit;
  final VoidCallback? onRotate; // null on TV — orientation is fixed there
  final VoidCallback? onTracks; // audio/subtitle picker; null when nothing to pick
  final VoidCallback? onSubtitle; // online subtitle download (VOD only)
  final VoidCallback? onPip; // Android mini-window; null elsewhere
  final VoidCallback? onCast;
  final VoidCallback onClose;

  const _Controls({
    required this.title,
    required this.isLive,
    required this.ready,
    required this.playing,
    required this.position,
    required this.duration,
    required this.fitIcon,
    required this.rotationIcon,
    required this.controlsFocus,
    required this.transportFocus,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSeekBy,
    required this.onFit,
    this.onRotate,
    this.onTracks,
    this.onSubtitle,
    this.onPip,
    this.onCast,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // The Focus node is the TV remote's entry point into the control buttons:
    // the player state requests it whenever the controls are revealed, so
    // D-pad navigation starts inside the buttons rather than on the player's
    // root node.
    return Focus(
      focusNode: controlsFocus,
      // Select while no button inside has focus = play/pause, matching the
      // player's old root-level behaviour once focus has moved into controls.
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if ((key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.space) &&
            node.hasPrimaryFocus) {
          onPlayPause();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xB3000000), Colors.transparent, Color(0xB3000000)],
          ),
        ),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded,
                        color: Ybox.textHigh, size: 28),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Ybox.textHigh,
                      ),
                    ),
                  ),
                  if (isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Ybox.danger,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (onTracks != null)
                    IconButton(
                      onPressed: onTracks,
                      tooltip: 'Audio & subtitles',
                      icon: const Icon(Icons.subtitles_rounded,
                          color: Ybox.textHigh),
                    ),
                  if (onSubtitle != null)
                    IconButton(
                      onPressed: onSubtitle,
                      tooltip: 'Download subtitles',
                      icon: const Icon(Icons.closed_caption_rounded,
                          color: Ybox.textHigh),
                    ),
                  if (onRotate != null)
                    IconButton(
                      onPressed: onRotate,
                      tooltip: 'Rotation',
                      icon: Icon(rotationIcon, color: Ybox.textHigh),
                    ),
                  IconButton(
                    onPressed: onFit,
                    tooltip: 'Screen fit',
                    icon: Icon(fitIcon, color: Ybox.textHigh),
                  ),
                  if (onPip != null)
                    IconButton(
                      onPressed: onPip,
                      tooltip: 'Mini window',
                      icon: const Icon(Icons.picture_in_picture_alt_rounded,
                          color: Ybox.textHigh),
                    ),
                  if (onCast != null)
                    IconButton(
                      onPressed: onCast,
                      icon: const Icon(Icons.cast_rounded, color: Ybox.textHigh),
                    ),
                ],
              ),
            ),
            const Spacer(),
            // Center play/pause
            if (ready)
              TvFocusable(
                onTap: onPlayPause,
                borderRadius: BorderRadius.circular(40),
                child: GestureDetector(
                  onTap: onPlayPause,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Ybox.accent,
                      shape: BoxShape.circle,
                      boxShadow: Ybox.glow(0.5),
                    ),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: playing,
                      builder: (context, isPlaying, _) => Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            // Bottom: seek bar for VOD only (a known duration is required —
            // unknown-length streams can't be seeked and would show a dead bar).
            // On TV the whole bar is one D-pad target: left/right jump 30s, so
            // the time is fully controllable from a remote (a focused Material
            // Slider would only nudge by an invisible step).
            if (ready && !isLive && duration.value > Duration.zero)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: _SeekBar(
                  position: position,
                  duration: duration,
                  onSeek: onSeek,
                  onSeekBy: onSeekBy,
                  focusNode: transportFocus,
                ),
              )
            else
              const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  final ValueListenable<Duration> position;
  final ValueListenable<Duration> duration;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration> onSeekBy;
  final FocusNode? focusNode;

  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.onSeekBy,
    this.focusNode,
  });

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  bool _focused = false;
  // While the thumb is being dragged, its value comes from the finger, NOT
  // the position stream — otherwise every position tick yanks the thumb back
  // and the seek never settles on the tapped spot.
  bool _dragging = false;
  double _dragValue = 0;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _commit(double v) {
    final durMs = widget.duration.value.inMilliseconds;
    // Never seek on a bogus duration (0 / unknown) — a clamped-to-zero or
    // negative target is what made browsers drop the movie back to 0:00.
    if (durMs <= 0) return;
    final target = (durMs * v).round().clamp(0, durMs);
    if (target > 0 && target < durMs) {
      widget.onSeek(Duration(milliseconds: target));
    }
  }

  /// TV remote: the whole bar is ONE focusable pivot where left/right jumps
  /// 30s (a focused Material Slider would only nudge by an invisible step).
  /// TV remote: the whole bar is ONE focusable pivot where left/right jumps
  /// 30s (a focused Material Slider would only nudge by an invisible step).
  /// Up/down pass through so focus can leave for the play button / top bar.
  /// The events arrive here via the [Focus] wrapper once the detector below
  /// (which has no key handler of its own) lets them bubble up.
  KeyEventResult _onSeekKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_focused) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      HapticFeedback.selectionClick();
      widget.onSeekBy(key == LogicalKeyboardKey.arrowLeft
          ? const Duration(seconds: -30)
          : const Duration(seconds: 30));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isTv = DeviceService.isTv;
    return Focus(
      onKeyEvent: _onSeekKey,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        onShowFocusHighlight: (v) {
          if (_focused != v && mounted) setState(() => _focused = v);
        },
        child: AnimatedBuilder(
        animation: Listenable.merge([widget.position, widget.duration]),
        builder: (context, _) {
          final pos = widget.position.value;
          final dur = widget.duration.value;
          final durMs = dur.inMilliseconds;
          final shown = _dragging
              ? _dragValue
              : (durMs == 0 ? 0.0 : (pos.inMilliseconds / durMs).clamp(0.0, 1.0));
          return LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  if (w <= 0) return;
                  setState(() {
                    _dragging = true;
                    _dragValue = (d.localPosition.dx / w).clamp(0.0, 1.0);
                  });
                },
                onTapUp: (d) {
                  if (!_dragging) return;
                  setState(() => _dragging = false);
                  _commit(_dragValue);
                },
                onHorizontalDragStart: (d) {
                  setState(() {
                    _dragging = true;
                    _dragValue = (d.localPosition.dx / w).clamp(0.0, 1.0);
                  });
                },
                onHorizontalDragUpdate: (d) {
                  setState(() {
                    _dragValue = (d.localPosition.dx / w).clamp(0.0, 1.0);
                  });
                },
                onHorizontalDragEnd: (_) {
                  if (!_dragging) return;
                  setState(() => _dragging = false);
                  _commit(_dragValue);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Ybox.radiusSm),
                    border: Border.all(
                      color: _focused ? Ybox.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 20,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: shown,
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Ybox.accent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(
                                    left: (shown * w).clamp(0.0, w - 12)),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 120),
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Ybox.accent,
                                    shape: BoxShape.circle,
                                    boxShadow:
                                        _focused ? Ybox.glow(0.5) : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fmt(_dragging
                                ? Duration(milliseconds: (durMs *
                                        _dragValue)
                                    .round()
                                    .clamp(0, durMs))
                                : pos),
                            style: TextStyle(
                              fontSize: isTv ? 17 : 12,
                              fontWeight: FontWeight.w700,
                              color: Ybox.textHigh,
                            ),
                          ),
                          Text(
                            _fmt(dur),
                            style: TextStyle(
                              fontSize: isTv ? 17 : 12,
                              color: Ybox.textDim,
                            ),
                          ),
                        ],
                      ),
                      if (_focused && isTv) ...[
                        const SizedBox(height: 4),
                        Text(
                          '◄  Left / Right  seek 30s  ►',
                          style: TextStyle(
                              fontSize: 14, color: Ybox.textDim),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback? onAlternate;

  const _ErrorView({required this.onRetry, this.message, this.onAlternate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Ybox.danger, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Playback failed',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Ybox.textHigh),
            ),
            const SizedBox(height: 8),
            Text(
              message == null || message!.isEmpty
                  ? 'The stream could not be opened. Check your connection '
                      'or try again.'
                  : message!,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Ybox.textDim),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              child: const Text('Retry'),
            ),
            if (onAlternate != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAlternate,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 48),
                  side: const BorderSide(color: Ybox.accent),
                  foregroundColor: Ybox.accent,
                ),
                child: const Text('Try alternate format'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Audio / subtitle track picker — lists the tracks the demuxer found inside
/// the stream (MKV VOD with multiple languages etc.). Only reachable when
/// such tracks exist; plain live HLS never shows it.
class _TracksSheet extends StatefulWidget {
  final Player player;
  final Tracks tracks;

  const _TracksSheet({required this.player, required this.tracks});

  @override
  State<_TracksSheet> createState() => _TracksSheetState();
}

class _TracksSheetState extends State<_TracksSheet> {
  // Local selection ids: the player's state.track updates asynchronously
  // after set*Track resolves, so the checkmark follows the tap immediately.
  late String _audioId = widget.player.state.track.audio.id;
  late String _subId = widget.player.state.track.subtitle.id;

  static final _section = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: Ybox.textDim);

  String _label(String? title, String? language, String id) {
    final parts = [
      if (language != null && language.isNotEmpty) language.toUpperCase(),
      if (title != null && title.isNotEmpty) title,
    ];
    return parts.isEmpty ? 'Track $id' : parts.join(' — ');
  }

  void _pickAudio(AudioTrack t) {
    setState(() => _audioId = t.id);
    unawaited(widget.player.setAudioTrack(t));
  }

  void _pickSub(SubtitleTrack t) {
    setState(() => _subId = t.id);
    unawaited(widget.player.setSubtitleTrack(t));
  }

  Widget _tile(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? Ybox.accent : Ybox.textDim,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected ? Ybox.textHigh : Ybox.textDim)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = widget.tracks.audio;
    final subs = widget.tracks.subtitle;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Audio & subtitles',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Ybox.textHigh)),
            const SizedBox(height: 10),
            if (audio.length > 1) ...[
              Text('AUDIO', style: _section),
              _tile('Auto', _audioId == AudioTrack.auto().id,
                  () => _pickAudio(AudioTrack.auto())),
              for (final t in audio)
                _tile(_label(t.title, t.language, t.id), _audioId == t.id,
                    () => _pickAudio(t)),
            ],
            if (subs.isNotEmpty) ...[
              if (audio.length > 1) const SizedBox(height: 12),
              Text('SUBTITLES', style: _section),
              _tile('Off', _subId == SubtitleTrack.no().id,
                  () => _pickSub(SubtitleTrack.no())),
              _tile('Auto', _subId == SubtitleTrack.auto().id,
                  () => _pickSub(SubtitleTrack.auto())),
              for (final t in subs)
                _tile(_label(t.title, t.language, t.id), _subId == t.id,
                    () => _pickSub(t)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Download & attach an online subtitle for the current movie / episode.
/// Lets the user pick a language, shows matching subtitle files found on
/// OpenSubtitles, and attaches the chosen one with [SubtitleTrack.data] —
/// which works on native (mpv) and web alike, so no file I/O is involved.
class _SubtitleSheet extends StatefulWidget {
  final String query;
  final Player player;

  const _SubtitleSheet({required this.query, required this.player});

  @override
  State<_SubtitleSheet> createState() => _SubtitleSheetState();
}

class _SubtitleSheetState extends State<_SubtitleSheet> {
  static const _languages = <String, String>{
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'pt': 'Portuguese',
    'it': 'Italian',
    'ru': 'Russian',
    'ar': 'Arabic',
    'tr': 'Turkish',
    'hi': 'Hindi',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'nl': 'Dutch',
    'pl': 'Polish',
    'el': 'Greek',
    'he': 'Hebrew',
    'sv': 'Swedish',
  };

  SubtitleSettings _settings = const SubtitleSettings();
  bool _configured = false;
  late String _language;
  bool _busy = false;
  String? _error;
  List<SubtitleCandidate>? _results;
  bool _attached = false;

  @override
  void initState() {
    super.initState();
    _language = 'en';
    _load();
  }

  Future<void> _load() async {
    final s = await SubtitleSettings.load();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _configured = s.hasCredentials;
      _language = _languages.containsKey(s.language) ? s.language : 'en';
    });
  }

  SubtitleService get _service =>
      SubtitleService(apiKey: _settings.apiKey);

  Future<void> _search() async {
    if (!_configured) {
      setState(() => _error =
          'Subtitle service needs an API key (Settings → Subtitles).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _results = null;
      _attached = false;
    });
    try {
      final found = await _service.search(widget.query, languages: [_language]);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _results = found;
        if (found.isEmpty) _error = 'No subtitles found for "${widget.query}".';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _download(SubtitleCandidate c) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final text = await _service.download(c.id);
      await widget.player.setSubtitleTrack(
        SubtitleTrack.data(
          text,
          title: c.fileName,
          language: c.language,
        ),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _attached = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Download subtitles',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Ybox.textHigh)),
                ),
                if (_attached)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      'Attached ✓',
                      style: TextStyle(fontSize: 12, color: Ybox.accent),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Searching: "${widget.query}"',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: Ybox.textDim),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _language,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final e in _languages.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value,
                              style: TextStyle(color: Ybox.textHigh)),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _language = v ?? 'en'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Ybox.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.search_rounded),
                  label: const Text('Find'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(fontSize: 12.5, color: Ybox.danger)),
            ],
            if (_results != null && _results!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('${_results!.length} FILE(S)',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Ybox.textDim)),
              const SizedBox(height: 4),
              for (final c in _results!) ...[
                InkWell(
                  onTap: _busy ? null : () => _download(c),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: Ybox.textDim.withValues(alpha: 0.15))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.download_rounded,
                            color: Ybox.accent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _languages[c.language] ??
                                    (c.languageName ?? c.language),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Ybox.textHigh),
                              ),
                              if (c.title != null && c.title!.trim().isNotEmpty)
                                Text(
                                  c.title!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12, color: Ybox.textDim),
                                ),
                            ],
                          ),
                        ),
                        if (c.downloads > 0)
                          Text('${c.downloads} ↓',
                              style: TextStyle(
                                  fontSize: 11, color: Ybox.textDim)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

