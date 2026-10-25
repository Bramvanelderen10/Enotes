import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/note.dart';

class ApiService {
  ApiService({
    required String baseUrl,
    required this.username,
    http.Client? client,
  }) : _baseUrl = _normalizeBaseUrl(baseUrl),
       _client = client ?? http.Client();

  final String _baseUrl;
  final String username;

  /// Swappable for tests; production code reuses one [http.Client] so the
  /// keep-alive connection is shared between requests.
  final http.Client _client;

  Uri _uri({String? noteId}) {
    final segments = <String>[
      ...Uri.parse(_baseUrl).pathSegments.where((part) => part.isNotEmpty),
      'api',
      'users',
      username,
      'notes',
      if (noteId != null) noteId,
    ];
    return Uri.parse(_baseUrl).replace(pathSegments: segments);
  }

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    final withScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'http://$trimmed';
    final parsed = Uri.parse(withScheme);
    if (parsed.host.isEmpty) {
      throw const FormatException('Enter a valid server address.');
    }
    return parsed.toString().replaceFirst(RegExp(r'/$'), '');
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Note>> getNotes() async {
    final response = await _client
        .get(_uri())
        .timeout(const Duration(seconds: 10));
    _checkResponse(response);
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => Note.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Note> createNote({
    required String title,
    required String content,
  }) async {
    final response = await _client
        .post(
          _uri(),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'title': title, 'content': content}),
        )
        .timeout(const Duration(seconds: 10));
    _checkResponse(response);
    return Note.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Note> updateNote(
    String id, {
    required String title,
    required String content,
  }) async {
    final response = await _client
        .put(
          _uri(noteId: id),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'title': title, 'content': content}),
        )
        .timeout(const Duration(seconds: 10));
    _checkResponse(response);
    return Note.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteNote(String id) async {
    final response = await _client
        .delete(_uri(noteId: id))
        .timeout(const Duration(seconds: 10));
    _checkResponse(response);
  }

  static void _checkResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = response.body.isEmpty ? 'Request failed.' : response.body;
      throw ApiException(response.statusCode, message);
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'API error ($statusCode): $message';
}
