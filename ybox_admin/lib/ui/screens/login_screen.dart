import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/admin_state.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../widgets/entrance.dart';
import '../widgets/ybox_widgets.dart';

/// Admin sign-in — only accounts with role 'admin' get past this screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile =
          await AdminAuth.signIn(_username.text, _password.text);
      HapticFeedback.mediumImpact();
      await AdminState.instance.onSignedIn(profile);
      // main.dart's AnimatedBuilder swaps to RootShell automatically.
    } catch (e) {
      setState(() => _error = e is String ? e : 'Sign-in failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(YSpace.l),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Entrance(
                    index: 0,
                    child: Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          image: const DecorationImage(
                            image: AssetImage('assets/icon_admin.png'),
                            fit: BoxFit.cover,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: YColors.accent.withOpacity(0.35),
                              blurRadius: 36,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: YSpace.l),
                  const Entrance(
                    index: 1,
                    child: Center(
                        child: Text('YBOX Admin', style: YText.title)),
                  ),
                  const SizedBox(height: YSpace.xs),
                  Entrance(
                    index: 2,
                    child: Center(
                      child: Text(
                        'Sign in with your admin account',
                        style: YText.caption,
                      ),
                    ),
                  ),
                  const SizedBox(height: YSpace.xl),
                  Entrance(
                    index: 3,
                    child: YTextField(
                      controller: _username,
                      label: 'Username',
                    ),
                  ),
                  Entrance(
                    index: 4,
                    child: YTextField(
                      controller: _password,
                      label: 'Password',
                      obscure: true,
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: YSpace.m),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: YColors.danger, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Entrance(
                    index: 5,
                    child: YPrimaryButton(
                      label: _busy ? 'Signing in…' : 'Sign in',
                      icon: Icons.lock_open,
                      onPressed: _busy ? null : _signIn,
                    ),
                  ),
                  const SizedBox(height: YSpace.m),
                  Entrance(
                    index: 6,
                    child: Text(
                      'Only admin accounts can use this app. Fleet control '
                      'works from anywhere — no LAN setup needed.',
                      style: YText.caption,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
