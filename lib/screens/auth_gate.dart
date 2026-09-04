import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

class AuthGate extends StatelessWidget {
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final Stream<User?>? authStream;

  const AuthGate({
    super.key,
    required this.themeModeNotifier,
    this.authStream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStream ?? AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        // While waiting for initial connection state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen(statusMessage: 'Checking authentication session...');
        }

        final User? user = snapshot.data;

        // Hard Constraint: If user is not authenticated, load ONLY LoginScreen.
        // Never load switches, schedules, or device data for unauthenticated sessions.
        if (user == null) {
          return LoginScreen(themeModeNotifier: themeModeNotifier);
        }

        // Authenticated session -> HomeScreen
        return HomeScreen(
          user: user,
          themeModeNotifier: themeModeNotifier,
        );
      },
    );
  }
}
