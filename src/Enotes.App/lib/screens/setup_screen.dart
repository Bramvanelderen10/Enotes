import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.storage,
    required this.onConfigured,
    this.initialUrl,
    this.initialUsername,
    this.onCancel,
    this.onForget,
  });

  final StorageService storage;
  final void Function(String url, String username) onConfigured;

  /// Fills the form with the configuration that is already saved, so server
  /// details can be edited instead of typed again.
  final String? initialUrl;
  final String? initialUsername;

  /// Returns to the notes page without changing anything. `null` when nothing
  /// is configured yet, because there is nowhere to go back to.
  final VoidCallback? onCancel;

  /// Forgets the saved server details and shows an empty form. `null` when
  /// nothing is saved.
  final VoidCallback? onForget;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final TextEditingController _urlController = TextEditingController(
    text: widget.initialUrl ?? '',
  );
  late final TextEditingController _usernameController = TextEditingController(
    text: widget.initialUsername ?? '',
  );
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    if (url.isEmpty || username.isEmpty) {
      setState(() => _error = 'Enter both the server address and username.');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      final api = ApiService(baseUrl: url, username: username);
      if (!await api.healthCheck()) {
        throw Exception('The server did not respond at that address.');
      }
      await api.getNotes();
      await widget.storage.saveConfig(url, username);
      if (mounted) widget.onConfigured(url, username);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _forget() async {
    await widget.storage.clearConfig();
    if (!mounted) return;
    _urlController.clear();
    _usernameController.clear();
    setState(() => _error = null);
    widget.onForget?.call();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.onCancel != null;
    return PopScope(
      // While editing an existing configuration, a system back gesture should
      // return to the notes page instead of leaving the app.
      canPop: !editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onCancel?.call();
      },
      child: Scaffold(
        appBar:
            editing
                ? AppBar(
                  leading: BackButton(onPressed: widget.onCancel),
                  title: const Text('Server settings'),
                )
                : null,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.note_alt_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enotes',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    editing
                        ? 'Change the server address or username used on this device.'
                        : 'Connect to your notes server and choose your username.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Server address',
                      hintText: 'http://192.168.1.10:36241',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _connect(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'Your name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _connect(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _connecting ? null : _connect,
                      child:
                          _connecting
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Connect'),
                    ),
                  ),
                  if (widget.onForget != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _connecting ? null : _forget,
                      icon: const Icon(Icons.link_off, size: 18),
                      label: const Text('Forget saved server'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
