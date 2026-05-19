import 'package:flutter/foundation.dart';
import 'dart:async';

import '../../features/camera/services/camera_service.dart';
import '../../features/notes/models/note.dart';
import '../../features/notes/models/processing_note.dart';
import '../../features/notes/services/notes_service.dart';
import '../../features/schedule/models/schedule_entry.dart';
import '../../features/schedule/models/subject.dart';
import '../../features/timeline/models/class_session.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/time_utils.dart';

/// Manages the in-memory list of notes and keeps it in sync with SQLite.
class NotesProvider extends ChangeNotifier {
  final NotesService _notesService;

  List<Note> _notes = [];
  final Map<String, ProcessingNote> _processingNotes = {};
  bool _loading = false;
  StreamSubscription<CameraTaskEvent>? _taskSub;

  List<Note> get notes => List.unmodifiable(_notes);
  List<ProcessingNote> get processingNotes =>
      List.unmodifiable(_processingNotes.values.toList());
  bool get loading => _loading;

  bool _disposed = false;

  NotesProvider(this._notesService) {
    _taskSub = CameraService.instance.taskEvents.listen(_onTaskEvent);
    _load();
  }

  Future<void> _load() async {
    _loading = true;
    _safeNotify();
    _notes = await _notesService.getNotesMetadata();
    _loading = false;
    _safeNotify();
  }

  Future<Note?> getNoteById(int id) => _notesService.getNoteById(id);

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<Note> addPhotoNote({
    required int? subjectId,
    required String imagePath,
    String? ocrText,
  }) async {
    final note = Note(
      subjectId: subjectId,
      noteType: NoteType.photo,
      imagePath: imagePath,
      ocrText: ocrText,
      createdAt: DateTime.now(),
    );
    final id = await _notesService.createNote(note);
    final saved = note.copyWith(id: id);
    _notes = [saved, ..._notes]; // newest first
    _safeNotify();
    return saved;
  }

  Future<Note> addTextNote({
    required int subjectId,
    required String textContent,
  }) async {
    final trimmed = textContent.trim();
    final note = Note(
      subjectId: subjectId,
      noteType: NoteType.text,
      textContent: trimmed,
      createdAt: DateTime.now(),
    );
    final id = await _notesService.createNote(note);
    final saved = note.copyWith(id: id);
    _notes = [saved, ..._notes];
    _safeNotify();
    return saved;
  }

  Future<void> deleteNote(int id) async {
    // Delete the image file from disk (best-effort).
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      await _notesService.deleteImageFile(_notes[idx].imagePath);
    }
    await _notesService.deleteNote(id);
    _notes = _notes.where((n) => n.id != id).toList();
    _safeNotify();
  }

  Future<void> clearOcrText(int id) async {
    await _notesService.updateNoteOcrText(id, null);
    _notes = [
      for (final note in _notes)
        if (note.id == id) note.copyWith(ocrText: null) else note,
    ];
    _safeNotify();
  }

  Future<void> updateOcrText(int id, String? ocrText) async {
    await _notesService.updateNoteOcrText(id, ocrText);
    _notes = [
      for (final note in _notes)
        if (note.id == id) note.copyWith(ocrText: ocrText) else note,
    ];
    _safeNotify();
  }

  Future<void> moveNoteToSubject({
    required int noteId,
    required int targetSubjectId,
  }) async {
    final idx = _notes.indexWhere((n) => n.id == noteId);
    if (idx == -1) return;

    final current = _notes[idx];
    if (current.subjectId == targetSubjectId) return;

    final updated = current.copyWith(subjectId: targetSubjectId);
    await _notesService.updateNote(updated);

    _notes = [
      for (final note in _notes)
        if (note.id == noteId) updated else note,
    ];
    _safeNotify();
  }

  Future<void> updateNoteDetails({
    required int noteId,
    required int subjectId,
    required DateTime createdAt,
    String? ocrText,
    String? textContent,
  }) async {
    final idx = _notes.indexWhere((n) => n.id == noteId);
    if (idx == -1) return;

    final current = _notes[idx];
    final updated = current.copyWith(
      subjectId: subjectId,
      createdAt: createdAt,
      ocrText: ocrText,
      textContent: textContent,
    );

    await _notesService.updateNote(updated);
    _notes = [
      for (final note in _notes)
        if (note.id == noteId) updated else note,
    ];
    _safeNotify();
  }

  /// Removes all notes of a subject from memory after DB-level cascade delete.
  void removeNotesBySubject(int subjectId) {
    _notes = _notes.where((n) => n.subjectId != subjectId).toList();
    _safeNotify();
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  /// Notes belonging to [subjectId], newest first.
  List<Note> notesForSubject(int subjectId) =>
      _notes.where((n) => n.subjectId == subjectId).toList();

  /// Notes that are not assigned to any subject yet, newest first.
  List<Note> unclassifiedNotes() =>
      _notes.where((n) => n.subjectId == null).toList();

  /// Background-processing notes belonging to [subjectId], newest first.
  List<ProcessingNote> processingNotesForSubject(int subjectId) {
    final list = _processingNotes.values
        .where((n) => n.subjectId == subjectId)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Note>? _searchResults;
  List<Note>? get searchResults => _searchResults;
  int _searchVersion = 0;

  Future<void> searchNotesAsync(String query) async {
    final currentVersion = ++_searchVersion;
    if (query.isEmpty) {
      _searchResults = [];
      _safeNotify();
      return;
    }
    _searchResults = null; // null means loading
    _safeNotify();
    final results = await _notesService.searchNotesInDb(query);
    if (_searchVersion == currentVersion) {
      _searchResults = results;
      _safeNotify();
    }
  }

  /// Builds class sessions for a subject using schedule entries and notes.
  List<ClassSession> sessionsForSubject({
    required Subject subject,
    required List<ScheduleEntry> scheduleEntries,
    int preGraceMinutes = AppConstants.sessionPreGraceMinutes,
    int postGraceMinutes = AppConstants.sessionPostGraceMinutes,
  }) {
    final subjectNotes = notesForSubject(subject.id!);
    final subjectProcessing = processingNotesForSubject(subject.id!);
    final sessions = <String, _SessionBucket>{};

    void addToSession({
      required DateTime date,
      required ScheduleEntry? entry,
      required bool isUnscheduled,
      Note? note,
      ProcessingNote? processing,
    }) {
      final dateKey = _dateKey(date);
      final entryKey =
          entry?.id?.toString() ??
          '${entry?.weekday ?? 0}-${entry?.startTime ?? 'na'}-${entry?.endTime ?? 'na'}';
      final key = isUnscheduled ? 'unscheduled-$dateKey' : '$entryKey-$dateKey';

      final bucket = sessions.putIfAbsent(
        key,
        () => _SessionBucket(
          subject: subject,
          date: date,
          scheduleEntry: entry,
          isUnscheduled: isUnscheduled,
        ),
      );

      if (note != null) bucket.notes.add(note);
      if (processing != null) bucket.processingNotes.add(processing);
    }

    for (final note in subjectNotes) {
      final entry = TimeUtils.matchEntryForTimestamp(
        scheduleEntries,
        note.createdAt,
        preGraceMinutes: preGraceMinutes,
        postGraceMinutes: postGraceMinutes,
      );
      addToSession(
        date: _dateOnly(note.createdAt),
        entry: entry,
        isUnscheduled: entry == null,
        note: note,
      );
    }

    for (final processing in subjectProcessing) {
      final entry = TimeUtils.matchEntryForTimestamp(
        scheduleEntries,
        processing.createdAt,
        preGraceMinutes: preGraceMinutes,
        postGraceMinutes: postGraceMinutes,
      );
      addToSession(
        date: _dateOnly(processing.createdAt),
        entry: entry,
        isUnscheduled: entry == null,
        processing: processing,
      );
    }

    // Add empty sessions for the current week schedule slots.
    for (final entry in scheduleEntries) {
      final date = TimeUtils.dateForWeekdayInCurrentWeek(entry.weekday);
      addToSession(date: date, entry: entry, isUnscheduled: false);
    }

    final list = sessions.values.map((bucket) {
      final notes = [...bucket.notes]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final processing = [...bucket.processingNotes]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return ClassSession(
        subject: bucket.subject,
        date: bucket.date,
        scheduleEntry: bucket.scheduleEntry,
        notes: notes,
        processingNotes: processing,
        isUnscheduled: bucket.isUnscheduled,
      );
    }).toList();

    list.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;

      if (a.isUnscheduled != b.isUnscheduled) {
        return a.isUnscheduled ? 1 : -1;
      }

      final aStart = a.startTime == null
          ? 9999
          : TimeUtils.minutesFromTimeString(a.startTime!);
      final bStart = b.startTime == null
          ? 9999
          : TimeUtils.minutesFromTimeString(b.startTime!);
      return aStart.compareTo(bStart);
    });

    return list;
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _dateKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';

  void _onTaskEvent(CameraTaskEvent event) {
    switch (event.status) {
      case CameraTaskStatus.queued:
      case CameraTaskStatus.processingOcr:
      case CameraTaskStatus.savingNote:
        // Keep OCR fully silent in the UI; the note is already saved and OCR
        // result will be applied asynchronously when completed.
        return;
      case CameraTaskStatus.completed:
        if (_processingNotes.remove(event.taskId) != null) {
          _safeNotify();
        }
        return;
      case CameraTaskStatus.failed:
        final current = _processingNotes[event.taskId];
        if (current != null) {
          _processingNotes[event.taskId] = current.copyWith(failed: true);
          _safeNotify();
        }
        return;
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _taskSub?.cancel();
    super.dispose();
  }
}

class _SessionBucket {
  final Subject subject;
  final DateTime date;
  final ScheduleEntry? scheduleEntry;
  final bool isUnscheduled;
  final List<Note> notes = [];
  final List<ProcessingNote> processingNotes = [];

  _SessionBucket({
    required this.subject,
    required this.date,
    required this.scheduleEntry,
    required this.isUnscheduled,
  });
}
