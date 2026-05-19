import 'package:flutter/foundation.dart';

import '../../features/schedule/models/subject.dart';
import '../../features/schedule/models/schedule_entry.dart';
import '../../features/schedule/services/schedule_service.dart';
import '../../features/schedule/models/session_override.dart';
import '../../core/utils/time_utils.dart';
import '../../core/constants/app_constants.dart';

/// Manages subjects and weekly schedule entries.
///
/// Loads data eagerly from SQLite on construction and exposes mutating
/// methods that keep the in-memory list and the database in sync.
class ScheduleProvider extends ChangeNotifier {
  final ScheduleService _service;

  List<Subject> _subjects = [];
  List<ScheduleEntry> _entries = [];
  Map<String, SessionOverride> _overrides = {};
  bool _loading = false;

  List<Subject> get subjects =>
      List.unmodifiable(_subjects.where((s) => !s.isArchived));
  List<Subject> get archivedSubjects =>
      List.unmodifiable(_subjects.where((s) => s.isArchived));
  List<ScheduleEntry> get entries {
    final activeIds = subjects.map((s) => s.id).whereType<int>().toSet();
    return List.unmodifiable(
      _entries.where((entry) => activeIds.contains(entry.subjectId)),
    );
  }

  bool get loading => _loading;

  bool _disposed = false;

  ScheduleProvider(this._service) {
    _load();
  }

  Future<void> _load() async {
    _loading = true;
    _safeNotify();
    _subjects = await _service.getSubjects();
    _entries = await _service.getScheduleEntries();
    final overrides = await _service.getSessionOverrides();
    _overrides = {
      for (final o in overrides) _overrideKey(o.scheduleEntryId, o.date): o,
    };
    _loading = false;
    _safeNotify();
  }

  // ── Subjects ───────────────────────────────────────────────────────────────

  Future<void> addSubject({
    required String name,
    String? professor,
    String? classroom,
  }) async {
    await addSubjectWithOptionalSchedule(
      name: name,
      professor: professor,
      classroom: classroom,
    );
  }

  Future<void> addSubjectWithOptionalSchedule({
    required String name,
    String? professor,
    String? classroom,
    int? weekday,
    String? startTime,
    String? endTime,
  }) async {
    final trimmed = name.trim();
    final normalizedProfessor = professor?.trim().isEmpty == true
        ? null
        : professor?.trim();
    final normalizedClassroom = classroom?.trim().isEmpty == true
        ? null
        : classroom?.trim();

    final id = await _service.createSubject(
      name: trimmed,
      professor: normalizedProfessor,
      classroom: normalizedClassroom,
    );
    _subjects = [
      ..._subjects,
      Subject(
        id: id,
        name: trimmed,
        professor: normalizedProfessor,
        classroom: normalizedClassroom,
        isArchived: false,
      ),
    ];

    if (weekday != null && startTime != null && endTime != null) {
      final entry = ScheduleEntry(
        subjectId: id,
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
      );
      final entryId = await _service.createScheduleEntry(entry);
      _entries = [..._entries, entry.copyWith(id: entryId)];
    }

    _safeNotify();
  }

  Future<void> deleteSubject(int id) async {
    await _service.deleteSubject(id); // cascade removes entries & notes in DB
    _subjects = _subjects.where((s) => s.id != id).toList();
    _entries = _entries.where((e) => e.subjectId != id).toList();
    _safeNotify();
  }

  Future<void> archiveSubject(int id) async {
    final subject = subjectByIdIncludingArchived(id);
    if (subject == null || subject.isArchived) return;
    final archived = subject.copyWith(isArchived: true);
    await _service.updateSubject(archived);
    _subjects = [
      for (final current in _subjects)
        if (current.id == id) archived else current,
    ];
    _safeNotify();
  }

  Future<void> restoreSubject(int id) async {
    final subject = subjectByIdIncludingArchived(id);
    if (subject == null || !subject.isArchived) return;
    final restored = subject.copyWith(isArchived: false);
    await _service.updateSubject(restored);
    _subjects = [
      for (final current in _subjects)
        if (current.id == id) restored else current,
    ];
    _safeNotify();
  }

  Future<void> updateSubject({
    required int id,
    required String name,
    String? professor,
    String? classroom,
  }) async {
    final trimmed = name.trim();
    final normalizedProfessor = professor?.trim().isEmpty == true
        ? null
        : professor?.trim();
    final normalizedClassroom = classroom?.trim().isEmpty == true
        ? null
        : classroom?.trim();

    final updated = Subject(
      id: id,
      name: trimmed,
      professor: normalizedProfessor,
      classroom: normalizedClassroom,
      isArchived: subjectByIdIncludingArchived(id)?.isArchived ?? false,
    );
    await _service.updateSubject(updated);
    _subjects = [
      for (final subject in _subjects)
        if (subject.id == id) updated else subject,
    ];
    _safeNotify();
  }

  // ── Schedule entries ───────────────────────────────────────────────────────

  Future<void> addScheduleEntry(ScheduleEntry entry) async {
    final id = await _service.createScheduleEntry(entry);
    _entries = [..._entries, entry.copyWith(id: id)];
    _safeNotify();
  }

  Future<void> addScheduleEntries(List<ScheduleEntry> entries) async {
    if (entries.isEmpty) return;
    final created = <ScheduleEntry>[];
    for (final entry in entries) {
      final id = await _service.createScheduleEntry(entry);
      created.add(entry.copyWith(id: id));
    }
    _entries = [..._entries, ...created];
    _safeNotify();
  }

  Future<void> deleteScheduleEntry(int id) async {
    await _service.deleteScheduleEntry(id);
    _entries = _entries.where((e) => e.id != id).toList();
    _safeNotify();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// All schedule entries that belong to [subjectId].
  List<ScheduleEntry> entriesForSubject(
    int subjectId, {
    bool includeArchivedSubject = false,
  }) {
    if (!includeArchivedSubject && subjectById(subjectId) == null) {
      return const <ScheduleEntry>[];
    }
    return _entries.where((e) => e.subjectId == subjectId).toList();
  }

  /// Returns the [Subject] with id == [subjectId], or `null` if not found.
  Subject? subjectById(int subjectId) {
    for (final s in _subjects) {
      if (s.id == subjectId && !s.isArchived) return s;
    }
    return null;
  }

  Subject? subjectByIdIncludingArchived(int subjectId) {
    for (final s in _subjects) {
      if (s.id == subjectId) return s;
    }
    return null;
  }

  /// Returns the [ScheduleEntry] that is active right now (if any).
  ScheduleEntry? getCurrentClass({
    int preGraceMinutes = AppConstants.sessionPreGraceMinutes,
    int postGraceMinutes = AppConstants.sessionPostGraceMinutes,
  }) => TimeUtils.matchEntryForTimestamp(
    entries,
    DateTime.now(),
    preGraceMinutes: preGraceMinutes,
    postGraceMinutes: postGraceMinutes,
  );

  Subject? resolveSubjectForEntryOnDate(ScheduleEntry entry, DateTime date) {
    final key = _overrideKey(entry.id!, _dateKey(date));
    final override = _overrides[key];
    return subjectById(override?.subjectId ?? entry.subjectId);
  }

  Future<void> setSessionOverride({
    required int scheduleEntryId,
    required DateTime date,
    required int subjectId,
  }) async {
    final dateKey = _dateKey(date);
    await _service.upsertSessionOverride(
      scheduleEntryId: scheduleEntryId,
      date: dateKey,
      subjectId: subjectId,
    );
    _overrides[_overrideKey(scheduleEntryId, dateKey)] = SessionOverride(
      scheduleEntryId: scheduleEntryId,
      date: dateKey,
      subjectId: subjectId,
    );
    _safeNotify();
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _overrideKey(int scheduleEntryId, String dateKey) =>
      '$scheduleEntryId-$dateKey';

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
