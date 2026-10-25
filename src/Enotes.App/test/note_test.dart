import 'package:enotes_app/models/note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timestamps with a trailing Z are read as UTC', () {
    final note = Note.fromJson({
      'id': 'c1f0e0a4-3b1e-4e9f-9c2a-0f6a5e2d1b3c',
      'title': 'Groceries',
      'content': 'Milk and bread',
      'createdAtUtc': '2026-01-01T08:00:00.0000000Z',
      'updatedAtUtc': '2026-01-01T09:30:00.5000000Z',
    });

    expect(note.updatedAtUtc.isUtc, isTrue);
    expect(note.updatedAtUtc, DateTime.utc(2026, 1, 1, 9, 30, 0, 500));
  });

  test('timestamps without a time zone are still read as UTC', () {
    final note = Note.fromJson({
      'id': 'c1f0e0a4-3b1e-4e9f-9c2a-0f6a5e2d1b3c',
      'title': 'Groceries',
      'content': 'Milk and bread',
      'createdAtUtc': '2026-01-01T08:00:00.0000000',
      'updatedAtUtc': '2026-01-01T09:30:00.5000000',
    });

    expect(note.createdAtUtc.isUtc, isTrue);
    expect(note.updatedAtUtc.isUtc, isTrue);
    expect(note.updatedAtUtc, DateTime.utc(2026, 1, 1, 9, 30, 0, 500));
    expect(
      note.updatedAtUtc.isAfter(DateTime.utc(2026, 1, 1, 9)),
      isTrue,
      reason: 'the comparison drives the two-way sync in the note screen',
    );
  });
}
