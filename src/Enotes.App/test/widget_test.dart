import 'dart:convert';

import 'package:enotes_app/main.dart';
import 'package:enotes_app/models/note.dart';
import 'package:enotes_app/screens/note_editor_screen.dart';
import 'package:enotes_app/screens/notes_screen.dart';
import 'package:enotes_app/screens/setup_screen.dart';
import 'package:enotes_app/services/api_service.dart';
import 'package:enotes_app/services/storage_service.dart';
import 'package:enotes_app/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _noteId = 'c1f0e0a4-3b1e-4e9f-9c2a-0f6a5e2d1b3c';
const _jsonHeaders = {'content-type': 'application/json'};

ApiService _api({http.Client? client}) => ApiService(
  baseUrl: 'http://localhost:36241',
  username: 'tester',
  client: client,
);

Note _note({
  String? id,
  String title = 'Groceries',
  String content = 'Milk and bread',
  DateTime? updatedAtUtc,
}) => Note(
  id: id ?? _noteId,
  title: title,
  content: content,
  createdAtUtc: DateTime.utc(2026, 1, 1, 8),
  updatedAtUtc: updatedAtUtc ?? DateTime.utc(2026, 1, 1, 8),
);

Map<String, dynamic> _noteJson(Note note) => {
  'id': note.id,
  'title': note.title,
  'content': note.content,
  'createdAtUtc': note.createdAtUtc.toIso8601String(),
  'updatedAtUtc': note.updatedAtUtc.toIso8601String(),
};

http.Response _noteResponse(Note note) =>
    http.Response(jsonEncode(_noteJson(note)), 200, headers: _jsonHeaders);

http.Response _notesResponse(List<Note> notes) => http.Response(
  jsonEncode(notes.map(_noteJson).toList()),
  200,
  headers: _jsonHeaders,
);

/// In-memory [StorageService], so the setup screen and the entry point can be
/// tested without the platform preferences plugin.
class _FakeStorage extends StorageService {
  _FakeStorage({this.config});

  (String, String)? config;
  int saveCalls = 0;
  int clearCalls = 0;

  @override
  Future<(String, String)?> getConfig() async => config;

  @override
  Future<void> saveConfig(String url, String username) async {
    saveCalls++;
    config = (url, username);
  }

  @override
  Future<void> clearConfig() async {
    clearCalls++;
    config = null;
  }
}

String _fieldText(WidgetTester tester, {required bool first}) {
  final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
  return (first ? fields.first : fields.last).controller?.text ?? '';
}

void main() {
  testWidgets('setup asks for server and username', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(storage: StorageService(), onConfigured: (_, _) {}),
      ),
    );

    expect(find.text('Server address'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('setup prefills the server details that are saved', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeStorage(config: ('http://192.168.1.10:36241', 'bram'));

    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(
          storage: storage,
          onConfigured: (_, _) {},
          initialUrl: 'http://192.168.1.10:36241',
          initialUsername: 'bram',
          onCancel: () {},
          onForget: () {},
        ),
      ),
    );

    expect(_fieldText(tester, first: true), 'http://192.168.1.10:36241');
    expect(_fieldText(tester, first: false), 'bram');

    // Editing can be cancelled, and the saved details survive until a new
    // connection is made.
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(storage.config, ('http://192.168.1.10:36241', 'bram'));
    expect(storage.saveCalls, 0);

    await tester.tap(find.text('Forget saved server'));
    await tester.pump();
    expect(storage.clearCalls, 1);
    expect(storage.config, isNull);
    expect(_fieldText(tester, first: true), isEmpty);
    expect(_fieldText(tester, first: false), isEmpty);
  });

  testWidgets('setup without saved details offers no way back', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(storage: _FakeStorage(), onConfigured: (_, _) {}),
      ),
    );

    expect(_fieldText(tester, first: true), isEmpty);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Forget saved server'), findsNothing);
  });

  testWidgets('the settings screen opens with the details in use', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _FakeStorage(config: ('http://192.168.1.10:36241', 'bram'));

    await tester.pumpWidget(EnotesApp(storage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('bram’s notes'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change server or user'));
    await tester.pumpAndSettle();

    expect(find.text('Server settings'), findsOneWidget);
    expect(_fieldText(tester, first: true), 'http://192.168.1.10:36241');
    expect(_fieldText(tester, first: false), 'bram');

    // Cancelling returns to the notes page with the same server and username.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('bram’s notes'), findsOneWidget);
    expect(storage.config, ('http://192.168.1.10:36241', 'bram'));
  });

  testWidgets('a note opens on its own screen with a back button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('notes list')),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(api: _api(), note: _note()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // A full screen instead of a dialog.
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Note')),
      findsOneWidget,
    );
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Milk and bread'), findsOneWidget);

    // Edits save themselves, so there is no save button and no prompt to
    // cancel and reopen the note to pick up changes.
    expect(find.text('Save'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('All changes saved'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('notes list'), findsOneWidget);
    expect(find.byType(NoteEditorScreen), findsNothing);
  });

  testWidgets('the copy button copies the note to the clipboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: NoteEditorScreen(api: _api(), note: _note())),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Copy note'));
    await tester.pumpAndSettle();

    final clipboardCalls =
        calls.where((call) => call.method == 'Clipboard.setData').toList();
    expect(clipboardCalls, hasLength(1));
    final arguments = clipboardCalls.single.arguments as Map<Object?, Object?>;
    expect(arguments['text'], 'Groceries\n\nMilk and bread');
    expect(find.text('Note copied to clipboard'), findsOneWidget);
  });

  testWidgets('every edit is saved to the backend automatically', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return _noteResponse(
          _note(
            title: body['title'] as String,
            content: body['content'] as String,
            updatedAtUtc: DateTime.utc(2026, 1, 1, 8, 0, 10),
          ),
        );
      }
      return _notesResponse([_note()]);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditorScreen(api: _api(client: client), note: _note()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Groceries and milk');
    await tester.pump();

    // Nothing to press: the status changes and the save follows by itself.
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(requests, isEmpty);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.pump();

    final updates =
        requests.where((request) => request.method == 'PUT').toList();
    expect(updates, hasLength(1));
    expect(jsonDecode(updates.single.body), {
      'title': 'Groceries and milk',
      'content': 'Milk and bread',
    });
    expect(find.text('All changes saved'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('changes saved on another device are pulled in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var remote = _note();
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return _notesResponse([remote]);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      remote = _note(
        title: body['title'] as String,
        content: body['content'] as String,
        updatedAtUtc: DateTime.utc(2026, 1, 1, 8, 0, 20),
      );
      return _noteResponse(remote);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditorScreen(api: _api(client: client), note: _note()),
      ),
    );
    await tester.pump();
    expect(find.text('Milk and bread'), findsOneWidget);

    // Another device edits the same note while this screen is open.
    remote = _note(
      content: 'Milk, bread and eggs',
      updatedAtUtc: DateTime.utc(2026, 1, 1, 8, 0, 30),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();

    expect(find.text('Milk, bread and eggs'), findsOneWidget);
    expect(find.text('Milk and bread'), findsNothing);
    expect(find.text('All changes saved'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the notes page shows a two column grid that opens a note', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    final client = MockClient(
      (request) async => _notesResponse([
        _note(id: 'note-1', title: 'Groceries'),
        _note(id: 'note-2', title: 'Ideas', content: 'A\nB\nC\nD\nE\nF\nG'),
        _note(id: 'note-3', title: 'Recipes'),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotesScreen(
          baseUrl: 'http://localhost:36241',
          username: 'tester',
          onEditSettings: () {},
          client: client,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Small squares: two per row on a phone, side by side.
    expect(find.byType(NoteCard), findsNWidgets(3));
    final columns = {
      for (var index = 0; index < 3; index++)
        tester.getTopLeft(find.byType(NoteCard).at(index)).dx,
    };
    expect(columns, hasLength(2));
    expect(
      tester.getSize(find.byType(NoteCard).first).width,
      closeTo((400 - 24 - 12) / 2, 0.01),
    );

    // Deleting lives on the note screen now.
    expect(find.byTooltip('Delete note'), findsNothing);

    await tester.tap(find.text('Groceries'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(NoteEditorScreen), findsOneWidget);
    expect(find.byTooltip('Copy note'), findsOneWidget);
    expect(find.byTooltip('Delete note'), findsOneWidget);
    expect(find.text('All changes saved'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a note can be deleted from the note screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'DELETE') return http.Response('', 204);
      if (request.method == 'GET') return _notesResponse([_note()]);
      return _noteResponse(_note());
    });

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('notes list')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder:
            (_) => NoteEditorScreen(api: _api(client: client), note: _note()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byTooltip('Delete note'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Delete note?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));

    final deletes = requests.where((request) => request.method == 'DELETE');
    expect(deletes, hasLength(1));
    expect(find.byType(NoteEditorScreen), findsNothing);
    expect(find.text('notes list'), findsOneWidget);
    expect(
      requests.where(
        (request) => request.method == 'PUT' || request.method == 'POST',
      ),
      isEmpty,
      reason: 'the last chance save must not recreate the deleted note',
    );
  });
}
