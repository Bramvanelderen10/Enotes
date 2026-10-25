import 'package:enotes_app/models/note.dart';
import 'package:enotes_app/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Note _note({String title = 'Groceries', String content = 'Milk and bread'}) =>
    Note(
      id: 'c1f0e0a4-3b1e-4e9f-9c2a-0f6a5e2d1b3c',
      title: title,
      content: content,
      createdAtUtc: DateTime.utc(2026, 1, 1),
      updatedAtUtc: DateTime.utc(2026, 1, 1),
    );

Future<void> _pumpCard(
  WidgetTester tester,
  Note note, {
  VoidCallback? onTap,
  double width = 174,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: NoteCard(note: note, onTap: onTap ?? () {}),
          ),
        ),
      ),
    ),
  );
}

double _height(WidgetTester tester) =>
    tester.getSize(find.byType(NoteCard)).height;

void main() {
  testWidgets('shows the title and a preview of the content', (tester) async {
    await _pumpCard(tester, _note());

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Milk and bread'), findsOneWidget);
  });

  testWidgets('an empty note says so instead of staying blank', (tester) async {
    await _pumpCard(tester, _note(content: '   '));

    expect(find.text('No content'), findsOneWidget);
  });

  testWidgets('tapping the card opens the note', (tester) async {
    var taps = 0;
    await _pumpCard(tester, _note(), onTap: () => taps++);

    await tester.tap(find.byType(NoteCard));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('deleting lives on the note screen, not on the card', (
    tester,
  ) async {
    await _pumpCard(tester, _note());

    expect(find.byType(IconButton), findsNothing);
    expect(find.byTooltip('Delete note'), findsNothing);
  });

  testWidgets('the preview grows with the content and stops at six lines', (
    tester,
  ) async {
    await _pumpCard(tester, _note(content: 'One line'));
    final short = _height(tester);

    await _pumpCard(tester, _note(content: List.filled(6, 'line').join('\n')));
    final sixLines = _height(tester);

    await _pumpCard(tester, _note(content: List.filled(40, 'line').join('\n')));
    final long = _height(tester);

    expect(
      sixLines,
      greaterThan(short + 10),
      reason: 'a longer note takes more vertical space',
    );
    expect(
      long,
      closeTo(sixLines, 0.5),
      reason: 'the preview is capped at ${NoteCard.maxPreviewLines} lines',
    );
  });

  testWidgets('a wrapped title stays inside the card width', (tester) async {
    await _pumpCard(
      tester,
      _note(title: 'A very long note title that has to wrap somewhere'),
    );

    final size = tester.getSize(find.byType(NoteCard));
    expect(size.width, 174);
    expect(size.height, greaterThan(60));

    final title = tester.getSize(
      find.text('A very long note title that has to wrap somewhere'),
    );
    expect(title.width, lessThanOrEqualTo(174 - 24));
  });
}
