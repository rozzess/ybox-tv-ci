import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/admin_state.dart';
import '../../theme.dart';
import '../widgets/entrance.dart';
import '../widgets/pressable_tile.dart';
import '../widgets/ybox_widgets.dart';
import 'device_detail_sheet.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AdminState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final devices = state.devices;
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    YSpace.l, YSpace.l, YSpace.l, YSpace.m),
                child: Row(
                  children: [
                    const Expanded(child: Text('Devices', style: YText.title)),
                    const LiveIndicator(),
                    const SizedBox(width: YSpace.s),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: YSpace.m, vertical: YSpace.s),
                      decoration: BoxDecoration(
                        color: YColors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${state.onlineDeviceCount} online',
                        style: const TextStyle(
                          color: YColors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: devices.isEmpty
                    ? const EmptyState(
                        icon: Icons.devices_other,
                        title: 'No devices yet',
                        message:
                            'Open YBOX TV on any phone or TV with internet — '
                            'devices register here automatically once someone '
                            'signs in.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            YSpace.l, 0, YSpace.l, YSpace.xl),
                        itemCount: devices.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: YSpace.m),
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return Entrance(
                            index: index,
                            child: _DeviceTile(device: device),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final Device device;

  const _DeviceTile({required this.device});

  @override
  Widget build(BuildContext context) {
    final ip = device.publicIp.isNotEmpty ? device.publicIp : device.localIp;
    return PressableTile(
      onTap: () => showDeviceDetailSheet(context, device),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(YSpace.m),
            decoration: BoxDecoration(
              color: YColors.accentSoft(),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              device.platform.toLowerCase() == 'android'
                  ? Icons.phone_android
                  : Icons.phone_iphone,
              color: YColors.accent,
            ),
          ),
          const SizedBox(width: YSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: YColors.text(0.95),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: YSpace.xs),
                Text(
                  '${ip.isEmpty ? 'no IP' : ip} · '
                  '${device.model.isEmpty ? device.platform : device.model} · '
                  'v${device.appVersion}'
                  '${device.username.isEmpty ? '' : ' · ${device.username}'}',
                  style: YText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: YSpace.s),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: device.online ? YColors.green : Colors.white24,
                  boxShadow: device.online
                      ? [
                          BoxShadow(
                            color: YColors.green.withOpacity(0.6),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: YSpace.s),
              Text(device.lastSeenLabel, style: YText.caption),
            ],
          ),
        ],
      ),
    );
  }
}
