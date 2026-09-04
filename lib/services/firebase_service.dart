import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../models/sanity_check_result.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool _isInitialized = false;
  String? _initError;

  bool get isInitialized => _isInitialized;
  String? get initError => _initError;

  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Initializes Firebase with platform-specific options.
  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _isInitialized = true;
      _initError = null;
      developer.log(
        'Firebase initialized successfully. App Name: ${Firebase.app().name}',
        name: 'FirebaseService',
      );
    } catch (e, stackTrace) {
      _isInitialized = false;
      _initError = e.toString();
      developer.log(
        'Failed to initialize Firebase: $e',
        name: 'FirebaseService',
        error: e,
        stackTrace: stackTrace,
      );
      // Re-throw so caller is aware
      rethrow;
    }
  }

  /// Runs a Firestore write-and-read sanity check.
  /// Writes a test document, reads it back, verifies integrity, and cleans up.
  Future<SanityCheckResult> runFirestoreSanityCheck() async {
    final DateTime now = DateTime.now();
    final String testDocId = 'sanity_check_${now.millisecondsSinceEpoch}';
    final DocumentReference<Map<String, dynamic>> testDocRef =
        firestore.collection('_sanity_checks').doc(testDocId);

    final Map<String, dynamic> testPayload = {
      'testId': testDocId,
      'name': 'Sanity Check Switch',
      'room': 'Diagnostic Lab',
      'isOn': true,
      'deviceId': 'esp32_sanity_probe',
      'createdAt': now.toIso8601String(),
      'description': 'Temporary document for Phase 1 verification',
    };

    try {
      developer.log(
        'Phase 1 Sanity Check: Writing document to _sanity_checks/$testDocId',
        name: 'FirebaseService',
      );

      // Step 1: Write document
      await testDocRef.set(testPayload);

      developer.log(
        'Phase 1 Sanity Check: Document written. Reading back from Firestore...',
        name: 'FirebaseService',
      );

      // Step 2: Read document back
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await testDocRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        return SanityCheckResult(
          isSuccess: false,
          step: 'READ_VERIFICATION',
          details: 'Document was written but could not be read back from Firestore.',
          timestamp: DateTime.now(),
          writtenPayload: testPayload,
          errorMessage: 'Document does not exist after write.',
        );
      }

      final Map<String, dynamic> readData = snapshot.data()!;

      // Step 3: Validate field integrity
      final bool matches = readData['name'] == testPayload['name'] &&
          readData['room'] == testPayload['room'] &&
          readData['isOn'] == testPayload['isOn'] &&
          readData['deviceId'] == testPayload['deviceId'];

      if (!matches) {
        return SanityCheckResult(
          isSuccess: false,
          step: 'DATA_INTEGRITY',
          details: 'Data mismatch between written and read document.',
          timestamp: DateTime.now(),
          writtenPayload: testPayload,
          readPayload: readData,
          errorMessage: 'Payload mismatch: $readData != $testPayload',
        );
      }

      developer.log(
        'Phase 1 Sanity Check: Field integrity verified. Cleaning up test document...',
        name: 'FirebaseService',
      );

      // Step 4: Cleanup
      await testDocRef.delete();

      developer.log(
        'Phase 1 Sanity Check: SUCCESS. Test document cleaned up.',
        name: 'FirebaseService',
      );

      return SanityCheckResult(
        isSuccess: true,
        step: 'COMPLETED',
        details: 'Firestore write, read-back, data verification, and cleanup succeeded.',
        timestamp: DateTime.now(),
        writtenPayload: testPayload,
        readPayload: readData,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Phase 1 Sanity Check Error: $e',
        name: 'FirebaseService',
        error: e,
        stackTrace: stackTrace,
      );
      // Attempt cleanup if possible
      try {
        await testDocRef.delete();
      } catch (_) {}

      return SanityCheckResult(
        isSuccess: false,
        step: 'EXCEPTION',
        details: 'Firestore sanity check failed with exception.',
        timestamp: DateTime.now(),
        writtenPayload: testPayload,
        errorMessage: e.toString(),
      );
    }
  }
}
