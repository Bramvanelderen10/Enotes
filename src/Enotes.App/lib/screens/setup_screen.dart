import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.storage,
    required this.onConfigured,
  });

  final StorageService storage;
  final void Function(String url, String username) onConfigured;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                const Text(
                  'Connect to your notes server and choose your username.',
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Connect'),
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
