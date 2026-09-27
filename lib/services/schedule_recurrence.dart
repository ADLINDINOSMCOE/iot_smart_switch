/// Pure recurrence helpers for switch schedules.
/// Weekday labels match the existing Schedule UI: Mon..Sun.
class ScheduleRecurrence {
  static const List<String> weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static String weekdayLabel(DateTime dateTime) =>
      weekdayLabels[dateTime.weekday - 1];

  static String? normalizeDay(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final lower = value.toLowerCase();
    const aliases = {
      'mon': 'Mon',
      'monday': 'Mon',
      'tue': 'Tue',
      'tues': 'Tue',
      'tuesday': 'Tue',
      'wed': 'Wed',
      'wednesday': 'Wed',
      'thu': 'Thu',
      'thur': 'Thu',
      'thurs': 'Thu',
      'thursday': 'Thu',
      'fri': 'Fri',
      'friday': 'Fri',
      'sat': 'Sat',
      'saturday': 'Sat',
      'sun': 'Sun',
      'sunday': 'Sun',
    };
    return aliases[lower] ??
        (weekdayLabels.contains(value) ? value : null);
  }

  static Set<String> normalizeDays(Iterable<dynamic> days) {
    final result = <String>{};
    for (final day in days) {
      final normalized = normalizeDay(day.toString());
      if (normalized != null) {
        result.add(normalized);
      }
    }
    return result;
  }

  /// Empty weekday list means a one-time run at the next matching clock time.
  static bool isOneTime(Iterable<dynamic> days) => normalizeDays(days).isEmpty;

  static bool isDaily(Iterable<dynamic> days) {
    final normalized = normalizeDays(days);
    return weekdayLabels.every(normalized.contains);
  }

  static String executionKey(DateTime localTime) {
    final y = localTime.year.toString().padLeft(4, '0');
    final m = localTime.month.toString().padLeft(2, '0');
    final d = localTime.day.toString().padLeft(2, '0');
    final h = localTime.hour.toString().padLeft(2, '0');
    final min = localTime.minute.toString().padLeft(2, '0');
    return '$y-$m-$d-$h-$min';
  }

  /// Next local DateTime at [hour]:[minute] on an allowed weekday.
  /// [from] is exclusive: the result is always strictly after [from].
  static DateTime computeNextRunAt({
    required int hour,
    required int minute,
    required List<dynamic> days,
    DateTime? from,
  }) {
    final safeHour = hour.clamp(0, 23);
    final safeMinute = minute.clamp(0, 59);
    final now = from ?? DateTime.now();
    final allowed = normalizeDays(days);

    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      safeHour,
      safeMinute,
    );
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
      candidate = DateTime(
        candidate.year,
        candidate.month,
        candidate.day,
        safeHour,
        safeMinute,
      );
    }

    if (allowed.isEmpty) {
      return candidate;
    }

    for (var i = 0; i < 8; i++) {
      if (allowed.contains(weekdayLabel(candidate))) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
      candidate = DateTime(
        candidate.year,
        candidate.month,
        candidate.day,
        safeHour,
        safeMinute,
      );
    }

    return candidate;
  }

  static DateTime computeFollowingRunAt({
    required DateTime justExecuted,
    required int hour,
    required int minute,
    required List<dynamic> days,
  }) {
    return computeNextRunAt(
      hour: hour,
      minute: minute,
      days: days,
      from: justExecuted.add(const Duration(minutes: 1)),
    );
  }
}
