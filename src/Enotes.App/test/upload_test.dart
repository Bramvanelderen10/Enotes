import 'dart:convert';
import 'dart:typed_data';

import 'package:enotes_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _jsonHeaders = {'content-type': 'application/json'};

ApiService _api({required http.Client client}) =>
    ApiService(baseUrl: 'http://localhost:36241', username: 'tester', client: client);

Map<String, dynamic> _fileNoteJson({
  String id = 'c1f0e0a4-3b1e-4e9f-9c2a-0f6a5e2d1b3c',
  String title = 'report.pdf',
  String fileName = 'report.pdf',
  int size = 5,
}) => {
  'id': id,
  'title': title,
  'content': '',
  'kind': 'file',
  'fileName': fileName,
  'sizeBytes': size,
  'createdAtUtc': '2026-01-01T08:00:00.0000000Z',
  'updatedAtUtc': '2026-01-01T08:00:00.0000000Z',
};

void main() {
  test('uploadFile streams the body and names the file in the query', () async {
    late http.BaseRequest captured;
    List<int>? receivedBody;
    final client = MockClient.streaming((request, bodyStream) async {
      captured = request;
      receivedBody = await bodyStream.toBytes();
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(_fileNoteJson(size: 11)))),
        201,
        headers: _jsonHeaders,
      );
    });

    final progress = <int>[];
    final note = await _api(client: client).uploadFile(
      fileName: 'report.pdf',
      size: 11,
      content: Stream.fromIterable([
        Uint8List.fromList(utf8.encode('hello ')),
        Uint8List.fromList(utf8.encode('world')),
      ]),
      onProgress: progress.add,
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/users/tester/notes/files');
    expect(captured.url.queryParameters['fileName'], 'report.pdf');
    expect(captured.headers['Content-Type'], 'application/octet-stream');
    expect(receivedBody, utf8.encode('hello world'));
    expect(progress, [6, 11], reason: 'progress is reported per chunk');

    expect(note.isFile, isTrue);
    expect(note.fileName, 'report.pdf');
    expect(note.sizeBytes, 11);
  });

  test('uploadFile throws when the server rejects the file', () async {
    final client = MockClient.streaming(
      (request, bodyStream) async {
        // A real server reads the body before answering; draining keeps the
        // mocked connection from stalling.
        await bodyStream.drain<void>();
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error":"The uploaded file is empty."}')),
          400,
          headers: _jsonHeaders,
        );
      },
    );

    await expectLater(
      _api(client: client).uploadFile(
        fileName: 'empty.bin',
        size: 1,
        content: Stream.value(Uint8List.fromList([1])),
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400)),
    );
  });

  test('noteFileUri points at the file endpoint of the note', () {
    final uri = _api(client: MockClient((_) async => http.Response('', 200)))
        .noteFileUri('c1f0e0a4-3b1e-4e9f-9c2a-0f6a5e2d1b3c');

    expect(
      uri.toString(),
      'http://localhost:36241/api/users/tester/notes/'
      'c1f0e0a4-3b1e-4e9f-9c2a-0f6a5e2d1b3c/file',
    );
  });
}
