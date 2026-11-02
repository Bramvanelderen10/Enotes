import 'package:flutter/material.dart';

import '../models/note.dart';
import '../utils/format.dart';

/// Compact card that previews a note in the notes grid.
///
/// A text note is as tall as its title plus the first lines of the content, so a
/// short note stays a small square while a long one grows up to
/// [maxPreviewLines] lines and is then cut off with an ellipsis. A file note shows
/// a file icon with its name and size instead of the text preview.
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.onTap});

  /// Most content lines shown before the preview is truncated.
  static const maxPreviewLines = 6;

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              if (note.isFile)
                _FilePreview(note: note)
              else
                _TextPreview(content: note.content),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview shown for a file note: an icon with the file name and its size.
class _FilePreview extends StatelessWidget {
  const _FilePreview({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = note.sizeBytes;
    return Row(
      children: [
        Icon(
          Icons.insert_drive_file_outlined,
          size: 22,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note.fileName ?? note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
              ),
              const SizedBox(height: 2),
              Text(
                size == null ? 'File' : formatFileSize(size),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Preview shown for a text note: its content, or a hint when it is empty.
class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = content.trim();
    return Text(
      body.isEmpty ? 'No content' : body,
      maxLines: NoteCard.maxPreviewLines,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        height: 1.3,
        color: body.isEmpty ? theme.colorScheme.onSurfaceVariant : null,
        fontStyle: body.isEmpty ? FontStyle.italic : null,
      ),
    );
  }
}
