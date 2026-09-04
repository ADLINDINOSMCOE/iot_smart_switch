import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/switch_model.dart';

class SwitchService {
  SwitchService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  static SwitchService? _instance;
  static SwitchService get instance => _instance ??= SwitchService();

  /// Reference to the authoritative `switches` Firestore collection
  CollectionReference<Map<String, dynamic>> get switchesCollection =>
      _firestore.collection('switches');

  /// Sample Switch seed dataset according to Phase 3 specification
  static final List<SwitchModel> sampleSwitches = [
    const SwitchModel(
      id: 'switch_1',
      name: 'Living Room Main Light',
      room: 'Living Room',
      isOn: false,
      deviceId: 'esp32_001',
    ),
    const SwitchModel(
      id: 'switch_2',
      name: 'Ceiling Fan',
      room: 'Living Room',
      isOn: false,
      deviceId: 'esp32_001',
    ),
    const SwitchModel(
      id: 'switch_3',
      name: 'Kitchen Overhead Lamp',
      room: 'Kitchen',
      isOn: false,
      deviceId: 'esp32_001',
    ),
    const SwitchModel(
      id: 'switch_4',
      name: 'Bedroom Nightstand Lamp',
      room: 'Bedroom',
      isOn: false,
      deviceId: 'esp32_002',
    ),
  ];

  /// Stream of all accessible switches from Cloud Firestore
  Stream<List<SwitchModel>> streamSwitches({String? userId}) {
    return switchesCollection.snapshots().map((snapshot) {
      final docs = snapshot.docs.map((doc) => SwitchModel.fromFirestore(doc)).toList();
      if (userId == null) return docs;
      return docs.where((s) => s.ownerId == null || s.ownerId == userId).toList();
    });
  }

  /// Stream of a single switch document by ID
  Stream<SwitchModel?> streamSwitch(String switchId) {
    return switchesCollection.doc(switchId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return SwitchModel.fromFirestore(snapshot);
    });
  }

  /// Stream of switches bound to a specific deviceId (used by hardware/scoping)
  Stream<List<SwitchModel>> streamSwitchesForDevice(String deviceId) {
    return switchesCollection
        .where('deviceId', isEqualTo: deviceId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return SwitchModel.fromFirestore(doc);
      }).toList();
    });
  }

  /// Fetch all accessible switches one-time
  Future<List<SwitchModel>> getSwitches({String? userId}) async {
    try {
      final snapshot = await switchesCollection.get();
      final docs = snapshot.docs.map((doc) => SwitchModel.fromFirestore(doc)).toList();
      if (userId == null) return docs;
      return docs.where((s) => s.ownerId == null || s.ownerId == userId).toList();
    } catch (e) {
      developer.log('Error fetching switches: $e', name: 'SwitchService');
      rethrow;
    }
  }

  /// Updates the `isOn` state of a switch in Cloud Firestore
  Future<void> setSwitchState({
    required String switchId,
    required bool isOn,
  }) async {
    try {
      developer.log(
        'Updating switch $switchId -> isOn: $isOn',
        name: 'SwitchService',
      );
      await switchesCollection.doc(switchId).update({
        'isOn': isOn,
      });
      developer.log('Switch $switchId updated successfully', name: 'SwitchService');
    } catch (e) {
      developer.log('Failed to update switch $switchId: $e', name: 'SwitchService');
      rethrow;
    }
  }

  /// Toggles switch `isOn` state based on current value
  Future<void> toggleSwitch({
    required String switchId,
    required bool currentIsOn,
  }) async {
    await setSwitchState(switchId: switchId, isOn: !currentIsOn);
  }

  /// Seeds sample switch documents (switch_1 .. switch_4) in Firestore
  Future<void> seedSampleSwitches({String? userId, bool overwrite = false}) async {
    try {
      developer.log('Starting seed of sample switches...', name: 'SwitchService');
      final batch = _firestore.batch();

      for (final s in sampleSwitches) {
        final docRef = switchesCollection.doc(s.id);
        if (!overwrite) {
          final doc = await docRef.get();
          if (doc.exists) {
            developer.log(
              'Switch doc ${s.id} already exists, skipping overwrite.',
              name: 'SwitchService',
            );
            continue;
          }
        }
        final switchWithUser = userId != null ? s.copyWith(ownerId: userId) : s;
        batch.set(docRef, switchWithUser.toMap());
      }

      await batch.commit();
      developer.log('Sample switches seeded successfully.', name: 'SwitchService');
    } catch (e) {
      developer.log('Error seeding sample switches: $e', name: 'SwitchService');
      rethrow;
    }
  }
}
