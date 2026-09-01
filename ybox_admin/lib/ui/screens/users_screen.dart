import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../services/admin_state.dart';
import '../../theme.dart';
import '../widgets/entrance.dart';
import '../widgets/pressable_tile.dart';
import '../widgets/ybox_widgets.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  void _showAddUserSheet(BuildContext context) {
    final username = TextEditingController();
    final password = TextEditingController();
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    String? error;
    bool busy = false;
    showYSheet(
      context,
      StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New user account', style: YText.section),
            const SizedBox(height: YSpace.xs),
            Text(
              'Players sign in with these credentials anywhere in the world. '
              'Grant a subscription afterwards so they can watch.',
              style: YText.caption,
            ),
            const SizedBox(height: YSpace.l),
            YTextField(controller: username, label: 'Username'),
            YTextField(controller: password, label: 'Password', obscure: true),
            YTextField(controller: name, label: 'Full name (optional)'),
            YTextField(
              controller: phone,
              label: 'Phone (optional)',
              keyboardType: TextInputType.phone,
            ),
            YTextField(
              controller: email,
              label: 'Email (optional)',
              keyboardType: TextInputType.emailAddress,
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: YSpace.s),
                child: Text(
                  error!,
                  style: const TextStyle(color: YColors.danger, fontSize: 13),
                ),
              ),
            YPrimaryButton(
              label: busy ? 'Creating…' : 'Create account',
              icon: Icons.person_add,
              onPressed: busy
                  ? null
                  : () async {
                      setSheetState(() => busy = true);
                      final result = await AdminState.instance.addUser(
                        username.text,
                        password.text,
                        name: name.text,
                        phone: phone.text,
                        email: email.text,
                      );
                      if (result != null) {
                        setSheetState(() {
                          busy = false;
                          error = result;
                        });
                      } else if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showGrantSheet(BuildContext context, YUser user) {
    final customAmount = TextEditingController();
    bool extend = false;
    String customUnit = 'days';
    String? error;
    bool busy = false;

    showYSheet(
      context,
      StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> grant(int durationMs, String label) async {
            if (busy) return;
            setSheetState(() => busy = true);
            HapticFeedback.mediumImpact();
            final expiry = await AdminState.instance
                .grantSubscription(user.uid, durationMs, extend: extend);
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${user.username}: $label ${extend ? 'added' : 'set'} — '
                    'active until ${SubDurations.dateLabel(expiry)}.',
                  ),
                ),
              );
            }
          }

          Widget modeChip(String label, bool value) => Expanded(
                child: ChoiceChip(
                  selected: extend == value,
                  showCheckmark: false,
                  selectedColor: YColors.accentSoft(0.25),
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: extend == value
                        ? YColors.accent
                        : YColors.accentSoft(0.3),
                  ),
                  label: SizedBox(
                    width: double.infinity,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: extend == value
                            ? YColors.accent
                            : YColors.text(0.6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  onSelected: (_) => setSheetState(() => extend = value),
                ),
              );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subscription for ${user.username}', style: YText.section),
              const SizedBox(height: YSpace.xs),
              Text(
                user.subscriptionActive
                    ? 'Current: ${user.subscriptionLabel} '
                        '(until ${SubDurations.dateLabel(user.subExpiry)})'
                    : 'Current: ${user.subscriptionLabel}',
                style: YText.caption,
              ),
              const SizedBox(height: YSpace.l),
              Row(children: [
                modeChip('Set duration', false),
                const SizedBox(width: YSpace.s),
                modeChip('Add time', true),
              ]),
              const SizedBox(height: YSpace.xs),
              Text(
                extend
                    ? 'Adds on top of the later of now or the current expiry.'
                    : 'Replaces the current subscription — it will expire '
                        'this long from now, even if that\'s sooner. '
                        'The countdown on their screen updates live.',
                style: YText.caption,
              ),
              const SizedBox(height: YSpace.l),
              Wrap(
                spacing: YSpace.s,
                runSpacing: YSpace.s,
                children: [
                  for (final key in SubDurations.all.keys)
                    ActionChip(
                      backgroundColor: YColors.accentSoft(0.12),
                      side: BorderSide(color: YColors.accentSoft(0.3)),
                      label: Text(
                        SubDurations.labels[key]!,
                        style: const TextStyle(
                          color: YColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: busy
                          ? null
                          : () => grant(
                              SubDurations.all[key]!, SubDurations.labels[key]!),
                    ),
                ],
              ),
              const SizedBox(height: YSpace.l),
              Text('Custom duration', style: YText.caption),
              const SizedBox(height: YSpace.s),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: customAmount,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: YColors.text(0.9)),
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                  ),
                  const SizedBox(width: YSpace.m),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: customUnit,
                      dropdownColor: YColors.card,
                      style: TextStyle(color: YColors.text(0.9)),
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: [
                        for (final unit in SubDurations.unitMs.keys)
                          DropdownMenuItem(value: unit, child: Text(unit)),
                      ],
                      onChanged: (v) =>
                          setSheetState(() => customUnit = v ?? 'days'),
                    ),
                  ),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: YSpace.s),
                  child: Text(
                    error!,
                    style:
                        const TextStyle(color: YColors.danger, fontSize: 13),
                  ),
                ),
              const SizedBox(height: YSpace.m),
              YPrimaryButton(
                label: busy
                    ? 'Applying…'
                    : (extend ? 'Add custom time' : 'Set custom duration'),
                icon: Icons.timer_outlined,
                onPressed: busy
                    ? null
                    : () {
                        final amount =
                            int.tryParse(customAmount.text.trim()) ?? 0;
                        if (amount < 1 || amount > 10000) {
                          setSheetState(() =>
                              error = 'Enter an amount between 1 and 10000');
                          return;
                        }
                        final unitLabel = amount == 1
                            ? customUnit.substring(0, customUnit.length - 1)
                            : customUnit;
                        grant(amount * SubDurations.unitMs[customUnit]!,
                            '$amount $unitLabel');
                      },
              ),
              if (user.subExpiry > 0) ...[
                const SizedBox(height: YSpace.m),
                YSecondaryButton(
                  label: 'Revoke subscription',
                  icon: Icons.block,
                  color: YColors.danger,
                  onPressed: () async {
                    await AdminState.instance.revokeSubscription(user.uid);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AdminState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    YSpace.l, YSpace.l, YSpace.l, YSpace.m),
                child: Row(
                  children: [
                    const Expanded(child: Text('Users', style: YText.title)),
                    const LiveIndicator(),
                    const SizedBox(width: YSpace.s),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: YColors.accent,
                      ),
                      onPressed: () => _showAddUserSheet(context),
                      icon: const Icon(Icons.person_add, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.users.isEmpty
                    ? const EmptyState(
                        icon: Icons.person_outline,
                        title: 'No user accounts',
                        message:
                            'Create accounts here, or let users register '
                            'themselves from the YBOX TV app.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            YSpace.l, 0, YSpace.l, YSpace.xl),
                        itemCount: state.users.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: YSpace.m),
                        itemBuilder: (context, index) {
                          final user = state.users[index];
                          return Entrance(
                            index: index,
                            child: _UserTile(
                              user: user,
                              onGrant: () => _showGrantSheet(context, user),
                            ),
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

class _UserTile extends StatelessWidget {
  final YUser user;
  final VoidCallback onGrant;

  const _UserTile({required this.user, required this.onGrant});

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: color,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = AdminState.instance;
    final subColor = user.subscriptionActive
        ? YColors.green
        : (user.subExpiry > 0 ? YColors.danger : YColors.text(0.4));
    final details = [
      if (user.name.isNotEmpty) user.name,
      if (user.phone.isNotEmpty) user.phone,
      if (user.email.isNotEmpty) user.email,
    ].join(' · ');

    return PressableTile(
      onTap: onGrant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: YColors.accentSoft(0.2),
                child: Text(
                  user.username.isEmpty ? '?' : user.username[0].toUpperCase(),
                  style: const TextStyle(
                    color: YColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: YSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.username,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: YColors.text(0.95),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: YSpace.s),
                        if (user.isAdmin)
                          _badge('ADMIN', YColors.accent)
                        else
                          _badge(
                            user.selfRegistered
                                ? 'SELF-REGISTERED'
                                : 'BY ADMIN',
                            user.selfRegistered
                                ? const Color(0xFFF2A93B)
                                : YColors.accent,
                          ),
                      ],
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: YSpace.xs),
                      Text(
                        details,
                        style: YText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: YSpace.xs),
                    Text(
                      user.subscriptionLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: subColor,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: user.active,
                onChanged:
                    user.isAdmin ? null : (v) => state.setUserActive(user.uid, v),
              ),
            ],
          ),
          const SizedBox(height: YSpace.s),
          Row(
            children: [
              Expanded(
                child: YSecondaryButton(
                  label: 'Subscription',
                  icon: Icons.timer_outlined,
                  onPressed: onGrant,
                ),
              ),
              const SizedBox(width: YSpace.s),
              IconButton(
                icon: Icon(Icons.delete_outline, color: YColors.text(0.4)),
                onPressed: user.isAdmin
                    ? null
                    : () async {
                        final confirmed = await confirmDialog(
                          context,
                          title: 'Delete user?',
                          message:
                              '"${user.username}" loses access immediately. '
                              'Tip: toggling them inactive locks them out '
                              'without losing the account. (Passwords can\'t '
                              'be reset from here — recreate the account '
                              'instead.)',
                        );
                        if (confirmed) {
                          await state.deleteUser(user);
                        }
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
