import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A DLNA/UPnP MediaRenderer found on the local network (a smart TV).
class DlnaDevice {
  final String friendlyName;
  final Uri controlUrl;
  final String location;

  const DlnaDevice({
    required this.friendlyName,
    required this.controlUrl,
    required this.location,
  });
}

/// Pure-Dart DLNA casting: SSDP discovery + AVTransport SOAP control.
class DlnaCast {
  static const _ssdpAddress = '239.255.255.250';
  static const _ssdpPort = 1900;
  static const _searchTarget = 'urn:schemas-upnp-org:device:MediaRenderer:1';

  /// Discovers MediaRenderers (TVs) on the LAN.
  static Future<List<DlnaDevice>> discover(
      {Duration timeout = const Duration(seconds: 3)}) async {
    final locations = <String>{};
    RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (_) {
      return [];
    }
    socket.broadcastEnabled = true;

    const msearch = 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: $_ssdpAddress:$_ssdpPort\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 2\r\n'
        'ST: $_searchTarget\r\n'
        '\r\n';

    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;
      final text = utf8.decode(dg.data, allowMalformed: true);
      final m = RegExp(r'LOCATION:\s*(\S+)', caseSensitive: false)
          .firstMatch(text);
      if (m != null) locations.add(m.group(1)!.trim());
    });

    final data = utf8.encode(msearch);
    final target = InternetAddress(_ssdpAddress);
    // Send a few times — SSDP is lossy UDP.
    for (var i = 0; i < 3; i++) {
      try {
        socket.send(data, target, _ssdpPort);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 150));
    }
    await Future.delayed(timeout);
    await sub.cancel();
    socket.close();

    final devices = <DlnaDevice>[];
    for (final loc in locations) {
      final d = await _describe(loc);
      if (d != null) devices.add(d);
    }
    return devices;
  }

  static Future<DlnaDevice?> _describe(String location) async {
    try {
      final res = await http
          .get(Uri.parse(location))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final xml = res.body;

      final name = RegExp(r'<friendlyName>([^<]*)</friendlyName>')
              .firstMatch(xml)
              ?.group(1) ??
          'TV';

      // Find the AVTransport service block, then its controlURL.
      String? controlPath;
      for (final svc
          in RegExp(r'<service>([\s\S]*?)</service>').allMatches(xml)) {
        final block = svc.group(1)!;
        if (block.contains('AVTransport')) {
          controlPath = RegExp(r'<controlURL>([^<]*)</controlURL>')
              .firstMatch(block)
              ?.group(1);
          break;
        }
      }
      if (controlPath == null || controlPath.isEmpty) return null;

      final base = Uri.parse(location);
      final control = controlPath.startsWith('http')
          ? Uri.parse(controlPath)
          : base.resolve(controlPath);

      return DlnaDevice(
          friendlyName: name.trim(), controlUrl: control, location: location);
    } catch (_) {
      return null;
    }
  }

  /// Sends the stream URL to the TV and starts playback.
  static Future<void> cast(DlnaDevice device, String streamUrl,
      {String title = 'YBOX TV'}) async {
    final metadata = _didl(streamUrl, title);
    await _soap(device, 'SetAVTransportURI', '''
<InstanceID>0</InstanceID>
<CurrentURI>${_xmlEscape(streamUrl)}</CurrentURI>
<CurrentURIMetaData>${_xmlEscape(metadata)}</CurrentURIMetaData>''');
    await _soap(device, 'Play', '''
<InstanceID>0</InstanceID>
<Speed>1</Speed>''');
  }

  /// Stops playback on the TV.
  static Future<void> stop(DlnaDevice device) async {
    await _soap(device, 'Stop', '<InstanceID>0</InstanceID>');
  }

  static Future<void> _soap(
      DlnaDevice device, String action, String body) async {
    final envelope = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
<s:Body>
<u:$action xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
$body
</u:$action>
</s:Body>
</s:Envelope>''';

    final res = await http
        .post(
          device.controlUrl,
          headers: {
            'Content-Type': 'text/xml; charset="utf-8"',
            'SOAPACTION':
                '"urn:schemas-upnp-org:service:AVTransport:1#$action"',
          },
          body: envelope,
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode >= 400) {
      throw Exception('TV refused $action (HTTP ${res.statusCode})');
    }
  }

  static String _didl(String url, String title) =>
      '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
      '<item id="0" parentID="-1" restricted="1">'
      '<dc:title>${_xmlEscape(title)}</dc:title>'
      '<upnp:class>object.item.videoItem</upnp:class>'
      '<res protocolInfo="http-get:*:video/*:*">${_xmlEscape(url)}</res>'
      '</item></DIDL-Lite>';

  static String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
