import '../../../shared/database/database_service.dart';
import '../models/schedule_entry.dart';
import '../models/subject.dart';
import '../models/session_override.dart';

/// Domain service for schedule-related operations.
///
/// Encapsulates persistence logic for subjects and weekly schedule entries.
class ScheduleService {
  final DatabaseService _db;

  ScheduleService(this._db);

  Future<List<Subject>> getSubjects() => _db.getSubjects();

  Future<List<ScheduleEntry>> getScheduleEntries() => _db.getScheduleEntries();

  Future<int> createSubject({
    required String name,
    String? professor,
    String? classroom,
  }) {
    return _db.insertSubject(
      Subject(
        name: name.trim(),
        professor: professor?.trim().isEmpty == true ? null : professor?.trim(),
        classroom: classroom?.trim().isEmpty == true ? null : classroom?.trim(),
      ),
    );
  }

  Future<int> deleteSubject(int subjectId) => _db.deleteSubject(subjectId);

  Future<int> updateSubject(Subject subject) => _db.updateSubject(subject);

  Future<int> createScheduleEntry(ScheduleEntry entry) {
    return _db.insertScheduleEntry(entry);
  }

  Future<int> updateScheduleEntry(ScheduleEntry entry) {
    return _db.updateScheduleEntry(entry);
  }

  Future<int> deleteScheduleEntry(int id) => _db.deleteScheduleEntry(id);

  Future<int> upsertSessionOverride({
    required int scheduleEntryId,
    required String date,
    required int subjectId,
  }) => _db.upsertSessionOverride(
    scheduleEntryId: scheduleEntryId,
    date: date,
    subjectId: subjectId,
  );

  Future<List<SessionOverride>> getSessionOverrides() async {
    final rows = await _db.getSessionOverrides();
    return rows.map(SessionOverride.fromMap).toList();
  }
}
