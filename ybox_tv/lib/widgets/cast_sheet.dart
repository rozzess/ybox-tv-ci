import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/dlna_cast.dart'
    if (dart.library.html) '../services/dlna_cast_web.dart';
import '../theme/app_theme.dart';
import 'pressable_tile.dart';

/// "Watch on TV" bottom sheet: DLNA discovery + cast, AirPlay hint on iOS.
class CastSheet extends StatefulWidget {
  final String streamUrl;
  final String title;

  const CastSheet({super.key, required this.streamUrl, required this.title});

  static Future<void> show(
      BuildContext context, String streamUrl, String title) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Ybox.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CastSheet(streamUrl: streamUrl, title: title),
    );
  }

  @override
  State<CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends State<CastSheet> {
  List<DlnaDevice>? _devices;
  String? _castingTo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _devices = null;
      _error = null;
    });
    final found = await DlnaCast.discover();
    if (mounted) setState(() => _devices = found);
  }

  Future<void> _cast(DlnaDevice device) async {
    setState(() {
      _castingTo = device.friendlyName;
      _error = null;
    });
    try {
      await DlnaCast.cast(device, widget.streamUrl, title: widget.title);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Now playing on ${device.friendlyName}'),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _castingTo = null;
          _error = 'Could not start playback on ${device.friendlyName}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = _devices;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Ybox.textDim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.cast_rounded, color: Ybox.accent),
                const SizedBox(width: 12),
                Text('Watch on TV',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: devices == null ? null : _scan,
                  icon: const Icon(Icons.refresh_rounded,
                      color: Ybox.textHigh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (defaultTargetPlatform == TargetPlatform.iOS)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Tip: for Apple TV, use AirPlay from Control Center — '
                  'the video follows automatically.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: Ybox.danger)),
              ),
            if (devices == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Ybox.accent),
                      SizedBox(height: 16),
                      Text('Looking for TVs on your network…',
                          style: TextStyle(color: Ybox.textHigh)),
                    ],
                  ),
                ),
              )
            else if (devices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No TVs found. Make sure your TV is on and connected to '
                  'the same Wi-Fi network, then tap refresh.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...devices.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PressableTile(
                    onTap: _castingTo == null ? () => _cast(d) : null,
                    borderRadius: BorderRadius.circular(Ybox.radiusSm),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Ybox.card,
                        borderRadius: BorderRadius.circular(Ybox.radiusSm),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tv_rounded, color: Ybox.textHigh),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              d.friendlyName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Ybox.textHigh,
                              ),
                            ),
                          ),
                          if (_castingTo == d.friendlyName)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Ybox.accent),
                            )
                          else
                            const Icon(Icons.play_arrow_rounded,
                                color: Ybox.accent),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
