import 'dart:async';

import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    required this.baseUrl,
    required this.username,
    required this.storage,
    required this.onDisconnect,
  });

  final String baseUrl;
  final String username;
  final StorageService storage;
  final VoidCallback onDisconnect;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final ApiService _api = ApiService(
    baseUrl: widget.baseUrl,
    username: widget.username,
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

  Future<void> _editNote({Note? note}) async {
    final result = await showDialog<_NoteDraft>(
      context: context,
      builder: (_) => _NoteEditor(note: note, api: _api),
    );
    if (result == null) return;

    try {
      if (note == null) {
        await _api.createNote(title: result.title, content: result.content);
      } else {
        await _api.updateNote(
          note.id,
          title: result.title,
          content: result.content,
        );
      }
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete note?'),
            content: Text('“${note.title}” will be permanently deleted.'),
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
    if (confirmed != true) return;
    try {
      await _api.deleteNote(note.id);
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _disconnect() async {
    await widget.storage.clearConfig();
    if (mounted) widget.onDisconnect();
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
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
              if (value == 'settings') _disconnect();
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
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                        title: Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            note.content.isEmpty ? 'No content' : note.content,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onTap: () => _editNote(note: note),
                        trailing: IconButton(
                          tooltip: 'Delete note',
                          onPressed: () => _deleteNote(note),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    );
                  },
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editNote(),
        icon: const Icon(Icons.add),
        label: const Text('New note'),
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

class _NoteDraft {
  const _NoteDraft(this.title, this.content);

  final String title;
  final String content;
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.note, required this.api});

  final Note? note;
  final ApiService api;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.note?.title ?? '',
  );
  late final TextEditingController _contentController = TextEditingController(
    text: widget.note?.content ?? '',
  );
  late String _baseTitle = widget.note?.title ?? '';
  late String _baseContent = widget.note?.content ?? '';
  late DateTime _lastSyncedAt = widget.note?.updatedAtUtc ?? DateTime.now();
  String? _error;
  String? _syncWarning;
  Timer? _syncTimer;
  bool _checkingRemote = false;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _syncTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_syncRemoteChanges()),
      );
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _syncRemoteChanges() async {
    final note = widget.note;
    if (note == null || _checkingRemote) return;
    _checkingRemote = true;
    try {
      final notes = await widget.api.getNotes();
      if (!mounted) return;
      final remote = notes.where((item) => item.id == note.id).firstOrNull;
      if (remote == null) {
        setState(
          () => _syncWarning = 'This note was deleted on another device.',
        );
        return;
      }
      if (!remote.updatedAtUtc.isAfter(_lastSyncedAt)) return;

      final hasLocalEdits =
          _titleController.text != _baseTitle ||
          _contentController.text != _baseContent;
      if (hasLocalEdits) {
        setState(() {
          _syncWarning =
              'This note changed on another device. Cancel and reopen to load it.';
        });
        return;
      }

      _baseTitle = remote.title;
      _baseContent = remote.content;
      _lastSyncedAt = remote.updatedAtUtc;
      setState(() {
        _titleController.text = remote.title;
        _contentController.text = remote.content;
        _syncWarning = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _syncWarning = 'Live sync check failed: $error');
      }
    } finally {
      _checkingRemote = false;
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty || title.length > 200) {
      setState(() => _error = 'Title is required (maximum 200 characters).');
      return;
    }
    Navigator.pop(context, _NoteDraft(title, _contentController.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? 'New note' : 'Edit note'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              maxLength: 200,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              minLines: 8,
              maxLines: 14,
              maxLength: 1000000,
              decoration: const InputDecoration(
                labelText: 'Note',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_syncWarning != null)
              Text(
                _syncWarning!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
