import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_log_model.dart';

class ActivityLogService {
  ActivityLogService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  static ActivityLogService? _instance;
  static ActivityLogService get instance =>
      _instance ??= ActivityLogService();

  CollectionReference<Map<String, dynamic>> get logsCollection =>
      _firestore.collection('activity_logs');

  /// Records a user or automation action to the audit trail
  Future<void> logAction({
    required String switchId,
    required String switchName,
    required String deviceId,
    String? userId,
    String? userEmail,
    required String action,
    required String source,
  }) async {
    try {
      final docRef = logsCollection.doc();
      final log = ActivityLogModel(
        id: docRef.id,
        switchId: switchId,
        switchName: switchName,
        deviceId: deviceId,
        userId: userId,
        userEmail: userEmail,
        action: action,
        source: source,
        timestamp: DateTime.now(),
      );

      await docRef.set(log.toMap());
      developer.log('Logged activity: ${log.action} on ${log.switchName}',
          name: 'ActivityLogService');
    } catch (e) {
      developer.log('Non-critical: Activity logging failed: $e',
          name: 'ActivityLogService');
    }
  }

  /// Streams recent activity logs with optional switch or user filter
  Stream<List<ActivityLogModel>> streamLogs({
    String? switchId,
    String? userId,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> query =
        logsCollection.orderBy('timestamp', descending: true).limit(limit);

    if (switchId != null) {
      query = query.where('switchId', isEqualTo: switchId);
    }

    return query.snapshots().map((snap) {
      final logs = snap.docs.map((doc) => ActivityLogModel.fromFirestore(doc)).toList();
      if (userId == null) return logs;
      return logs.where((l) => l.userId == null || l.userId == userId).toList();
    });
  }
}
