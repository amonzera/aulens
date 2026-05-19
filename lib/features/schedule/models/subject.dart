/// A school subject (e.g., "Mathematics").
class Subject {
  final int? id;
  final String name;
  final String? professor;
  final String? classroom;
  final bool isArchived;

  const Subject({
    this.id,
    required this.name,
    this.professor,
    this.classroom,
    this.isArchived = false,
  });

  Subject copyWith({
    int? id,
    String? name,
    String? professor,
    String? classroom,
    bool? isArchived,
  }) => Subject(
    id: id ?? this.id,
    name: name ?? this.name,
    professor: professor ?? this.professor,
    classroom: classroom ?? this.classroom,
    isArchived: isArchived ?? this.isArchived,
  );

  /// Used for DB inserts – `id` is excluded as it is AUTOINCREMENT.
  Map<String, dynamic> toMap() => {
    'name': name,
    'professor': professor,
    'classroom': classroom,
    'is_archived': isArchived ? 1 : 0,
  };

  factory Subject.fromMap(Map<String, dynamic> m) => Subject(
    id: m['id'] as int,
    name: m['name'] as String,
    professor: m['professor'] as String?,
    classroom: m['classroom'] as String?,
    isArchived: (m['is_archived'] as int?) == 1,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Subject && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Subject(id: $id, name: $name, professor: $professor, classroom: $classroom, isArchived: $isArchived)';
}
