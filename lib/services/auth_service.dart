import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth? _customAuth;
  final GoogleSignIn? _customGoogleSignIn;
  final FirebaseFirestore? _customFirestore;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  })  : _customAuth = auth,
        _customGoogleSignIn = googleSignIn,
        _customFirestore = firestore;

  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService();
  static set instance(AuthService service) => _instance = service;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => _customGoogleSignIn ?? GoogleSignIn();
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current authenticated user (null if not logged in).
  User? get currentUser => _auth.currentUser;

  /// Check if user is authenticated.
  bool get isAuthenticated => _auth.currentUser != null;

  /// Safely creates/syncs user document in users/{uid}
  Future<void> _syncUserProfile(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      await docRef.set({
        'name': user.displayName ?? user.email?.split('@').first ?? 'User',
        'email': user.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log('Non-critical: User profile sync deferred: $e',
          name: 'AuthService');
    }
  }

  /// Sign in with Email and Password.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      developer.log('Attempting email sign-in for: $email', name: 'AuthService');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null) {
        await _syncUserProfile(credential.user!);
      }
      developer.log(
        'Sign-in successful. UID: ${credential.user?.uid}',
        name: 'AuthService',
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      developer.log('FirebaseAuthException during sign-in: ${e.code}', name: 'AuthService');
      throw _handleAuthException(e);
    } catch (e) {
      developer.log('Unexpected error during sign-in: $e', name: 'AuthService');
      throw Exception('An unexpected error occurred during login. Please try again.');
    }
  }

  /// Create user with Email and Password.
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      developer.log('Attempting email registration for: $email', name: 'AuthService');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null) {
        await _syncUserProfile(credential.user!);
      }
      developer.log(
        'Registration successful. UID: ${credential.user?.uid}',
        name: 'AuthService',
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      developer.log('FirebaseAuthException during registration: ${e.code}', name: 'AuthService');
      throw _handleAuthException(e);
    } catch (e) {
      developer.log('Unexpected error during registration: $e', name: 'AuthService');
      throw Exception('An unexpected error occurred during registration. Please try again.');
    }
  }

  /// Send official Firebase password reset email.
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      developer.log('Sending password reset email to: $email', name: 'AuthService');
      await _auth.sendPasswordResetEmail(email: email.trim());
      developer.log('Password reset email dispatched successfully.', name: 'AuthService');
    } on FirebaseAuthException catch (e) {
      developer.log('FirebaseAuthException during password reset: ${e.code}', name: 'AuthService');
      throw _handleAuthException(e);
    } catch (e) {
      developer.log('Unexpected error during password reset: $e', name: 'AuthService');
      throw Exception('Failed to send password reset email. Please try again.');
    }
  }

  /// Send official Firebase email verification to current user.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user session found.');
    }
    try {
      developer.log('Sending email verification to: ${user.email}', name: 'AuthService');
      await user.sendEmailVerification();
      developer.log('Verification email dispatched successfully.', name: 'AuthService');
    } on FirebaseAuthException catch (e) {
      developer.log('FirebaseAuthException during email verification: ${e.code}', name: 'AuthService');
      throw _handleAuthException(e);
    } catch (e) {
      developer.log('Unexpected error during email verification: $e', name: 'AuthService');
      throw Exception('Failed to send verification email. Please try again.');
    }
  }

  /// Sign in with Google Account.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      developer.log('Initiating Google Sign-In flow', name: 'AuthService');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        developer.log('Google Sign-In canceled by user', name: 'AuthService');
        return null; // User canceled the sign-in flow
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _syncUserProfile(userCredential.user!);
      }
      developer.log(
        'Google Sign-In successful. UID: ${userCredential.user?.uid}',
        name: 'AuthService',
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      developer.log('FirebaseAuthException during Google Sign-In: ${e.code}', name: 'AuthService');
      throw _handleAuthException(e);
    } catch (e) {
      developer.log('Unexpected error during Google Sign-In: $e', name: 'AuthService');
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }

  /// Reload current user profile & token freshness.
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      developer.log('Error reloading user profile: $e', name: 'AuthService');
    }
  }

  /// Delete current user account and clean up their private document in users/{userId}.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user session found.');
    }
    final uid = user.uid;
    try {
      developer.log('Deleting user account: $uid', name: 'AuthService');
      // Clean up user token document in Firestore
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      } catch (docErr) {
        developer.log('Warning: could not delete user doc $uid: $docErr', name: 'AuthService');
      }

      await user.delete();
      await _googleSignIn.signOut();
      developer.log('Account deleted successfully.', name: 'AuthService');
    } on FirebaseAuthException catch (e) {
      developer.log('FirebaseAuthException during account deletion: ${e.code}', name: 'AuthService');
      if (e.code == 'requires-recent-login') {
        throw Exception('This operation is sensitive and requires recent authentication. Please log out and sign in again before deleting your account.');
      }
      throw _handleAuthException(e);
    } catch (e) {
      developer.log('Unexpected error during account deletion: $e', name: 'AuthService');
      throw Exception('Account deletion failed: $e');
    }
  }

  /// Sign out current user from Firebase & Google.
  Future<void> signOut() async {
    try {
      developer.log('Signing out current user...', name: 'AuthService');
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      developer.log('Sign-out completed successfully.', name: 'AuthService');
    } catch (e) {
      developer.log('Error during sign-out: $e', name: 'AuthService');
      throw Exception('Sign-out failed. Please try again.');
    }
  }

  /// Maps Firebase error codes to clean, human-readable error messages.
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found registered with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please verify and try again.';
      case 'invalid-email':
        return 'The email address format is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'operation-not-allowed':
        return 'This sign-in method is currently not enabled in Firebase Console.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection.';
      case 'invalid-credential':
        return 'Invalid credentials provided. Please try again.';
      case 'requires-recent-login':
        return 'This action requires recent authentication. Please sign in again.';
      case 'too-many-requests':
        return 'Too many attempts. Access temporarily blocked. Try again later.';
      case 'expired-action-code':
        return 'The reset/verification code has expired.';
      case 'invalid-action-code':
        return 'The reset/verification code is invalid.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
