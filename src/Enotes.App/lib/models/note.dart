class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
    updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
  );
}
