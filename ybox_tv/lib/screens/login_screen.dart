import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/segmented_toggle.dart';

/// Entry gate: sign in with an existing account or create a new one.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _mode = 0; // 0 = sign in, 1 = create account

  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  bool _busy = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_user.text.trim().length < 3) {
      return 'Username must be at least 3 characters.';
    }
    if (_pass.text.length < 4) {
      return 'Password must be at least 4 characters.';
    }
    if (_mode == 1) {
      if (_name.text.trim().isEmpty) return 'Enter your name.';
      if (_phone.text.trim().length < 6) return 'Enter a valid phone number.';
      final email = _email.text.trim();
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        return 'Enter a valid email address.';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final invalid = _validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = AppScope.read(context);
    final err = _mode == 0
        ? await state.login(_user.text.trim(), _pass.text)
        : await state.register(
            username: _user.text.trim(),
            password: _pass.text,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
          );
    if (!mounted) return;
    if (err == null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _success = true;
        _busy = false;
      });
      // AppState.notifyListeners flips needsLogin and the root swaps screens.
    } else {
      setState(() {
        _error = err;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo orb
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF35E82A), Ybox.accentDark],
                        ),
                        boxShadow: Ybox.glow(_success ? 0.7 : 0.35),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Y',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text('Welcome to YBOX TV',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      isRegister
                          ? 'Create your account to get started'
                          : 'Sign in with your account',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SegmentedToggle(
                    segments: const ['Sign in', 'Create account'],
                    selected: _mode,
                    onChanged: (i) => setState(() {
                      _mode = i;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _user,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'Username',
                      prefixIcon:
                          Icon(Icons.person_rounded, color: Ybox.accent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    textInputAction: isRegister
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onSubmitted: isRegister ? null : (_) => _submit(),
                    decoration: const InputDecoration(
                      hintText: 'Password',
                      prefixIcon: Icon(Icons.lock_rounded, color: Ybox.accent),
                    ),
                  ),
                  // Registration details
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: !isRegister
                        ? const SizedBox.shrink()
                        : Column(
                            children: [
                              const SizedBox(height: 12),
                              TextField(
                                controller: _name,
                                textInputAction: TextInputAction.next,
                                textCapitalization:
                                    TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'Full name',
                                  prefixIcon: Icon(Icons.badge_rounded,
                                      color: Ybox.accent),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  hintText: 'Phone number',
                                  prefixIcon: Icon(Icons.phone_rounded,
                                      color: Ybox.accent),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                onSubmitted: (_) => _submit(),
                                decoration: const InputDecoration(
                                  hintText: 'Email',
                                  prefixIcon: Icon(Icons.email_rounded,
                                      color: Ybox.accent),
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style:
                            const TextStyle(color: Ybox.danger, fontSize: 13)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : Text(isRegister ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      isRegister
                          ? 'Your access is activated by the admin after '
                              'you register.'
                          : 'No account? Create one, or ask your admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Ybox.textDim),
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
