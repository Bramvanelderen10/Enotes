import 'package:flutter/material.dart';

import 'screens/notes_screen.dart';
import 'screens/setup_screen.dart';
import 'services/storage_service.dart';

void main() {
  runApp(const EnotesApp());
}

class EnotesApp extends StatelessWidget {
  const EnotesApp({super.key, this.storage});

  /// Swappable for tests; see [StorageService].
  final StorageService? storage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enotes',
      debugShowCheckedModeBanner: false,
      // Dark is the default, so the same dark theme is used whichever way the
      // device is set up. Its surface color (#121318) is repeated in the
      // Android launch theme and the web page, to avoid a white flash before
      // the first frame.
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: _EntryPoint(storage: storage),
    );
  }
}

class _EntryPoint extends StatefulWidget {
  const _EntryPoint({this.storage});

  final StorageService? storage;

  @override
  State<_EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<_EntryPoint> {
  late final StorageService _storage = widget.storage ?? StorageService();
  late final Future<(String, String)?> _configFuture = _storage.getConfig();
  (String, String)? _config;

  /// True while the setup screen is opened to change the saved configuration.
  /// The configuration itself is kept, so the form can show it and cancelling
  /// leaves the saved details untouched.
  bool _editingConfig = false;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String, String)?>(
      future: _configFuture,
      builder: (context, snapshot) {
        if (!_loaded && snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!_loaded) {
          _config = snapshot.data;
          _loaded = true;
        }

        final config = _config;
        if (config == null || _editingConfig) {
          return SetupScreen(
            // Rebuilds the form whenever the configuration changes, so the
            // fields always start from the details that are actually saved.
            key: ValueKey(config),
            storage: _storage,
            initialUrl: config?.$1,
            initialUsername: config?.$2,
            onConfigured: (url, username) {
              setState(() {
                _config = (url, username);
                _editingConfig = false;
              });
            },
            onCancel:
                config == null
                    ? null
                    : () => setState(() => _editingConfig = false),
            onForget:
                config == null ? null : () => setState(() => _config = null),
          );
        }

        return NotesScreen(
          baseUrl: config.$1,
          username: config.$2,
          onEditSettings: () => setState(() => _editingConfig = true),
        );
      },
    );
  }
}
