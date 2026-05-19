/// A weekly recurring time slot linked to a [Subject].
class ScheduleEntry {
  final int? id;
  final int subjectId;

  /// Weekday following [DateTime.weekday] convention: 1 = Monday … 7 = Sunday.
  final int weekday;

  /// Start time as zero-padded "HH:mm" (24-hour clock).
  final String startTime;

  /// End time as zero-padded "HH:mm" (24-hour clock).
  final String endTime;

  const ScheduleEntry({
    this.id,
    required this.subjectId,
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  ScheduleEntry copyWith({
    int? id,
    int? subjectId,
    int? weekday,
    String? startTime,
    String? endTime,
  }) => ScheduleEntry(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    weekday: weekday ?? this.weekday,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
  );

  /// Used for DB inserts – `id` is excluded as it is AUTOINCREMENT.
  Map<String, dynamic> toMap() => {
    'subject_id': subjectId,
    'weekday': weekday,
    'start_time': startTime,
    'end_time': endTime,
  };

  factory ScheduleEntry.fromMap(Map<String, dynamic> m) => ScheduleEntry(
    id: m['id'] as int,
    subjectId: m['subject_id'] as int,
    weekday: m['weekday'] as int,
    startTime: m['start_time'] as String,
    endTime: m['end_time'] as String,
  );

  @override
  String toString() =>
      'ScheduleEntry(id: $id, subjectId: $subjectId, weekday: $weekday, $startTime-$endTime)';
}
