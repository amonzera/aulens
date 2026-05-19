/// Stores a manual subject override for a specific session.
class SessionOverride {
  final int? id;
  final int scheduleEntryId;
  final String date; // yyyy-MM-dd
  final int subjectId;

  const SessionOverride({
    this.id,
    required this.scheduleEntryId,
    required this.date,
    required this.subjectId,
  });

  Map<String, dynamic> toMap() => {
    'schedule_entry_id': scheduleEntryId,
    'date': date,
    'subject_id': subjectId,
  };

  factory SessionOverride.fromMap(Map<String, dynamic> m) => SessionOverride(
    id: m['id'] as int,
    scheduleEntryId: m['schedule_entry_id'] as int,
    date: m['date'] as String,
    subjectId: m['subject_id'] as int,
  );
}
