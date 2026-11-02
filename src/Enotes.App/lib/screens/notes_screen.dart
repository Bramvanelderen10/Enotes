import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/note.dart';
import '../services/api_service.dart';
import '../utils/format.dart';
import '../widgets/masonry_grid.dart';
import '../widgets/note_card.dart';
import 'file_note_screen.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    required this.baseUrl,
    required this.username,
    required this.onEditSettings,
    this.client,
  });

  final String baseUrl;
  final String username;

  /// Opens the setup screen to change the server address or username.
  final VoidCallback onEditSettings;

  /// Swappable for tests; see [ApiService].
  final http.Client? client;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

/// The two things the "+" button can add.
enum _AddChoice { note, file }

class _NotesScreenState extends State<NotesScreen> {
  /// Largest file the app uploads, matching the API's default limit.
  static const _maxUploadBytes = 10 * 1024 * 1024 * 1024;

  late final ApiService _api = ApiService(
    baseUrl: widget.baseUrl,
    username: widget.username,
    client: widget.client,
  );
  List<Note> _notes = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _syncTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refresh()),
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final notes = await _api.getNotes();
      if (mounted) {
        setState(() {
          _notes = notes;
          _error = null;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  /// Opens a note: text notes on their editor screen, file notes on the file screen.
  /// Both screens save/delete on their own, so the list is refreshed once the user
  /// comes back.
  Future<void> _openNote({Note? note}) async {
    if (note != null && note.isFile) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FileNoteScreen(api: _api, note: note),
        ),
      );
      await _refresh();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(api: _api, note: note),
      ),
    );
    await _refresh();
  }

  /// Opens the little chooser behind the "+" button: write a note or upload a file.
  Future<void> _showAddOptions() async {
    final choice = await showModalBottomSheet<_AddChoice>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.note_add_outlined),
                  title: const Text('New note'),
                  subtitle: const Text('Write a text note'),
                  onTap: () => Navigator.pop(context, _AddChoice.note),
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: const Text('Upload file'),
                  subtitle: const Text('Share any file up to 10 GB'),
                  onTap: () => Navigator.pop(context, _AddChoice.file),
                ),
              ],
            ),
          ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _AddChoice.note:
        await _openNote();
        break;
      case _AddChoice.file:
        await _uploadFile();
        break;
    }
  }

  /// Picks a file with the platform's native selector and uploads it as a file note.
  Future<void> _uploadFile() async {
    PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        dialogTitle: 'Choose a file to upload',
        type: FileType.any,
      );
    } catch (error) {
      _showMessage('Could not open the file picker: $error');
      return;
    }
    if (picked == null) return;
    final file = picked;

    final size = file.lengthSync() ?? await file.length() ?? 0;
    if (size > _maxUploadBytes) {
      _showMessage('“${file.name}” is larger than the 10 GB limit.');
      return;
    }
    if (size == 0) {
      _showMessage('“${file.name}” is empty.');
      return;
    }

    if (!mounted) return;

    // A determinate progress dialog, updated while the bytes stream to the server.
    final progress = ValueNotifier<int>(0);
    var dialogOpen = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) =>
                _UploadDialog(name: file.name, size: size, progress: progress),
      ).whenComplete(() => dialogOpen = false),
    );

    try {
      await _api.uploadFile(
        fileName: file.name,
        size: size,
        content: file.readAsByteStream(),
        onProgress: (sent) => progress.value = sent,
      );
      await _refresh();
      if (mounted) _showMessage('Uploaded “${file.name}”');
    } catch (error) {
      if (mounted) _showMessage('Upload failed: $error');
    } finally {
      if (dialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
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
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.username}’s notes'),
        actions: [
          IconButton(
            tooltip: 'Refresh now',
            onPressed: _refresh,
            icon: const Icon(Icons.sync),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') widget.onEditSettings();
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: 'settings',
                    child: Text('Change server or user'),
                  ),
                ],
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _notes.isEmpty
              ? _EmptyState(error: _error, onRetry: _refresh)
              : RefreshIndicator(
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  // The grid needs variable card heights, so it cannot be a
                  // lazy sliver list; building all cards is fine for the note
                  // counts this app serves.
                  child: MasonryGrid(
                    children: [
                      for (final note in _notes)
                        NoteCard(
                          note: note,
                          onTap: () => _openNote(note: note),
                        ),
                    ],
                  ),
                ),
              ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add',
        onPressed: _showAddOptions,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar:
          _error == null
              ? null
              : Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Sync issue: $_error',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error == null
                  ? Icons.note_add_outlined
                  : Icons.cloud_off_outlined,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(error == null ? 'No notes yet' : 'Could not load notes'),
            const SizedBox(height: 12),
            if (error != null)
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Non-dismissible dialog shown while a file uploads, with a progress bar that
/// follows the bytes sent to the server.
class _UploadDialog extends StatelessWidget {
  const _UploadDialog({
    required this.name,
    required this.size,
    required this.progress,
  });

  final String name;
  final int size;
  final ValueListenable<int> progress;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Uploading'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (context, sent, _) {
              final value = size <= 0 ? null : (sent / size).clamp(0.0, 1.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: value),
                  const SizedBox(height: 8),
                  Text(
                    '${formatFileSize(sent)} of ${formatFileSize(size)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
