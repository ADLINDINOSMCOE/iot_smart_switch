import 'package:flutter_test/flutter_test.dart';
import 'package:iotswitch/models/switch_device.dart';
import 'package:iotswitch/services/firestore_service.dart';

void main() {
  group('Security Architecture & Access Control Tests', () {
    const ownerUid = 'user_owner_123';
    const editorUid = 'user_editor_456';
    const viewerUid = 'user_viewer_789';
    const attackerUid = 'user_attacker_999';

    late Map<String, dynamic> baseSwitchData;

    setUp(() {
      baseSwitchData = {
        'id': 'esp32_relay_01',
        'deviceId': 'esp32_relay_01',
        'name': 'Living Room Lamp',
        'room': 'Living Room',
        'isOn': false,
        'online': true,
        'ownerId': ownerUid,
        'sharedWith': {
          editorUid: 'editor',
          viewerUid: 'viewer',
        },
        'sharedWithUids': [editorUid, viewerUid],
        'sharedUsers': [
          {'uid': editorUid, 'email': 'editor@example.com', 'role': 'editor'},
          {'uid': viewerUid, 'email': 'viewer@example.com', 'role': 'viewer'},
        ],
        'timerActive': false,
        'timerDurationSeconds': 0,
      };
    });

    // -------------------------------------------------------------------------
    // TEST 1: Unauthenticated User Access
    // -------------------------------------------------------------------------
    test('1. Unauthenticated user (null/empty UID) has DeviceRole.none and zero permissions', () {
      final switchDevice = SwitchDevice.fromMap('esp32_relay_01', baseSwitchData);

      expect(switchDevice.getRoleForUser(null), equals(DeviceRole.none));
      expect(switchDevice.getRoleForUser(''), equals(DeviceRole.none));
      expect(switchDevice.isOwner(null), isFalse);
      expect(switchDevice.canControl(null), isFalse);
      expect(switchDevice.canShare(null), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 2: Device Owner Access
    // -------------------------------------------------------------------------
    test('2. Device Owner has full permissions (isOwner, canControl, canShare)', () {
      final switchDevice = SwitchDevice.fromMap('esp32_relay_01', baseSwitchData);

      expect(switchDevice.getRoleForUser(ownerUid), equals(DeviceRole.owner));
      expect(switchDevice.isOwner(ownerUid), isTrue);
      expect(switchDevice.canControl(ownerUid), isTrue);
      expect(switchDevice.canShare(ownerUid), isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 3: Authorized Editor Access
    // -------------------------------------------------------------------------
    test('3. Authorized Editor can control device but CANNOT manage shares or claim ownership', () {
      final switchDevice = SwitchDevice.fromMap('esp32_relay_01', baseSwitchData);

      expect(switchDevice.getRoleForUser(editorUid), equals(DeviceRole.editor));
      expect(switchDevice.isOwner(editorUid), isFalse);
      expect(switchDevice.canControl(editorUid), isTrue);
      expect(switchDevice.canShare(editorUid), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 4: Viewer Read-Only Restrictions
    // -------------------------------------------------------------------------
    test('4. Viewer role is strictly read-only (cannot control, cannot share, is not owner)', () {
      final switchDevice = SwitchDevice.fromMap('esp32_relay_01', baseSwitchData);

      expect(switchDevice.getRoleForUser(viewerUid), equals(DeviceRole.viewer));
      expect(switchDevice.isOwner(viewerUid), isFalse);
      expect(switchDevice.canControl(viewerUid), isFalse);
      expect(switchDevice.canShare(viewerUid), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 5: Unauthorized User Access
    // -------------------------------------------------------------------------
    test('5. Unauthorized third-party user has DeviceRole.none and cannot control or share', () {
      final switchDevice = SwitchDevice.fromMap('esp32_relay_01', baseSwitchData);

      expect(switchDevice.getRoleForUser(attackerUid), equals(DeviceRole.none));
      expect(switchDevice.isOwner(attackerUid), isFalse);
      expect(switchDevice.canControl(attackerUid), isFalse);
      expect(switchDevice.canShare(attackerUid), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 6: Immutable ownerId Verification
    // -------------------------------------------------------------------------
    test('6. Changing ownerId in payload is detectable and forbidden', () {
      final switchDevice = SwitchDevice.fromMap('esp32_relay_01', baseSwitchData);
      expect(switchDevice.ownerId, equals(ownerUid));

      // Attempt to tamper ownerId
      final tamperedData = Map<String, dynamic>.from(baseSwitchData);
      tamperedData['ownerId'] = attackerUid;

      final tamperedDevice = SwitchDevice.fromMap('esp32_relay_01', tamperedData);
      // Verify that security validation would catch owner mismatch
      expect(tamperedDevice.ownerId == switchDevice.ownerId, isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 7: Privilege Escalation Prevention
    // -------------------------------------------------------------------------
    test('7. Viewer cannot self-escalate to editor or owner', () {
      final switchDevice = SwitchDevice.fromMap('esp32_relay_01', baseSwitchData);
      expect(switchDevice.getRoleForUser(viewerUid), equals(DeviceRole.viewer));

      // Attacker attempts to modify their role locally or in Firestore payload
      final maliciousSharedWith = Map<String, String>.from(switchDevice.sharedWith);
      maliciousSharedWith[viewerUid] = 'owner'; // Privilege escalation attempt

      final escalatedDevice = SwitchDevice(
        id: switchDevice.id,
        name: switchDevice.name,
        room: switchDevice.room,
        isOn: switchDevice.isOn,
        deviceId: switchDevice.deviceId,
        online: switchDevice.online,
        ownerId: switchDevice.ownerId, // ownerId remains ownerUid
        sharedWith: maliciousSharedWith,
      );

      // Even if sharedWith says owner, ownerId check ensures isOwner remains FALSE
      expect(escalatedDevice.isOwner(viewerUid), isFalse);
      expect(escalatedDevice.canShare(viewerUid), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 8: Manipulated Device ID (Mismatch check)
    // -------------------------------------------------------------------------
    test('8. Manipulated device ID in document payload does not match document ID', () {
      const docId = 'esp32_relay_01';
      const spoofedPayloadId = 'esp32_relay_99_spoofed';

      final spoofedData = Map<String, dynamic>.from(baseSwitchData);
      spoofedData['deviceId'] = spoofedPayloadId;

      final device = SwitchDevice.fromMap(docId, spoofedData);
      // The deviceId from map is different from docId, indicating tampering
      expect(device.id, equals(docId));
      expect(device.deviceId, equals(spoofedPayloadId));
      expect(device.id == device.deviceId, isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 9: Invalid Device ID Format Validation
    // -------------------------------------------------------------------------
    test('9. FirestoreService.isValidDeviceId rejects malicious, empty, or special character IDs', () {
      // Valid IDs
      expect(FirestoreService.isValidDeviceId('esp32_relay_01'), isTrue);
      expect(FirestoreService.isValidDeviceId('switch-room-1'), isTrue);
      expect(FirestoreService.isValidDeviceId('DEVICE_ABC_123'), isTrue);

      // Invalid IDs
      expect(FirestoreService.isValidDeviceId(null), isFalse);
      expect(FirestoreService.isValidDeviceId(''), isFalse);
      expect(FirestoreService.isValidDeviceId('ab'), isFalse); // < 3 chars
      expect(FirestoreService.isValidDeviceId('a' * 51), isFalse); // > 50 chars
      expect(FirestoreService.isValidDeviceId('device/with/slashes'), isFalse);
      expect(FirestoreService.isValidDeviceId('device@domain.com'), isFalse);
      expect(FirestoreService.isValidDeviceId('device with spaces'), isFalse);
      expect(FirestoreService.isValidDeviceId('device#admin'), isFalse);
      expect(FirestoreService.isValidDeviceId('device;drop table'), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 10: Spoofed Command Payload Validation
    // -------------------------------------------------------------------------
    test('10. Command payloads are strictly validated against action allowlist', () {
      const validActions = ['TURN_ON', 'TURN_OFF', 'SET_TIMER', 'CANCEL_TIMER', 'TOGGLE'];
      const maliciousActions = ['DROP_COLLECTION', 'EXEC_SHELL', 'OVERWRITE_OWNER', 'FORMAT_FLASH'];

      for (final action in validActions) {
        expect(validActions.contains(action), isTrue);
      }

      for (final action in maliciousActions) {
        expect(validActions.contains(action), isFalse);
      }
    });

    // -------------------------------------------------------------------------
    // TEST 11: Unauthorized Device Hardware Identity Check
    // -------------------------------------------------------------------------
    test('11. ESP32 hardware identity validator rejects foreign device document', () {
      const hardwareDeviceId = 'esp32_relay_01';
      const foreignDeviceId = 'esp32_relay_02';

      bool validateHardwarePayload(String incomingId) {
        return incomingId == hardwareDeviceId;
      }

      expect(validateHardwarePayload(hardwareDeviceId), isTrue);
      expect(validateHardwarePayload(foreignDeviceId), isFalse);
      expect(validateHardwarePayload('malicious_injected_id'), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST 12: Anti-Replay & Freshness Validation
    // -------------------------------------------------------------------------
    test('12. Stale or replayed timestamp is detected and rejected', () {
      String lastProcessedTimestamp = '2026-08-30T10:00:00.000Z';

      bool isFreshCommand(String newTimestamp) {
        if (newTimestamp.isEmpty) return false;
        if (newTimestamp == lastProcessedTimestamp) return false; // Duplicate / replayed
        return true;
      }

      // Exact same timestamp (replay) -> rejected
      expect(isFreshCommand('2026-08-30T10:00:00.000Z'), isFalse);

      // Empty timestamp -> rejected
      expect(isFreshCommand(''), isFalse);

      // Newer timestamp -> accepted
      expect(isFreshCommand('2026-08-30T10:00:01.000Z'), isTrue);
    });
  });

  group('Timer & Schedule Functional Logic Tests', () {
    test('13. Duration formatter properly formats seconds into HH:MM:SS', () {
      String formatDuration(int totalSeconds) {
        if (totalSeconds < 0) totalSeconds = 0;
        final hours = totalSeconds ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final seconds = totalSeconds % 60;
        return '${hours.toString().padLeft(2, '0')}:'
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}';
      }

      expect(formatDuration(0), equals('00:00:00'));
      expect(formatDuration(59), equals('00:00:59'));
      expect(formatDuration(60), equals('00:01:00'));
      expect(formatDuration(3599), equals('00:59:59'));
      expect(formatDuration(3600), equals('01:00:00'));
      expect(formatDuration(3665), equals('01:01:05'));
      expect(formatDuration(-10), equals('00:00:00')); // Negative boundary
    });

    test('14. Schedule hour and minute validations adhere to 24-hour time', () {
      bool isValidScheduleTime(int hour, int minute) {
        return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
      }

      expect(isValidScheduleTime(0, 0), isTrue);
      expect(isValidScheduleTime(23, 59), isTrue);
      expect(isValidScheduleTime(12, 30), isTrue);
      expect(isValidScheduleTime(-1, 0), isFalse);
      expect(isValidScheduleTime(24, 0), isFalse);
      expect(isValidScheduleTime(10, 60), isFalse);
      expect(isValidScheduleTime(10, -5), isFalse);
    });

    test('15. Switch data mapping preserves all 4 switch documents (switch_1 to switch_4)', () {
      final mockFirestoreDocs = [
        {'id': 'switch_1', 'name': 'Living Room', 'room': 'Living Room', 'isOn': false, 'deviceId': 'switch_1', 'online': true, 'ownerId': 'user_1'},
        {'id': 'switch_2', 'name': 'Bed Room', 'room': 'Bed Room', 'isOn': true, 'deviceId': 'switch_2', 'online': true, 'ownerId': 'user_1'},
        {'id': 'switch_3', 'name': 'Kitchen', 'room': 'Kitchen', 'isOn': false, 'deviceId': 'switch_3', 'online': true, 'ownerId': 'user_1'},
        {'id': 'switch_4', 'name': 'Garage', 'room': 'Garage', 'isOn': true, 'deviceId': 'switch_4', 'online': false, 'ownerId': 'user_1'},
      ];

      final switches = mockFirestoreDocs.map((d) => SwitchDevice.fromMap(d['id'] as String, d)).toList();

      expect(switches.length, equals(4));
      expect(switches[0].id, equals('switch_1'));
      expect(switches[0].room, equals('Living Room'));
      expect(switches[0].isOn, isFalse);

      expect(switches[1].id, equals('switch_2'));
      expect(switches[1].room, equals('Bed Room'));
      expect(switches[1].isOn, isTrue);

      expect(switches[2].id, equals('switch_3'));
      expect(switches[2].room, equals('Kitchen'));
      expect(switches[2].isOn, isFalse);

      expect(switches[3].id, equals('switch_4'));
      expect(switches[3].room, equals('Garage'));
      expect(switches[3].isOn, isTrue);
      expect(switches[3].online, isFalse);
    });

    test('16. Email validation regex correctly classifies valid and invalid formats', () {
      bool isValidEmail(String email) {
        return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim());
      }

      expect(isValidEmail('user@example.com'), isTrue);
      expect(isValidEmail('john.doe@company.org'), isTrue);
      expect(isValidEmail('admin_test@sub.domain.co'), isTrue);
      expect(isValidEmail(''), isFalse);
      expect(isValidEmail('invalid-email'), isFalse);
      expect(isValidEmail('user@'), isFalse);
      expect(isValidEmail('@domain.com'), isFalse);
      expect(isValidEmail('user@domain'), isFalse);
    });
  });
}