import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/session.dart';
import 'core/theme.dart';
import 'screens/permissions_screen.dart';
import 'screens/shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlay);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const BusinessConnectApp());
}

class BusinessConnectApp extends StatelessWidget {
  const BusinessConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Business Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      builder: (context, child) {
        // Keep the layout faithful to the mockups regardless of device font scale.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.15,
            ),
          ),
          child: child!,
        );
      },
      home: const AppLauncher(),
    );
  }
}

/// Restores a saved session, then shows either the app shell or onboarding.
class AppLauncher extends StatefulWidget {
  const AppLauncher({super.key});

  @override
  State<AppLauncher> createState() => _AppLauncherState();
}

class _AppLauncherState extends State<AppLauncher> {
  final AppSession _session = AppSession.instance;
  late final Future<void> _restore = _session.restore();

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        return _session.isSignedIn
            ? const ShellScreen()
            : const PermissionsScreen();
      },
    );
  }
}
