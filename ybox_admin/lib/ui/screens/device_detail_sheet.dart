import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/admin_state.dart';
import '../../theme.dart';
import '../widgets/ybox_widgets.dart';

Future<void> showDeviceDetailSheet(BuildContext context, Device device) {
  return showYSheet(
    context,
    _DeviceDetail(device: device),
  );
}

class _DeviceDetail extends StatelessWidget {
  final Device device;

  const _DeviceDetail({required this.device});

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: YSpace.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: YText.caption),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                color: YColors.text(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AdminState.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: device.online ? YColors.green : Colors.white24,
              ),
            ),
            const SizedBox(width: YSpace.s),
            Expanded(
              child: Text(device.name, style: YText.section),
            ),
          ],
        ),
        const SizedBox(height: YSpace.m),
        _row('Device ID', device.deviceId),
        _row('Platform', device.platform),
        _row('Model', device.model),
        _row('App version', device.appVersion),
        _row('Public IP', device.publicIp),
        _row('Local IP', device.localIp),
        _row('Signed-in user', device.username),
        _row('Last seen', device.lastSeenLabel),
        if (device.watching.isNotEmpty) _row('Watching', device.watching),
        const SizedBox(height: YSpace.m),
        Text(
          'Playlist and subscription changes reach this device instantly '
          'while it\'s online — no manual push needed.',
          style: YText.caption,
        ),
        const SizedBox(height: YSpace.l),
        YSecondaryButton(
          label: 'Remove device',
          icon: Icons.delete_outline,
          color: YColors.danger,
          onPressed: () async {
            final confirmed = await confirmDialog(
              context,
              title: 'Remove device?',
              message:
                  '${device.name} will disappear from the fleet. It re-registers '
                  'automatically the next time the app checks in.',
              confirmLabel: 'Remove',
            );
            if (confirmed) {
              await state.removeDevice(device.deviceId);
              if (context.mounted) Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}
