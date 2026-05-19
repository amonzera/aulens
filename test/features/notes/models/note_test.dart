import 'package:flutter_test/flutter_test.dart';

import 'package:aulens/features/notes/models/note.dart';

void main() {
  test('Note.copyWith can intentionally clear nullable fields', () {
    final note = Note(
      id: 1,
      subjectId: 2,
      noteType: NoteType.photo,
      imagePath: '/tmp/aulens_images/photo.jpg',
      ocrText: 'whiteboard text',
      textContent: 'manual notes',
      createdAt: DateTime(2026, 5, 11, 9),
    );

    final updated = note.copyWith(
      subjectId: null,
      imagePath: null,
      ocrText: null,
      textContent: null,
    );

    expect(updated.id, 1);
    expect(updated.subjectId, isNull);
    expect(updated.imagePath, isNull);
    expect(updated.ocrText, isNull);
    expect(updated.textContent, isNull);
    expect(updated.createdAt, note.createdAt);
  });
}
