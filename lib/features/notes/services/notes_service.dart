import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../shared/database/database_service.dart';
import '../models/note.dart';

/// Domain service for note persistence and image file lifecycle.
class NotesService {
  final DatabaseService _db;

  NotesService(this._db);

  Future<List<Note>> getNotes() => _db.getNotes();

  Future<List<Note>> getNotesMetadata() => _db.getNotesMetadata();

  Future<List<Note>> searchNotesInDb(String query) =>
      _db.searchNotesInDb(query);

  Future<Note?> getNoteById(int id) => _db.getNoteById(id);

  Future<int> createNote(Note note) => _db.insertNote(note);

  Future<int> updateNote(Note note) => _db.updateNote(note);

  Future<int> updateNoteOcrText(int id, String? ocrText) =>
      _db.updateNoteOcrText(id, ocrText);

  Future<int> deleteNote(int id) => _db.deleteNote(id);

  Future<void> deleteImageFile(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return;
    }

    if (!await _isManagedImagePath(imagePath)) {
      return;
    }

    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> _isManagedImagePath(String imagePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final imagesDir = p.normalize(p.join(docsDir.path, 'aulens_images'));
    final candidate = p.normalize(imagePath);
    return p.isWithin(imagesDir, candidate);
  }
}
