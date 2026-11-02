import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/note.dart';
import '../services/api_service.dart';
import '../utils/format.dart';

/// Detail screen for a file note.
///
/// The file is not loaded into the app; opening it hands the download URL to the
/// platform, which streams it with the browser or the default app for its type.
/// That keeps even very large files out of the app's memory.
class FileNoteScreen extends StatefulWidget {
  const FileNoteScreen({super.key, required this.api, required this.note});

  final Note note;
  final ApiService api;

  @override
  State<FileNoteScreen> createState() => _FileNoteScreenState();
}

class _FileNoteScreenState extends State<FileNoteScreen> {
  bool _working = false;

  Future<void> _open() async {
    setState(() => _working = true);
    try {
      final opened = await launchUrl(
        widget.api.noteFileUri(widget.note.id),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showMessage('Could not open the file.');
      }
    } catch (error) {
      if (mounted) _showMessage('Could not open: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _delete() async {
    final name = widget.note.fileName ?? widget.note.title;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete file?'),
            content: Text('“$name” will be permanently deleted.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      await widget.api.deleteNote(widget.note.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        _showMessage('Could not delete: $error');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.note.fileName ?? widget.note.title;
    final size = widget.note.sizeBytes;
    return Scaffold(
      appBar: AppBar(
        title: Text(name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Delete file',
            onPressed: _working ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  size == null ? 'File' : formatFileSize(size),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _working ? null : _open,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Open / download'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The file opens with the browser or the app for this file type.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
