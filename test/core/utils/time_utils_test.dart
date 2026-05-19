import 'package:flutter_test/flutter_test.dart';

import 'package:aulens/core/utils/time_utils.dart';
import 'package:aulens/features/schedule/models/schedule_entry.dart';

void main() {
  group('TimeUtils.matchEntryForTimestamp', () {
    const entry = ScheduleEntry(
      id: 1,
      subjectId: 10,
      weekday: DateTime.monday,
      startTime: '08:00',
      endTime: '10:00',
    );

    test('matches a timestamp inside the class window', () {
      final result = TimeUtils.matchEntryForTimestamp(const [
        entry,
      ], DateTime(2026, 5, 11, 9));

      expect(result, entry);
    });

    test('honors pre and post grace windows', () {
      final before = TimeUtils.matchEntryForTimestamp(
        const [entry],
        DateTime(2026, 5, 11, 7, 55),
        preGraceMinutes: 10,
      );
      final after = TimeUtils.matchEntryForTimestamp(
        const [entry],
        DateTime(2026, 5, 11, 10, 5),
        postGraceMinutes: 10,
      );

      expect(before, entry);
      expect(after, entry);
    });

    test('does not match outside the grace window', () {
      final result = TimeUtils.matchEntryForTimestamp(
        const [entry],
        DateTime(2026, 5, 11, 10, 20),
        postGraceMinutes: 10,
      );

      expect(result, isNull);
    });
  });
}
