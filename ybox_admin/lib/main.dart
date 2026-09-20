import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'services/admin_state.dart';
import 'theme.dart';
import 'ui/root_shell.dart';
import 'ui/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  runApp(const YboxAdminApp());
}

class YboxAdminApp extends StatefulWidget {
  const YboxAdminApp({super.key});

  @override
  State<YboxAdminApp> createState() => _YboxAdminAppState();
}

class _YboxAdminAppState extends State<YboxAdminApp> {
  late final Future<bool> _restore = AdminState.instance.tryRestoreSession();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YBOX Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      home: FutureBuilder<bool>(
        future: _restore,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _SplashScreen();
          }
          return AnimatedBuilder(
            animation: AdminState.instance,
            builder: (context, _) => AdminState.instance.admin != null
                ? const RootShell()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                image: const DecorationImage(
                  image: AssetImage('assets/icon_admin.png'),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: YColors.accent.withOpacity(0.3),
                    blurRadius: 40,
                  ),
                ],
              ),
            ),
            const SizedBox(height: YSpace.l),
            const Text('YBOX Admin', style: YText.title),
            const SizedBox(height: YSpace.s),
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                color: YColors.accent,
                backgroundColor: YColors.card,
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
