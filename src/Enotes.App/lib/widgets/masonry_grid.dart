import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Packs [children] into as many equal-width columns as fit and stacks each
/// child directly under the previous one in its column.
///
/// Unlike [GridView], cards in the same row do not share a height, so short
/// notes stay small while longer ones take more vertical space. Children are
/// placed from the top-left to the bottom-right: the first child goes into the
/// first column, the second into the second column, and so on.
class MasonryGrid extends StatelessWidget {
  const MasonryGrid({
    super.key,
    required this.children,
    this.maxColumnWidth = 240,
    this.spacing = 12,
  });

  /// Cards never get wider than this. With the default a phone shows two
  /// columns, a tablet three or four and a desktop window five or more, while
  /// the cards themselves stay between roughly 120 and 240 logical pixels.
  final double maxColumnWidth;

  /// Gap between columns and between the cards of one column.
  final double spacing;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = math.max(1, (width / maxColumnWidth).ceil());
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var column = 0; column < columns; column++) ...[
              if (column > 0) SizedBox(width: spacing),
              Expanded(child: _buildColumn(column, columns)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildColumn(int column, int columns) {
    final stacked = <Widget>[];
    for (var index = column; index < children.length; index += columns) {
      if (stacked.isNotEmpty) stacked.add(SizedBox(height: spacing));
      stacked.add(children[index]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: stacked,
    );
  }
}
