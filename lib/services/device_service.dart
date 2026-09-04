import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_model.dart';

class DeviceService {
  DeviceService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  static DeviceService? _instance;
  static DeviceService get instance => _instance ??= DeviceService();

  CollectionReference<Map<String, dynamic>> get devicesCollection =>
      _firestore.collection('devices');

  /// Streams all registered device telemetry documents
  Stream<List<DeviceModel>> streamDevices() {
    return devicesCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => DeviceModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Streams real-time telemetry for a specific deviceId
  Stream<DeviceModel?> streamDevice(String deviceId) {
    return devicesCollection.doc(deviceId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DeviceModel.fromFirestore(doc);
    });
  }

  /// Updates heartbeat and reported actual physical states
  Future<void> updateHeartbeat({
    required String deviceId,
    required Map<String, bool> actualStates,
  }) async {
    try {
      final docRef = devicesCollection.doc(deviceId);
      await docRef.set({
        'lastSeen': FieldValue.serverTimestamp(),
        'actualStates': actualStates,
      }, SetOptions(merge: true));

      developer.log(
        'Heartbeat recorded for $deviceId (states: $actualStates)',
        name: 'DeviceService',
      );
    } catch (e) {
      developer.log('Failed to record heartbeat: $e', name: 'DeviceService');
      rethrow;
    }
  }
}
