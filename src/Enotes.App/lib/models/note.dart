class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.kind = kindText,
    this.fileName,
    this.sizeBytes,
  });

  /// A note holding typed text (the default).
  static const kindText = 'text';

  /// A note holding an uploaded file.
  static const kindFile = 'file';

  final String id;
  final String title;
  final String content;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// Either [kindText] or [kindFile].
  final String kind;

  /// Original name of the uploaded file; `null` for text notes.
  final String? fileName;

  /// Size of the uploaded file in bytes; `null` for text notes.
  final int? sizeBytes;

  /// Whether this note is an uploaded file rather than typed text.
  bool get isFile => kind == kindFile;

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    createdAtUtc: _parseUtc(json['createdAtUtc'] as String),
    updatedAtUtc: _parseUtc(json['updatedAtUtc'] as String),
    kind: json['kind'] as String? ?? kindText,
    fileName: json['fileName'] as String?,
    sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
  );

  /// Timestamps are always stored in UTC, but a server may return them without
  /// the trailing `Z`. Treating such a value as local time would shift it by the
  /// time zone offset and make newer versions from another device look older.
  static DateTime _parseUtc(String value) {
    final parsed = DateTime.parse(value);
    if (parsed.isUtc) return parsed;
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }
}
