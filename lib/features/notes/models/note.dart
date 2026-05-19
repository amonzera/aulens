enum NoteType { photo, text }

const Object _unset = Object();

extension NoteTypeDb on NoteType {
  static NoteType fromDb(String value) {
    switch (value) {
      case 'text':
        return NoteType.text;
      case 'photo':
      default:
        return NoteType.photo;
    }
  }

  String get dbValue => this == NoteType.text ? 'text' : 'photo';
}

/// A note linked to a [Subject]. It can be a photo note or a text note.
class Note {
  final int? id;
  final int? subjectId;
  final NoteType noteType;

  /// Absolute path to the image file stored in app documents directory.
  /// Only set for photo notes.
  final String? imagePath;

  /// Text extracted from the image via OCR. Only set for photo notes.
  final String? ocrText;

  /// Manual text content, only set for text notes.
  final String? textContent;

  final DateTime createdAt;

  const Note({
    this.id,
    required this.subjectId,
    required this.noteType,
    this.imagePath,
    this.ocrText,
    this.textContent,
    required this.createdAt,
  });

  bool get hasImage => imagePath != null && imagePath!.trim().isNotEmpty;
  bool get isTextNote => noteType == NoteType.text;

  Note copyWith({
    Object? id = _unset,
    Object? subjectId = _unset,
    NoteType? noteType,
    Object? imagePath = _unset,
    Object? ocrText = _unset,
    Object? textContent = _unset,
    DateTime? createdAt,
  }) => Note(
    id: identical(id, _unset) ? this.id : id as int?,
    subjectId: identical(subjectId, _unset)
        ? this.subjectId
        : subjectId as int?,
    noteType: noteType ?? this.noteType,
    imagePath: identical(imagePath, _unset)
        ? this.imagePath
        : imagePath as String?,
    ocrText: identical(ocrText, _unset) ? this.ocrText : ocrText as String?,
    textContent: identical(textContent, _unset)
        ? this.textContent
        : textContent as String?,
    createdAt: createdAt ?? this.createdAt,
  );

  /// Used for DB inserts – `id` is excluded as it is AUTOINCREMENT.
  Map<String, dynamic> toMap() => {
    'subject_id': subjectId,
    'note_type': noteType.dbValue,
    'image_path': imagePath,
    'ocr_text': ocrText,
    'text_content': textContent,
    'created_at': createdAt.toIso8601String(),
  };

  factory Note.fromMap(Map<String, dynamic> m) => Note(
    id: m['id'] as int,
    subjectId: m['subject_id'] as int?,
    noteType: NoteTypeDb.fromDb((m['note_type'] as String?) ?? 'photo'),
    imagePath: m['image_path'] as String?,
    ocrText: m['ocr_text'] as String?,
    textContent: m['text_content'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  @override
  String toString() =>
      'Note(id: $id, type: ${noteType.dbValue}, subjectId: $subjectId, createdAt: $createdAt)';
}
