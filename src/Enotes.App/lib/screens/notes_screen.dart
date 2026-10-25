import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/note.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/masonry_grid.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    required this.baseUrl,
    required this.username,
    required this.storage,
    required this.onDisconnect,
    this.client,
  });

  final String baseUrl;
  final String username;
  final StorageService storage;
  final VoidCallback onDisconnect;

  /// Swappable for tests; see [ApiService].
  final http.Client? client;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
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

  /// Opens the note on its own screen. The screen saves every edit by itself,
  /// so the list is refreshed once the user comes back.
  Future<void> _openNote({Note? note}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(api: _api, note: note),
      ),
    );
    await _refresh();
  }

  Future<void> _disconnect() async {
    await widget.storage.clearConfig();
    if (mounted) widget.onDisconnect();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNote(),
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
