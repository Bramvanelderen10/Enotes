import 'package:enotes_app/screens/setup_screen.dart';
import 'package:enotes_app/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('setup asks for server and username', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(storage: StorageService(), onConfigured: (_, _) {}),
      ),
    );

    expect(find.text('Server address'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}
