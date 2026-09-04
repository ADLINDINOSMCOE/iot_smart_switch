import 'package:flutter/foundation.dart';

@immutable
class SanityCheckResult {
  final bool isSuccess;
  final String step;
  final String details;
  final DateTime timestamp;
  final Map<String, dynamic>? writtenPayload;
  final Map<String, dynamic>? readPayload;
  final String? errorMessage;

  const SanityCheckResult({
    required this.isSuccess,
    required this.step,
    required this.details,
    required this.timestamp,
    this.writtenPayload,
    this.readPayload,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'SanityCheckResult(isSuccess: $isSuccess, step: $step, details: $details)';
  }
}
