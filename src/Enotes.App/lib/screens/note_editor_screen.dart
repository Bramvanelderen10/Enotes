import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/note.dart';
import '../services/api_service.dart';

/// Full-screen note editor.
///
/// This is a separate screen (pushed on top of the notes list) instead of a
/// dialog, so the app bar provides a back button to return to the notes page.
///
/// There is no save button: every edit is pushed to the API automatically and
/// remote edits made on other devices are pulled in while the note is
/// untouched, which keeps the screen in two-way sync.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.api, this.note});

  /// `null` creates a new note on the first automatic save.
  final Note? note;
  final ApiService api;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

enum _SaveStatus { saved, saving, pending, error, deleted }

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  /// The API requires a title, so a note that is saved without one gets this
  /// fallback instead of blocking the automatic save.
  static const _untitledTitle = 'Untitled';
  static const _autosaveDelay = Duration(milliseconds: 500);
  static const _syncInterval = Duration(seconds: 2);

  late final TextEditingController _titleController = TextEditingController(
    text: widget.note?.title ?? '',
  );
  late final TextEditingController _contentController = TextEditingController(
    text: widget.note?.content ?? '',
  );

  late String? _noteId = widget.note?.id;
  late String _baseTitle = widget.note?.title ?? '';
  late String _baseContent = widget.note?.content ?? '';

  /// Timestamp of the version this screen last sent or received, used to detect
  /// newer versions from other devices.
  late DateTime _lastSyncedAt =
      widget.note?.updatedAtUtc ?? DateTime.now().toUtc();

  _SaveStatus _status = _SaveStatus.saved;
  String? _statusDetail;
  Timer? _autosaveTimer;
  Timer? _syncTimer;
  bool _saving = false;
  bool _saveQueued = false;
  bool _checkingRemote = false;

  /// Set once the note is deleted here, so the pending and last-chance saves
  /// cannot store it again while the screen is closing.
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _syncTimer = Timer.periodic(
      _syncInterval,
      (_) => unawaited(_pullRemoteChanges()),
    );
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _syncTimer?.cancel();
    // Read the fields before disposing the controllers, then push whatever was
    // typed as a last chance save. State updates are skipped because the widget
    // is on its way out.
    final title = _titleController.text;
    final content = _contentController.text;
    _titleController.dispose();
    _contentController.dispose();
    unawaited(_persist(title, content, showStatus: false));
    super.dispose();
  }

  void _onChanged(String _) {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, () => unawaited(_save()));
    if (_status != _SaveStatus.pending && _status != _SaveStatus.saving) {
      _setStatus(_SaveStatus.pending);
    }
  }

  /// Cancels the pending debounce and stores the note right away. Used when the
  /// user leaves the screen and after a queued save.
  Future<void> _save() async {
    _autosaveTimer?.cancel();
    await _persist(_titleController.text, _contentController.text);
  }

  Future<void> _persist(
    String title,
    String content, {
    bool showStatus = true,
  }) async {
    if (_deleted) return;
    final effectiveTitle = _normalizeTitle(title);
    if (_saving) {
      _saveQueued = true;
      return;
    }
    if (_noteId != null &&
        effectiveTitle == _baseTitle &&
        content == _baseContent) {
      if (showStatus) _setStatus(_SaveStatus.saved);
      return;
    }

    _saving = true;
    if (showStatus) _setStatus(_SaveStatus.saving);
    try {
      final saved = await _push(effectiveTitle, content);
      _noteId = saved.id;
      _baseTitle = saved.title;
      _baseContent = saved.content;
      _lastSyncedAt = saved.updatedAtUtc;
      if (showStatus) _setStatus(_SaveStatus.saved);
    } catch (error) {
      if (showStatus) _setStatus(_SaveStatus.error, detail: error.toString());
    } finally {
      _saving = false;
      if (_saveQueued) {
        _saveQueued = false;
        if (mounted) {
          _autosaveTimer?.cancel();
          _autosaveTimer = Timer(_autosaveDelay, () => unawaited(_save()));
        }
      }
    }
  }

  Future<Note> _push(String title, String content) async {
    final noteId = _noteId;
    if (noteId == null) {
      return widget.api.createNote(title: title, content: content);
    }
    try {
      return await widget.api.updateNote(
        noteId,
        title: title,
        content: content,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      // The note was removed on another device; keep the typed text by saving
      // it as a new note instead of failing.
      _noteId = null;
      return widget.api.createNote(title: title, content: content);
    }
  }

  Future<void> _pullRemoteChanges() async {
    final noteId = _noteId;
    if (_deleted || noteId == null || _checkingRemote || _saving) return;
    _checkingRemote = true;
    try {
      final notes = await widget.api.getNotes();
      if (!mounted) return;
      final remote = _findNote(notes, noteId);
      if (remote == null) {
        _setStatus(_SaveStatus.deleted);
        return;
      }
      if (!remote.updatedAtUtc.isAfter(_lastSyncedAt)) return;

      final hasLocalEdits =
          _normalizeTitle(_titleController.text) != _baseTitle ||
          _contentController.text != _baseContent;
      if (hasLocalEdits) {
        // The pending automatic save wins; leave the local text alone.
        return;
      }

      _baseTitle = remote.title;
      _baseContent = remote.content;
      _lastSyncedAt = remote.updatedAtUtc;
      setState(() {
        _titleController.text = remote.title;
        _contentController.text = remote.content;
        _status = _SaveStatus.saved;
        _statusDetail = null;
      });
    } catch (error) {
      _setStatus(_SaveStatus.error, detail: error.toString());
    } finally {
      _checkingRemote = false;
    }
  }

  /// Deletes the note and returns to the notes page. Only offered once the note
  /// exists on the server, so a brand new note has nothing to delete yet.
  Future<void> _deleteNote() async {
    final noteId = _noteId;
    if (noteId == null) return;

    final title = _titleController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete note?'),
            content: Text(
              '“${title.isEmpty ? _untitledTitle : title}” will be permanently deleted.',
            ),
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

    _autosaveTimer?.cancel();
    try {
      await widget.api.deleteNote(noteId);
    } catch (error) {
      _setStatus(_SaveStatus.error, detail: error.toString());
      return;
    }

    _deleted = true;
    _noteId = null;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _copyNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text;
    final text =
        title.isEmpty
            ? content
            : content.trim().isEmpty
            ? title
            : '$title\n\n$content';
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Note copied to clipboard')),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not copy: $error')));
    }
  }

  void _setStatus(_SaveStatus status, {String? detail}) {
    if (!mounted) return;
    setState(() {
      _status = status;
      _statusDetail = detail;
    });
  }

  static Note? _findNote(List<Note> notes, String noteId) {
    for (final note in notes) {
      if (note.id == noteId) return note;
    }
    return null;
  }

  static String _normalizeTitle(String title) =>
      title.trim().isEmpty ? _untitledTitle : title.trim();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Store pending edits as soon as the user goes back, so the notes page
        // they return to is up to date.
        if (didPop) unawaited(_save());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'New note' : 'Note'),
          actions: [
            IconButton(
              tooltip: 'Copy note',
              onPressed: _copyNote,
              icon: const Icon(Icons.copy_all_outlined),
            ),
            if (_noteId != null)
              IconButton(
                tooltip: 'Delete note',
                onPressed: _deleteNote,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(32),
            child: _StatusStrip(status: _status, detail: _statusDetail),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                maxLength: 200,
                autofocus: widget.note == null,
                textInputAction: TextInputAction.next,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  maxLength: 1000000,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  onChanged: _onChanged,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.status, this.detail});

  final _SaveStatus status;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, String label, Color color) = switch (status) {
      _SaveStatus.saved => (
        Icons.cloud_done_outlined,
        'All changes saved',
        scheme.onSurfaceVariant,
      ),
      _SaveStatus.saving => (
        Icons.cloud_upload_outlined,
        'Saving…',
        scheme.onSurfaceVariant,
      ),
      _SaveStatus.pending => (
        Icons.edit_outlined,
        'Unsaved changes',
        scheme.onSurfaceVariant,
      ),
      _SaveStatus.deleted => (
        Icons.delete_outline,
        'Deleted on another device — keep typing to save it again',
        scheme.error,
      ),
      _SaveStatus.error => (
        Icons.cloud_off_outlined,
        detail == null ? 'Not saved' : 'Not saved: $detail',
        scheme.error,
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (status == _SaveStatus.saving)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
