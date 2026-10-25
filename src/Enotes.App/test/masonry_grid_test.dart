import 'package:enotes_app/widgets/masonry_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cards used by the layout tests, with heights standing in for short and long
/// note previews.
const _heights = [100.0, 150.0, 100.0, 50.0, 50.0, 100.0];

Widget _card(int index) => SizedBox(
  key: Key('card-$index'),
  height: _heights[index],
  child: const Card(margin: EdgeInsets.zero, child: SizedBox.expand()),
);

Future<void> _pumpGrid(WidgetTester tester, double width) async {
  // The default test surface is only 800 wide, which would clamp wider windows.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width + 40, 2400);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        // The grid lives inside a scroll view, like on the notes screen.
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            heightFactor: 1,
            child: SizedBox(
              width: width,
              child: MasonryGrid(
                children: [
                  for (var index = 0; index < _heights.length; index++)
                    _card(index),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Offset _topLeft(WidgetTester tester, int index) =>
    tester.getTopLeft(find.byKey(Key('card-$index')));

void main() {
  testWidgets('a phone width shows two columns', (tester) async {
    await _pumpGrid(tester, 360);

    final columnWidth = tester.getSize(find.byKey(const Key('card-0'))).width;
    expect(columnWidth, closeTo((360 - 12) / 2, 0.01));

    // Column 0 is packed with the first, third and fifth card.
    expect(_topLeft(tester, 0), const Offset(0, 0));
    expect(_topLeft(tester, 2), const Offset(0, 112));
    expect(_topLeft(tester, 4), const Offset(0, 224));

    // Column 1 starts next to it and packs around the taller cards of column 0.
    expect(_topLeft(tester, 1), const Offset(186, 0));
    expect(_topLeft(tester, 3), const Offset(186, 162));
    expect(_topLeft(tester, 5), const Offset(186, 224));
  });

  testWidgets('a wide window shows more columns with a pleasant card width', (
    tester,
  ) async {
    await _pumpGrid(tester, 1200);

    final columns = {
      for (var index = 0; index < _heights.length; index++)
        _topLeft(tester, index).dx,
    };
    expect(columns, hasLength(5));

    final width = tester.getSize(find.byKey(const Key('card-0'))).width;
    expect(width, greaterThan(120));
    expect(width, lessThanOrEqualTo(240));
    // The sixth card wraps back into the first column, under the first card.
    expect(_topLeft(tester, 1).dx, closeTo(width + 12, 0.01));
    expect(_topLeft(tester, 5), const Offset(0, 112));
  });

  testWidgets('a very narrow window falls back to a single column', (
    tester,
  ) async {
    await _pumpGrid(tester, 200);

    expect(tester.getSize(find.byKey(const Key('card-0'))).width, 200);
    expect(_topLeft(tester, 1), const Offset(0, 112));
    expect(_topLeft(tester, 2), const Offset(0, 274));
  });
}
