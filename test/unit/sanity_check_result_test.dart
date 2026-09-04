import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/sanity_check_result.dart';

void main() {
  group('SanityCheckResult Model Tests', () {
    test('Correctly instantiates success result and fields', () {
      final now = DateTime.now();
      final result = SanityCheckResult(
        isSuccess: true,
        step: 'COMPLETED',
        details: 'Firestore sanity check succeeded.',
        timestamp: now,
        writtenPayload: {'testId': '123', 'isOn': true},
        readPayload: {'testId': '123', 'isOn': true},
      );

      expect(result.isSuccess, isTrue);
      expect(result.step, 'COMPLETED');
      expect(result.details, 'Firestore sanity check succeeded.');
      expect(result.writtenPayload?['isOn'], true);
      expect(result.readPayload?['isOn'], true);
      expect(result.errorMessage, isNull);
      expect(result.toString(), contains('isSuccess: true'));
    });

    test('Correctly instantiates failure result with error message', () {
      final now = DateTime.now();
      final result = SanityCheckResult(
        isSuccess: false,
        step: 'READ_VERIFICATION',
        details: 'Document read timed out.',
        timestamp: now,
        errorMessage: 'Network timeout',
      );

      expect(result.isSuccess, isFalse);
      expect(result.step, 'READ_VERIFICATION');
      expect(result.errorMessage, 'Network timeout');
    });
  });
}
