import 'package:flutter/material.dart';

import 'screens/notes_screen.dart';
import 'screens/setup_screen.dart';
import 'services/storage_service.dart';

void main() {
  runApp(const EnotesApp());
}

class EnotesApp extends StatelessWidget {
  const EnotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enotes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const _EntryPoint(),
    );
  }
}

class _EntryPoint extends StatefulWidget {
  const _EntryPoint();

  @override
  State<_EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<_EntryPoint> {
  final _storage = StorageService();
  late final Future<(String, String)?> _configFuture = _storage.getConfig();
  (String, String)? _config;
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
        if (config == null) {
          return SetupScreen(
            storage: _storage,
            onConfigured: (url, username) {
              setState(() => _config = (url, username));
            },
          );
        }

        return NotesScreen(
          baseUrl: config.$1,
          username: config.$2,
          storage: _storage,
          onDisconnect: () => setState(() => _config = null),
        );
      },
    );
  }
}
