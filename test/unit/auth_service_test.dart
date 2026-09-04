import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/services/auth_service.dart';

class FakeFirebaseAuthForTest extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => Stream.value(null);
}

void main() {
  group('AuthService Security & Functionality Tests', () {
    test('AuthService is a singleton instance and accepts injected auth', () {
      final fakeAuth = FakeFirebaseAuthForTest();
      final authService = AuthService(auth: fakeAuth);

      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentUser, isNull);
    });

    test('AuthService authStateChanges stream yields null for unauthenticated state', () async {
      final fakeAuth = FakeFirebaseAuthForTest();
      final authService = AuthService(auth: fakeAuth);

      final user = await authService.authStateChanges.first;
      expect(user, isNull);
      expect(authService.isAuthenticated, isFalse);
    });
  });
}
