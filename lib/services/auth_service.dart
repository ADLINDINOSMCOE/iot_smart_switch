import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  String? get currentUid => _auth.currentUser?.uid;

  bool get isAuthenticated => _auth.currentUser != null;

  // =========================================================
  // SYNC USER PROFILE TO FIRESTORE (users/{uid})
  // =========================================================
  Future<void> _syncUserProfile(User? user, {String? displayName}) async {
    if (user == null) return;

    try {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final existingDoc = await userDocRef.get();

      final data = <String, dynamic>{
        'uid': user.uid,
        'email': (user.email ?? '').trim().toLowerCase(),
        'displayName': displayName ?? user.displayName ?? 'User',
        'photoUrl': user.photoURL ?? '',
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      if (!existingDoc.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await userDocRef.set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing user profile: $e');
    }
  }

  // =========================================================
  // SIGN IN WITH EMAIL & PASSWORD
  // =========================================================
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await _syncUserProfile(credential.user);
    return credential;
  }

  // =========================================================
  // SIGN UP WITH EMAIL & PASSWORD
  // =========================================================
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (displayName.trim().isNotEmpty) {
      await credential.user?.updateDisplayName(displayName.trim());
    }

    await _syncUserProfile(
      credential.user,
      displayName: displayName.trim(),
    );

    return credential;
  }

  // =========================================================
  // SIGN IN WITH GOOGLE
  // =========================================================
  Future<UserCredential> signInWithGoogle() async {
    UserCredential credential;

    if (kIsWeb) {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      credential = await _auth.signInWithPopup(googleProvider);
    } else {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final AuthCredential authCredential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      credential = await _auth.signInWithCredential(authCredential);
    }

    await _syncUserProfile(credential.user);
    return credential;
  }

  // =========================================================
  // PASSWORD RESET
  // =========================================================
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // =========================================================
  // SEND EMAIL VERIFICATION
  // =========================================================
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // =========================================================
  // DELETE USER ACCOUNT
  // =========================================================
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final uid = user.uid;

    try {
      // Clean up user profile document in Firestore
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('Warning: Failed to delete user profile document: $e');
    }

    // Sign out of Google if applicable
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }

    // Delete Firebase Auth user account
    await user.delete();
  }

  // =========================================================
  // SIGN OUT
  // =========================================================
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error during sign out: $e');
    }
  }

  // =========================================================
  // UPDATE USER PROFILE (DISPLAY NAME)
  // =========================================================
  Future<void> updateUserProfile({required String displayName}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final trimmed = displayName.trim();
    if (trimmed.isEmpty || trimmed.length > 60) {
      throw Exception('Display name must be between 1 and 60 characters.');
    }

    await user.updateDisplayName(trimmed);

    await _firestore.collection('users').doc(user.uid).set(
      {
        'displayName': trimmed,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // =========================================================
  // STREAM USER PROFILE (users/{uid})
  // =========================================================
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserProfile() {
    final uid = currentUid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // =========================================================
  // FIND USER BY EMAIL (FOR DEVICE SHARING)
  // =========================================================
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    final doc = query.docs.first;
    final data = doc.data();

    return {
      'uid': doc.id,
      'email': data['email'] ?? cleanEmail,
      'displayName': data['displayName'] ?? 'User',
    };
  }
}
