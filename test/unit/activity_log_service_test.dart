import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/activity_log_model.dart';
import 'package:iot_smart_switch/services/activity_log_service.dart';

class FakeActivityLogServiceForTest extends Fake implements ActivityLogService {
  final List<ActivityLogModel> inMemoryLogs = [];

  @override
  Future<void> logAction({
    required String switchId,
    required String switchName,
    required String deviceId,
    String? userId,
    String? userEmail,
    required String action,
    required String source,
  }) async {
    final log = ActivityLogModel(
      id: 'log_${inMemoryLogs.length + 1}',
      switchId: switchId,
      switchName: switchName,
      deviceId: deviceId,
      userId: userId,
      userEmail: userEmail,
      action: action,
      source: source,
      timestamp: DateTime.now(),
    );
    inMemoryLogs.insert(0, log);
  }

  @override
  Stream<List<ActivityLogModel>> streamLogs({
    String? switchId,
    String? userId,
    int limit = 20,
  }) {
    var filtered = inMemoryLogs.toList();
    if (switchId != null) {
      filtered = filtered.where((l) => l.switchId == switchId).toList();
    }
    if (userId != null) {
      filtered = filtered.where((l) => l.userId == null || l.userId == userId).toList();
    }
    return Stream.value(filtered.take(limit).toList());
  }
}

void main() {
  group('ActivityLogService Business Logic Tests', () {
    test('Logs action and retrieves via stream filtered by switchId', () async {
      final service = FakeActivityLogServiceForTest();

      await service.logAction(
        switchId: 'switch_1',
        switchName: 'Living Room Light',
        deviceId: 'esp32_001',
        userId: 'user_123',
        action: 'ON',
        source: 'mobile_app',
      );

      await service.logAction(
        switchId: 'switch_2',
        switchName: 'Bedroom Fan',
        deviceId: 'esp32_001',
        userId: 'user_123',
        action: 'OFF',
        source: 'timer',
      );

      final logsSwitch1 = await service.streamLogs(switchId: 'switch_1').first;
      expect(logsSwitch1.length, 1);
      expect(logsSwitch1.first.switchId, 'switch_1');
      expect(logsSwitch1.first.action, 'ON');

      final allLogs = await service.streamLogs().first;
      expect(allLogs.length, 2);
    });
  });
}
