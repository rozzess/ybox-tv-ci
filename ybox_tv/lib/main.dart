import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/device_service.dart';
import 'services/pip_service.dart';
import 'screens/root_shell.dart';
import 'screens/tv_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  PipService.init();
  await DeviceService.init();
  if (DeviceService.isTv) {
    // Low-RAM boxes: Flutter's default 100 MiB / 1000-entry image cache is
    // enough to get the whole app OOM-killed once big channel grids scroll.
    PaintingBinding.instance.imageCache
      ..maximumSize = 300
      ..maximumSizeBytes = 48 << 20;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // TVs are landscape like Netflix/Apple TV; phones keep the portrait shell.
  SystemChrome.setPreferredOrientations(DeviceService.isTv
      ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
      : [DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  final state = AppState();
  state.init();
  runApp(YboxApp(state: state));
}

class YboxApp extends StatelessWidget {
  final AppState state;

  const YboxApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'YBOX TV',
        debugShowCheckedModeBanner: false,
        theme: Ybox.theme(),
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) {
            if (!state.initialized) return const _Splash();
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: state.needsLogin
                  ? const LoginScreen()
                  : (DeviceService.isTv ? const TvShell() : const RootShell()),
            );
          },
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF35E82A), Ybox.accentDark],
                ),
                boxShadow: Ybox.glow(0.5),
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
            const SizedBox(height: 24),
            const Text(
              'YBOX TV',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Ybox.textHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
