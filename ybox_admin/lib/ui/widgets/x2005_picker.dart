import 'package:flutter/material.dart';

import '../../data/x2005_accounts.dart';
import '../../services/admin_state.dart';
import '../../theme.dart';
import 'pressable_tile.dart';

/// Searchable full-height picker over the X2005 server list — the bundled
/// dump merged with the Firestore copy (mirror-built IPAs have an empty
/// bundle and rely entirely on the cloud list). Tapping a row pops with
/// that account so the caller can pre-fill an Xtream playlist form.
Future<X2005Account?> showX2005Picker(BuildContext context) {
  return showModalBottomSheet<X2005Account>(
    context: context,
    backgroundColor: YColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const _X2005Picker(),
  );
}

class _X2005Picker extends StatefulWidget {
  const _X2005Picker();

  @override
  State<_X2005Picker> createState() => _X2005PickerState();
}

class _X2005PickerState extends State<_X2005Picker> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<X2005Account> get _accounts => AdminState.instance.x2005All;

  List<X2005Account> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _accounts;
    return _accounts
        .where((a) =>
            a.hostLabel.toLowerCase().contains(q) ||
            a.username.toLowerCase().contains(q) ||
            a.password.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: AdminState.instance,
        builder: (context, _) {
          final accounts = _accounts;
          final matches = _matches;
          return Padding(
            padding: EdgeInsets.only(
              left: YSpace.l,
              right: YSpace.l,
              top: YSpace.m,
              bottom: MediaQuery.of(context).viewInsets.bottom + YSpace.l,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: YSpace.m),
                  const Text('Pick X2005 account', style: YText.section),
                  const SizedBox(height: YSpace.xs),
                  Text(
                    '${accounts.length} accounts — valid ones first. '
                    'Tap one to pre-fill the form.',
                    style: YText.caption,
                  ),
                  const SizedBox(height: YSpace.m),
                  TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(color: YColors.text(0.9)),
                    decoration: InputDecoration(
                      hintText: 'Search host, username or password…',
                      prefixIcon: Icon(Icons.search, color: YColors.text(0.4)),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: YSpace.s),
                  Text(
                    '${matches.length} of ${accounts.length}',
                    style: YText.caption,
                  ),
                  const SizedBox(height: YSpace.s),
                  Expanded(
                    child: matches.isEmpty
                        ? Center(
                            child: Text(
                            accounts.isEmpty
                                ? 'No accounts yet — waiting for cloud list…'
                                : 'No matches',
                            style: YText.caption,
                          ))
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: matches.length,
                            itemBuilder: (context, index) =>
                                _AccountRow(account: matches[index]),
                          ),
                  ),
                ],
              ),
            ),
          );
        });
  }
}

class _AccountRow extends StatelessWidget {
  final X2005Account account;

  const _AccountRow({required this.account});

  @override
  Widget build(BuildContext context) {
    final expiry = account.expiryDate;
    return Padding(
      padding: const EdgeInsets.only(bottom: YSpace.s),
      child: PressableTile(
        padding: const EdgeInsets.symmetric(horizontal: YSpace.m, vertical: 12),
        onTap: () => Navigator.pop(context, account),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(YSpace.s),
              decoration: BoxDecoration(
                color: account.expired
                    ? YColors.danger.withOpacity(0.12)
                    : YColors.accentSoft(),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.cloud_outlined,
                size: 18,
                color: account.expired ? YColors.danger : YColors.accent,
              ),
            ),
            const SizedBox(width: YSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.hostLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: YColors.text(0.95),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account.username,
                    style: YText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (expiry != null) ...[
              const SizedBox(width: YSpace.s),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (account.expired ? YColors.danger : YColors.green)
                      .withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  account.expired
                      ? 'EXPIRED ${_shortDate(expiry)}'
                      : _shortDate(expiry),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: account.expired ? YColors.danger : YColors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
