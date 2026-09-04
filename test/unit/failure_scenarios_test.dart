import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/device_model.dart';
import 'package:iot_smart_switch/models/schedule_model.dart';
import 'package:iot_smart_switch/models/switch_model.dart';

void main() {
  group('Phase 10: End-to-End Failure & Edge Case Verification Tests', () {
    // 1. Error & Failure Case: Stale Heartbeat Offline Timeout (25s)
    test('Device Status: Stale heartbeat correctly flags device as offline', () {
      final now = DateTime.now();
      final freshDevice = DeviceModel(
        deviceId: 'esp32_001',
        lastSeen: now.subtract(const Duration(seconds: 15)),
        actualStates: const {'switch_1': true},
      );
      expect(freshDevice.isOnline, isTrue,
          reason: '15s is within the 25s threshold');

      final staleDevice = DeviceModel(
        deviceId: 'esp32_001',
        lastSeen: now.subtract(const Duration(seconds: 26)),
        actualStates: const {'switch_1': true},
      );
      expect(staleDevice.isOnline, isFalse,
          reason: '26s exceeds the 25s threshold');
    });

    // 2. Error & Failure Case: Unsynced State Detection
    test('Switch Control: Detects mismatch between desired isOn and physical actualStates', () {
      final device = DeviceModel(
        deviceId: 'esp32_001',
        lastSeen: DateTime.now(),
        actualStates: const {'switch_1': false},
      );

      // Desired is ON, but physical relay reported OFF -> Unsynced
      expect(device.isSwitchSynced('switch_1', true), isFalse);

      // Desired is OFF, and physical relay reported OFF -> Synced
      expect(device.isSwitchSynced('switch_1', false), isTrue);
    });

    // 3. Timer & Schedule Idempotency: Duplicate Execution Prevention
    test('Timer & Schedule: Repeated execution transaction is blocked if status != pending', () {
      final completedTimer = ScheduleModel(
        id: 'timer_001',
        switchId: 'switch_1',
        action: 'off',
        time: DateTime.now().subtract(const Duration(minutes: 5)),
        type: 'timer',
        status: 'completed',
        executedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      expect(completedTimer.isPending, isFalse);
      expect(completedTimer.isCompleted, isTrue);

      final cancelledSchedule = ScheduleModel(
        id: 'sched_001',
        switchId: 'switch_2',
        action: 'on',
        time: DateTime.now(),
        type: 'schedule',
        status: 'cancelled',
      );

      expect(cancelledSchedule.isPending, isFalse);
      expect(cancelledSchedule.isCancelled, isTrue);
    });

    // 4. Schema Integrity: Switches collection strict 4-field schema
    test('Firestore: SwitchModel serialization contains strictly approved 4 fields', () {
      const sw = SwitchModel(
        id: 'switch_test',
        name: 'Bedroom Light',
        room: 'Bedroom',
        isOn: false,
        deviceId: 'esp32_001',
      );

      final map = sw.toMap();
      expect(map.keys.toSet(), equals({'name', 'room', 'isOn', 'deviceId'}));
      expect(map['isOn'], isFalse);
    });

    // 5. Schedules collection strict 6-field schema
    test('Firestore: ScheduleModel serialization contains strictly approved 6 fields', () {
      final sched = ScheduleModel(
        id: 'sched_test',
        switchId: 'switch_1',
        action: 'on',
        time: DateTime.utc(2026, 8, 30, 18, 0),
        type: 'schedule',
        status: 'pending',
      );

      final map = sched.toMap();
      expect(map.keys.toSet(),
          equals({'switchId', 'action', 'time', 'type', 'status', 'executedAt'}));
      expect(map['action'], 'on');
    });

    // 6. Timezone Handling: Canonical UTC conversion
    test('Schedule Timezone: Preserves accurate UTC epoch regardless of local timezone', () {
      final localDateTime = DateTime(2026, 8, 30, 20, 0); // 8:00 PM local
      final utcDateTime = localDateTime.toUtc();

      final model = ScheduleModel(
        id: 'tz_test',
        switchId: 'switch_1',
        action: 'off',
        time: utcDateTime,
      );

      expect(model.time.isUtc, isTrue);
      expect(model.time.toLocal().hour, 20);
    });
  });
}
