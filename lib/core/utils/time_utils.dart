import '../../features/schedule/models/schedule_entry.dart';

/// Time / date helpers used for automatic class-detection logic.
class TimeUtils {
  TimeUtils._();

  /// Formats [hour] and [minute] as a zero-padded "HH:mm" string.
  static String formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Returns the current wall-clock time as a "HH:mm" string.
  static String currentTimeString() {
    final now = DateTime.now();
    return formatTime(now.hour, now.minute);
  }

  /// Parses a zero-padded "HH:mm" string into minutes since midnight.
  static int minutesFromTimeString(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return (h.clamp(0, 23) * 60) + m.clamp(0, 59);
  }

  /// Returns `true` when [time] falls in the closed interval [[start], [end]]
  /// (all values must be zero-padded "HH:mm" strings so lexicographic
  /// comparison is equivalent to numeric comparison).
  static bool isTimeBetween(String time, String start, String end) =>
      time.compareTo(start) >= 0 && time.compareTo(end) <= 0;

  /// Returns true when [time] is within the start/end window with a grace.
  static bool isTimeBetweenWithGrace(
    String time,
    String start,
    String end, {
    int preGraceMinutes = 0,
    int postGraceMinutes = 0,
  }) {
    final timeMin = minutesFromTimeString(time);
    final startMin = minutesFromTimeString(start);
    final endMin = minutesFromTimeString(end);
    final min = (startMin - preGraceMinutes).clamp(0, 24 * 60 - 1);
    final max = (endMin + postGraceMinutes).clamp(0, 24 * 60 - 1);
    return timeMin >= min && timeMin <= max;
  }

  /// Scans [entries] and returns the first one whose weekday matches today
  /// and whose time window contains the current time, or `null` if none.
  static ScheduleEntry? detectCurrentClass(List<ScheduleEntry> entries) {
    final now = DateTime.now();
    final time = formatTime(now.hour, now.minute);
    for (final e in entries) {
      if (e.weekday == now.weekday &&
          isTimeBetween(time, e.startTime, e.endTime)) {
        return e;
      }
    }
    return null;
  }

  /// Returns the matching entry for the given [timestamp] (if any).
  static ScheduleEntry? matchEntryForTimestamp(
    List<ScheduleEntry> entries,
    DateTime timestamp, {
    int preGraceMinutes = 0,
    int postGraceMinutes = 0,
  }) {
    final time = formatTime(timestamp.hour, timestamp.minute);
    final weekday = timestamp.weekday;
    ScheduleEntry? best;
    int? bestDistance;
    int? bestStartDistance;

    for (final entry in entries) {
      if (entry.weekday != weekday) continue;
      if (!isTimeBetweenWithGrace(
        time,
        entry.startTime,
        entry.endTime,
        preGraceMinutes: preGraceMinutes,
        postGraceMinutes: postGraceMinutes,
      )) {
        continue;
      }

      final distance = _distanceToInterval(
        time,
        entry.startTime,
        entry.endTime,
      );
      final startDistance = _distanceToStart(time, entry.startTime);

      if (best == null ||
          distance < bestDistance! ||
          (distance == bestDistance && startDistance < bestStartDistance!)) {
        best = entry;
        bestDistance = distance;
        bestStartDistance = startDistance;
      }
    }
    return best;
  }

  /// Returns a date in the current week for [weekday] (1 = Monday).
  static DateTime dateForWeekdayInCurrentWeek(int weekday) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final delta = weekday - today.weekday;
    return today.add(Duration(days: delta));
  }

  static int _distanceToInterval(String time, String start, String end) {
    final timeMin = minutesFromTimeString(time);
    final startMin = minutesFromTimeString(start);
    final endMin = minutesFromTimeString(end);

    if (timeMin < startMin) return startMin - timeMin;
    if (timeMin > endMin) return timeMin - endMin;
    return 0;
  }

  static int _distanceToStart(String time, String start) {
    final timeMin = minutesFromTimeString(time);
    final startMin = minutesFromTimeString(start);
    return (timeMin - startMin).abs();
  }

  /// Human-readable day name for a [DateTime.weekday] value (1 = Monday).
  static String weekdayName(int weekday) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][(weekday - 1).clamp(0, 6)];
}
