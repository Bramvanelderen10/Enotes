# Enotes app

Flutter companion client for Enotes, targeting Android and web.

## Run

```bash
flutter pub get
flutter run
```

On first launch, provide the API address and username. The settings are saved locally and can be
changed from the menu on the notes screen: the form opens with the server address and username that
are in use, so they can be edited instead of typed again. Saving the form replaces the stored details;
the back button (or the system back gesture) returns to the notes without changing them, and "Forget
saved server" clears the stored details and shows an empty form. The app refreshes the notes every two
seconds while that screen is open.

Notes are shown as a grid of compact cards: title plus up to six lines of the content, so a short
note stays a small square and a long one grows to about six lines before it is cut off. A phone shows
two columns; wider windows fit more columns, with each card between roughly 120 and 240 logical
pixels wide (that width is the `maxColumnWidth` of `lib/widgets/masonry_grid.dart`).

Tapping a card (or "New note") opens the note on its own screen with a back button. That screen has
no save button: every edit is sent to the API shortly after you stop typing, and the app bar reports
the state (`Unsaved changes`, `Saving…`, `All changes saved`, or `Not saved`). While the note is
untouched, the screen also polls for remote changes and loads them; if you are editing at the same
time, your change is saved first and the most recently saved version wins.

The app bar of the note screen also has a copy button, which puts the title and text of the note on
the clipboard, and a delete button (for notes that exist on the server) that asks for confirmation and
returns to the notes page.

## Theme

The app is dark by default: the single theme in `lib/main.dart` uses
`ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark)`, so it looks the same on a
device that is set to light or to dark. Every other color is derived from that seed.

The Android launch screen (`res/values/colors.xml`, `res/values/styles.xml`, the `launch_background`
drawables) and the web page (`web/index.html`, `web/manifest.json`) paint the theme's surface color
before Flutter's first frame, so starting the app does not flash white. `test/theme_test.dart` fails if
those files and the theme color drift apart.

## Build

```bash
flutter build apk
flutter build web
```

For browser use, serve the API over HTTPS when the web app is served over HTTPS.
