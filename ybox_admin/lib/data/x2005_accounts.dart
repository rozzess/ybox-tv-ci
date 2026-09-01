// Stub for the public CI mirror: the real account dump is private.
library;

class X2005Account {
  const X2005Account(this.server, this.username, this.password,
      [this.expiry = '']);
  final String server;
  final String username;
  final String password;
  final String expiry;
  bool get hasExpiry => expiry.isNotEmpty;
  DateTime? get expiryDate => hasExpiry ? DateTime.tryParse(expiry) : null;
  bool get expired =>
      expiryDate != null && !expiryDate!.isAfter(DateTime.now());
  String get hostLabel => server.replaceFirst(RegExp(r'^https?://'), '');
}

const List<X2005Account> x2005Accounts = [];
