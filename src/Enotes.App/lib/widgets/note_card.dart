import 'package:flutter/material.dart';

import '../models/note.dart';

/// Compact card that previews a note in the notes grid.
///
/// The card is as tall as its title plus the first lines of the content, so a
/// short note stays a small square while a long one grows up to
/// [maxPreviewLines] lines and is then cut off with an ellipsis.
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.onTap});

  /// Most content lines shown before the preview is truncated.
  static const maxPreviewLines = 6;

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = note.content.trim();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                content.isEmpty ? 'No content' : content,
                maxLines: maxPreviewLines,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.3,
                  color:
                      content.isEmpty
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                  fontStyle: content.isEmpty ? FontStyle.italic : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
