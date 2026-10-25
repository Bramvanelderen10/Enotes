# Enotes app

Flutter companion client for Enotes, targeting Android and web.

## Run

```bash
flutter pub get
flutter run
```

On first launch, provide the API address and username. The settings are saved locally and can be
changed from the menu on the notes screen. The app refreshes the note list every two seconds while
that screen is open. An open note editor also checks for remote changes; it refreshes automatically
while untouched and warns rather than replacing local unsaved edits.

## Build

```bash
flutter build apk
flutter build web
```

For browser use, serve the API over HTTPS when the web app is served over HTTPS.
