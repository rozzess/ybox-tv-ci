import 'dart:io';

String platformName() => Platform.operatingSystem;
String platformVersion() => Platform.operatingSystemVersion;
String hostname() => Platform.localHostname;

Future<String> localIp() async {
  try {
    final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    for (final ni in interfaces) {
      for (final addr in ni.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
  } catch (_) {}
  return '';
}
