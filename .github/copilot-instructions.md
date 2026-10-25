# Enotes

Enotes is a private notes app with an ASP.NET Core .NET 10 minimal API and a Flutter Android/web
client. Notes are stored in SQLite and scoped by a username that is an identifier, not an authenticator.

## Backend

- API project: `src/Enotes.Api`
- Settings live in `src/Enotes.Api/appsettings.json` under `Notes`, or in environment variables
  (`__` separator), for example `Notes__AllowedOrigins__0`
- SQLite database path: `Notes:DatabasePath` (defaults to `data/notes.db`)
- API listens on port `36241`
- Note endpoints are in `src/Enotes.Api/Notes`
- Run with `dotnet run --project src/Enotes.Api`

## Flutter client

- App project: `src/Enotes.App`
- Settings store the API address and username in shared preferences.
- Note changes from other devices are polled every two seconds while the notes screen or a note
  editor is open. Do not silently overwrite local unsaved editor changes.
- Run `flutter analyze` and `flutter test` from `src/Enotes.App`.

## Privacy

There is no authentication. Never describe the username as a security boundary. Keep the API on a
trusted network or behind a VPN and HTTPS; anyone with API access can read and modify any user's notes.
