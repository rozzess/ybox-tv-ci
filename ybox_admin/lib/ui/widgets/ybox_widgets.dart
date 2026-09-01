import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/admin_state.dart';
import '../../theme.dart';

/// Replaces the old "Sync to all" button (SPEC 6.3): changes now propagate
/// instantly over Firestore snapshots, so headers just show a live indicator.
class LiveIndicator extends StatelessWidget {
  const LiveIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final ok = AdminState.instance.cloudOk;
        final color = ok ? YColors.green : YColors.text(0.35);
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: YSpace.m, vertical: YSpace.xs + 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: ok
                      ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)]
                      : null,
                ),
              ),
              const SizedBox(width: YSpace.s),
              Text(
                ok ? 'LIVE' : 'OFFLINE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Primary CTA — filled accent button with subtle inner highlight.
class YPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  const YPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = YColors.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: YSpace.s),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Secondary button — accent at 8% opacity fill.
class YSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  const YSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = YColors.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: color.withOpacity(0.08),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withOpacity(0.25)),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: YSpace.s),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: YSpace.m),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: YText.section),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(YSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(YSpace.l),
              decoration: BoxDecoration(
                color: YColors.accentSoft(),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: YColors.accent),
            ),
            const SizedBox(height: YSpace.l),
            Text(title, style: YText.section, textAlign: TextAlign.center),
            const SizedBox(height: YSpace.s),
            Text(message, style: YText.caption, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: YSpace.l),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class YTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType keyboardType;

  const YTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: YSpace.m),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: TextStyle(color: YColors.text(0.9)),
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

/// Bottom-sheet scaffold used by all edit/detail sheets.
Future<T?> showYSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: YColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: YSpace.l,
        right: YSpace.l,
        top: YSpace.m,
        bottom: MediaQuery.of(context).viewInsets.bottom + YSpace.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: YSpace.m),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: YColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: YText.section),
      content: Text(message, style: YText.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: YColors.text(0.6))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: const TextStyle(
                color: YColors.danger, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
