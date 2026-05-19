import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:aulens/core/constants/app_constants.dart';
import 'package:aulens/features/notes/models/note.dart';
import 'package:aulens/shared/database/database_service.dart';

void main() {
  late DatabaseService service;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    service = DatabaseService();
    await service.close();
    dbPath = p.join(await getDatabasesPath(), AppConstants.dbName);
    await deleteDatabase(dbPath);
  });

  tearDown(() async {
    await service.close();
    await deleteDatabase(dbPath);
  });

  test('metadata loading excludes heavy searchable text fields', () async {
    await service.insertNote(
      Note(
        subjectId: null,
        noteType: NoteType.photo,
        imagePath: '/tmp/aulens_images/board.jpg',
        ocrText: 'linear algebra',
        textContent: 'manual summary',
        createdAt: DateTime(2026, 5, 11, 9),
      ),
    );

    final rows = await service.getNotesMetadata();

    expect(rows, hasLength(1));
    expect(rows.single.ocrText, isNull);
    expect(rows.single.textContent, isNull);
    expect(rows.single.imagePath, '/tmp/aulens_images/board.jpg');
  });

  test('database search returns matching text for result snippets', () async {
    await service.insertNote(
      Note(
        subjectId: null,
        noteType: NoteType.photo,
        imagePath: '/tmp/aulens_images/derivatives.jpg',
        ocrText: 'derivatives and integrals on the board',
        createdAt: DateTime(2026, 5, 11, 9),
      ),
    );
    await service.insertNote(
      Note(
        subjectId: null,
        noteType: NoteType.text,
        textContent: 'matrix algebra study plan',
        createdAt: DateTime(2026, 5, 11, 10),
      ),
    );

    final ocrResults = await service.searchNotesInDb('integrals');
    final textResults = await service.searchNotesInDb('matrix');

    expect(ocrResults, hasLength(1));
    expect(ocrResults.single.ocrText, contains('integrals'));
    expect(textResults, hasLength(1));
    expect(textResults.single.textContent, contains('matrix'));
  });
}
