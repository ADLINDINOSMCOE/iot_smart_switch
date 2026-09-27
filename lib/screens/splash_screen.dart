import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    try {
      // Wait concurrently for the splash delay and for Firebase Auth
      // to restore the persisted session from local storage.
      final results = await Future.wait([
        Future.delayed(const Duration(seconds: 2)),
        FirebaseAuth.instance.authStateChanges().first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => FirebaseAuth.instance.currentUser,
        ),
      ]);

      if (!mounted) return;

      final User? user = results[1] as User?;

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Safe fallback in case of any stream or platform error
      final User? fallbackUser = FirebaseAuth.instance.currentUser;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => fallbackUser != null
              ? const HomeScreen()
              : const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081726),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // App Icon
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2438),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF1976D2),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x551976D2),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.white,
                  size: 80,
                ),
              ),

              const SizedBox(height: 35),

              // App Name
              const Text(
                'IoT Switch',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 10),

              // Tagline
              const Text(
                'Smart Control, Smarter Life',
                style: TextStyle(
                  color: Color(0xFF9ECAF5),
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 70),

              const Text(
                'Loading...',
                style: TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 15),

              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1976D2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}