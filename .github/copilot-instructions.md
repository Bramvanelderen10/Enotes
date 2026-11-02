# Enotes

Enotes is a private notes app with an ASP.NET Core .NET 10 minimal API and a Flutter Android/web
client. Notes are stored in SQLite and scoped by a username that is an identifier, not an authenticator.

## Backend

- API project: `src/Enotes.Api`
- Settings live in `src/Enotes.Api/appsettings.json` under `Notes`, or in environment variables
  (`__` separator), for example `Notes__AllowedOrigins__0`
- SQLite database path: `Notes:DatabasePath` (defaults to `data/notes.db`)
- Uploaded files are kept under `Notes:StoragePath` (defaults to a `files` folder beside the database);
  a file note's bytes stream to disk, never into SQLite, and `Notes:MaxFileSizeBytes` (default 10 GB)
  caps both the upload and the Kestrel request body
- The database is created with `EnsureCreatedAsync` and has no EF migrations; columns added to `Note`
  are applied by `NotesDatabase.InitializeAsync`, so update that when the model changes
- API listens on port `36241`
- Note endpoints are in `src/Enotes.Api/Notes`
- Run with `dotnet run --project src/Enotes.Api`

## Flutter client

- App project: `src/Enotes.App`
- `src/Enotes.App/pubspec.lock` and `src/Enotes.App/web` are committed on purpose (the image, APK and
  web builds need them); do not add them to `.gitignore`.
- Settings store the API address and username in shared preferences.
- Note changes from other devices are polled every two seconds while the notes screen or a note
  editor is open. Do not silently overwrite local unsaved editor changes.
- Run `flutter analyze` and `flutter test` from `src/Enotes.App`.

## Privacy

There is no authentication. Never describe the username as a security boundary. Keep the API on a
trusted network or behind a VPN and HTTPS; anyone with API access can read and modify any user's notes.
