class DlnaDevice {
  final String friendlyName;
  final Uri controlUrl;
  final String location;

  DlnaDevice({
    this.friendlyName = '',
    Uri? controlUrl,
    this.location = '',
  }) : controlUrl = controlUrl ?? Uri.parse('http://localhost');
}

/// Web stub of the DLNA cast service — SSDP/UDP sockets don't exist in the
/// browser, so there are never any renderers to find.
class DlnaCast {
  static Future<List<DlnaDevice>> discover(
      {Duration timeout = const Duration(seconds: 3)}) async {
    return [];
  }

  static Future<void> cast(DlnaDevice device, String url,
      {String title = ''}) {
    throw UnsupportedError('DLNA casting is not available on the web');
  }
}
