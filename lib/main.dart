import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';
import 'services/firebase_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await FirebaseService.instance.initialize();
  } catch (e) {
    developer.log(
      'Warning: Firebase initialization deferred or failed: $e. '
      'Ensure valid Firebase configuration is in place.',
      name: 'Main',
    );
  }

  runApp(const IoTSmartSwitchApp());
}

class IoTSmartSwitchApp extends StatefulWidget {
  final Stream<User?>? authStream;

  const IoTSmartSwitchApp({super.key, this.authStream});

  @override
  State<IoTSmartSwitchApp> createState() => _IoTSmartSwitchAppState();
}

class _IoTSmartSwitchAppState extends State<IoTSmartSwitchApp> {
  final ValueNotifier<ThemeMode> _themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  @override
  void dispose() {
    _themeModeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'IoT Smart Switch',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: AuthGate(
            themeModeNotifier: _themeModeNotifier,
            authStream: widget.authStream,
          ),
        );
      },
    );
  }
}
