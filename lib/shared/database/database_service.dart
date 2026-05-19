import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../features/notes/models/note.dart';
import '../../features/schedule/models/schedule_entry.dart';
import '../../features/schedule/models/subject.dart';
import '../../core/constants/app_constants.dart';

/// Singleton SQLite service for Aulens.
///
/// Tables:
/// - `subjects`
/// - `schedule`
/// - `notes`
///
/// Foreign keys use ON DELETE CASCADE so deleting a subject also deletes
/// related schedule entries and notes from the database.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  static const String _dbName = AppConstants.dbName;
  static const int _dbVersion = AppConstants.dbVersion;

  static const String _subjectsTable = 'subjects';
  static const String _scheduleTable = 'schedule';
  static const String _legacyScheduleTable = 'schedule_entries';
  static const String _notesTable = 'notes';
  static const String _sessionOverridesTable = 'session_overrides';

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<Database> _open() async {
    final basePath = await getDatabasesPath();
    final dbPath = p.join(basePath, _dbName);

    return openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_subjectsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        professor TEXT,
        classroom TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $_scheduleTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL
          REFERENCES $_subjectsTable(id) ON DELETE CASCADE,
        title TEXT,
        weekday INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_notesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER
          REFERENCES $_subjectsTable(id) ON DELETE CASCADE,
        note_type TEXT NOT NULL DEFAULT 'photo',
        image_path TEXT,
        ocr_text TEXT,
        text_content TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_sessionOverridesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        schedule_entry_id INTEGER NOT NULL
          REFERENCES $_scheduleTable(id) ON DELETE CASCADE,
        date TEXT NOT NULL,
        subject_id INTEGER NOT NULL
          REFERENCES $_subjectsTable(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _migrateScheduleEntriesToSchedule(db);
    }

    if (oldVersion < 4) {
      await _migrateNotesToTypedTable(db);
    } else {
      await _ensureNotesOcrColumn(db);
      await _ensureNotesTypeColumns(db);
    }

    await _ensureSessionOverridesTable(db);
    await _ensureScheduleTitleColumn(db);

    // Backfill new subject metadata columns.
    await _ensureSubjectMetadataColumns(db);
    await _ensureSubjectArchiveColumn(db);

    if (oldVersion < 7) {
      await _migrateNotesSubjectNullable(db);
    }

    if (oldVersion < 8) {
      await _ensureSubjectArchiveColumn(db);
    }
  }

  Future<void> _migrateScheduleEntriesToSchedule(Database db) async {
    final hasSchedule = await _tableExists(db, _scheduleTable);
    if (!hasSchedule) {
      await db.execute('''
        CREATE TABLE $_scheduleTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subject_id INTEGER NOT NULL
            REFERENCES $_subjectsTable(id) ON DELETE CASCADE,
          title TEXT,
          weekday INTEGER NOT NULL,
          start_time TEXT NOT NULL,
          end_time TEXT NOT NULL
        )
      ''');
    }

    final hasLegacy = await _tableExists(db, _legacyScheduleTable);
    if (hasLegacy) {
      await db.execute('''
        INSERT INTO $_scheduleTable (id, subject_id, title, weekday, start_time, end_time)
        SELECT id, subject_id, NULL, weekday, start_time, end_time
        FROM $_legacyScheduleTable
      ''');
      await db.execute('DROP TABLE $_legacyScheduleTable');
    }
  }

  Future<void> _ensureScheduleTitleColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_scheduleTable)');
    final hasTitle = columns.any((row) => row['name'] == 'title');
    if (!hasTitle) {
      await db.execute('ALTER TABLE $_scheduleTable ADD COLUMN title TEXT');
    }
  }

  Future<bool> _tableExists(DatabaseExecutor db, String tableName) async {
    final rows = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ? AND name = ?',
      whereArgs: ['table', tableName],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> _ensureNotesOcrColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_notesTable)');
    final hasOcr = columns.any((row) => row['name'] == 'ocr_text');
    if (!hasOcr) {
      await db.execute('ALTER TABLE $_notesTable ADD COLUMN ocr_text TEXT');
    }
  }

  Future<void> _ensureNotesTypeColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_notesTable)');
    final hasType = columns.any((row) => row['name'] == 'note_type');
    final hasText = columns.any((row) => row['name'] == 'text_content');

    if (!hasType) {
      await db.execute(
        "ALTER TABLE $_notesTable ADD COLUMN note_type TEXT NOT NULL DEFAULT 'photo'",
      );
    }

    if (!hasText) {
      await db.execute('ALTER TABLE $_notesTable ADD COLUMN text_content TEXT');
    }
  }

  Future<void> _migrateNotesToTypedTable(Database db) async {
    final hasNotes = await _tableExists(db, _notesTable);
    if (!hasNotes) {
      await db.execute('''
        CREATE TABLE $_notesTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subject_id INTEGER
            REFERENCES $_subjectsTable(id) ON DELETE CASCADE,
          note_type TEXT NOT NULL DEFAULT 'photo',
          image_path TEXT,
          ocr_text TEXT,
          text_content TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      return;
    }

    await db.execute('''
      CREATE TABLE notes_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER
          REFERENCES $_subjectsTable(id) ON DELETE CASCADE,
        note_type TEXT NOT NULL DEFAULT 'photo',
        image_path TEXT,
        ocr_text TEXT,
        text_content TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      INSERT INTO notes_new (id, subject_id, note_type, image_path, ocr_text, text_content, created_at)
      SELECT id, subject_id, 'photo', image_path, ocr_text, NULL, created_at
      FROM $_notesTable
    ''');

    await db.execute('DROP TABLE $_notesTable');
    await db.execute('ALTER TABLE notes_new RENAME TO $_notesTable');
  }

  Future<void> _migrateNotesSubjectNullable(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_notesTable)');
    final subjectIdColumn = columns.firstWhere(
      (row) => row['name'] == 'subject_id',
      orElse: () => const <String, Object?>{},
    );
    if (subjectIdColumn.isEmpty) {
      return;
    }

    final isNotNull = (subjectIdColumn['notnull'] as int?) == 1;
    if (!isNotNull) {
      return;
    }

    await db.execute('''
      CREATE TABLE notes_new_nullable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER
          REFERENCES $_subjectsTable(id) ON DELETE CASCADE,
        note_type TEXT NOT NULL DEFAULT 'photo',
        image_path TEXT,
        ocr_text TEXT,
        text_content TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      INSERT INTO notes_new_nullable (id, subject_id, note_type, image_path, ocr_text, text_content, created_at)
      SELECT id, subject_id, note_type, image_path, ocr_text, text_content, created_at
      FROM $_notesTable
    ''');

    await db.execute('DROP TABLE $_notesTable');
    await db.execute('ALTER TABLE notes_new_nullable RENAME TO $_notesTable');
  }

  Future<void> _ensureSubjectMetadataColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_subjectsTable)');
    final hasProfessor = columns.any((row) => row['name'] == 'professor');
    final hasClassroom = columns.any((row) => row['name'] == 'classroom');

    if (!hasProfessor) {
      await db.execute('ALTER TABLE $_subjectsTable ADD COLUMN professor TEXT');
    }

    if (!hasClassroom) {
      await db.execute('ALTER TABLE $_subjectsTable ADD COLUMN classroom TEXT');
    }
  }

  Future<void> _ensureSubjectArchiveColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_subjectsTable)');
    final hasArchived = columns.any((row) => row['name'] == 'is_archived');
    if (!hasArchived) {
      await db.execute(
        'ALTER TABLE $_subjectsTable ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> _ensureSessionOverridesTable(Database db) async {
    final exists = await _tableExists(db, _sessionOverridesTable);
    if (exists) return;
    await db.execute('''
      CREATE TABLE $_sessionOverridesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        schedule_entry_id INTEGER NOT NULL
          REFERENCES $_scheduleTable(id) ON DELETE CASCADE,
        date TEXT NOT NULL,
        subject_id INTEGER NOT NULL
          REFERENCES $_subjectsTable(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _db = null;
  }

  // ── Subjects CRUD ──────────────────────────────────────────────────────────

  Future<int> insertSubject(Subject subject) async {
    final db = await database;
    return db.insert(_subjectsTable, subject.toMap());
  }

  Future<List<Subject>> getSubjects() async {
    final db = await database;
    final rows = await db.query(_subjectsTable, orderBy: 'name ASC');
    return rows.map(Subject.fromMap).toList();
  }

  Future<Subject?> getSubjectById(int id) async {
    final db = await database;
    final rows = await db.query(
      _subjectsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Subject.fromMap(rows.first);
  }

  Future<int> updateSubject(Subject subject) async {
    if (subject.id == null) {
      throw ArgumentError('Subject id is required for update');
    }
    final db = await database;
    return db.update(
      _subjectsTable,
      subject.toMap(),
      where: 'id = ?',
      whereArgs: [subject.id],
    );
  }

  Future<int> deleteSubject(int id) async {
    final db = await database;
    return db.delete(_subjectsTable, where: 'id = ?', whereArgs: [id]);
  }

  // ── Schedule CRUD ──────────────────────────────────────────────────────────

  Future<int> insertScheduleEntry(ScheduleEntry entry) async {
    final db = await database;
    return db.insert(_scheduleTable, entry.toMap());
  }

  Future<List<ScheduleEntry>> getScheduleEntries() async {
    final db = await database;
    final rows = await db.query(
      _scheduleTable,
      orderBy: 'weekday ASC, start_time ASC',
    );
    return rows.map(ScheduleEntry.fromMap).toList();
  }

  Future<List<ScheduleEntry>> getScheduleEntriesBySubject(int subjectId) async {
    final db = await database;
    final rows = await db.query(
      _scheduleTable,
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'weekday ASC, start_time ASC',
    );
    return rows.map(ScheduleEntry.fromMap).toList();
  }

  Future<ScheduleEntry?> getScheduleEntryById(int id) async {
    final db = await database;
    final rows = await db.query(
      _scheduleTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ScheduleEntry.fromMap(rows.first);
  }

  Future<int> updateScheduleEntry(ScheduleEntry entry) async {
    if (entry.id == null) {
      throw ArgumentError('ScheduleEntry id is required for update');
    }
    final db = await database;
    return db.update(
      _scheduleTable,
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteScheduleEntry(int id) async {
    final db = await database;
    return db.delete(_scheduleTable, where: 'id = ?', whereArgs: [id]);
  }

  // ── Notes CRUD ─────────────────────────────────────────────────────────────

  Future<int> insertNote(Note note) async {
    final db = await database;
    return db.insert(_notesTable, note.toMap());
  }

  Future<List<Note>> getNotes() async {
    final db = await database;
    final rows = await db.query(_notesTable, orderBy: 'created_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> getNotesMetadata() async {
    final db = await database;
    final rows = await db.query(
      _notesTable,
      columns: ['id', 'subject_id', 'note_type', 'image_path', 'created_at'],
      orderBy: 'created_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> searchNotesInDb(String query) async {
    if (query.isEmpty) return [];
    final db = await database;
    final q = '%$query%';
    final rows = await db.query(
      _notesTable,
      columns: [
        'id',
        'subject_id',
        'note_type',
        'image_path',
        'ocr_text',
        'text_content',
        'created_at',
      ],
      where: 'ocr_text LIKE ? OR text_content LIKE ?',
      whereArgs: [q, q],
      orderBy: 'created_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> getNotesBySubject(int subjectId) async {
    final db = await database;
    final rows = await db.query(
      _notesTable,
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<Note?> getNoteById(int id) async {
    final db = await database;
    final rows = await db.query(
      _notesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  Future<int> updateNote(Note note) async {
    if (note.id == null) {
      throw ArgumentError('Note id is required for update');
    }
    final db = await database;
    return db.update(
      _notesTable,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> updateNoteOcrText(int id, String? ocrText) async {
    final db = await database;
    return db.update(
      _notesTable,
      {'ocr_text': ocrText},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return db.delete(_notesTable, where: 'id = ?', whereArgs: [id]);
  }

  // ── Session overrides CRUD ───────────────────────────────────────────────

  Future<int> upsertSessionOverride({
    required int scheduleEntryId,
    required String date,
    required int subjectId,
  }) async {
    final db = await database;
    final existing = await db.query(
      _sessionOverridesTable,
      columns: ['id'],
      where: 'schedule_entry_id = ? AND date = ?',
      whereArgs: [scheduleEntryId, date],
      limit: 1,
    );

    if (existing.isEmpty) {
      return db.insert(_sessionOverridesTable, {
        'schedule_entry_id': scheduleEntryId,
        'date': date,
        'subject_id': subjectId,
      });
    }

    final id = existing.first['id'] as int;
    await db.update(
      _sessionOverridesTable,
      {'subject_id': subjectId},
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<List<Map<String, Object?>>> getSessionOverrides() async {
    final db = await database;
    return db.query(_sessionOverridesTable);
  }
}
