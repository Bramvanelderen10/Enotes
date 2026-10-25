import 'dart:io';

import 'package:enotes_app/main.dart';
import 'package:enotes_app/screens/setup_screen.dart';
import 'package:enotes_app/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory storage, so the app can start without the preferences plugin.
class _FakeStorage extends StorageService {
  @override
  Future<(String, String)?> getConfig() async => null;
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

void main() {
  testWidgets('the app renders dark on light and dark devices', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    for (final brightness in [Brightness.light, Brightness.dark]) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await tester.pumpWidget(EnotesApp(storage: _FakeStorage()));
      await tester.pump();

      final theme = Theme.of(tester.element(find.byType(SetupScreen)));
      expect(
        theme.brightness,
        Brightness.dark,
        reason: 'the app is dark by default, even on a $brightness device',
      );
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, isNot(Colors.white));
    }
  });

  test('the launcher and web backgrounds match the dark theme surface', () {
    // Keep this in sync with the theme in lib/main.dart; a mismatch shows up as
    // a white flash while the app starts.
    final surface = _hex(
      ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ).surface,
    );
    expect(surface, '#121318');

    expect(
      File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
      contains(surface),
      reason: 'colors.xml defines the launch and window background',
    );
    expect(
      File('web/index.html').readAsStringSync(),
      contains(surface),
      reason: 'the web page is painted before Flutter loads',
    );
    expect(
      File('web/manifest.json').readAsStringSync(),
      contains(surface),
      reason: 'the installed web app splash uses background_color',
    );

    for (final path in const [
      'android/app/src/main/res/drawable/launch_background.xml',
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('@color/enotes_background'),
        reason: '$path should use the dark background',
      );
    }
  });
}
