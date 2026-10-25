# Enotes

Enotes is a private notes app with a .NET 10 API and a Flutter client for Android and web.
The API stores notes in SQLite, partitioned by the username selected in the app.

## Migration plan

### Removed from the copied Jellynizer codebase

- Media discovery, filename parsing, move planning/execution, cleanup, and move-history storage.
- qBittorrent integration, torrent handling, file browsing, library management, and log streaming.
- The old media-organizer Flutter screens, intent handling, artwork tooling, and stale tests.
- Media-specific Docker configuration and the old project/solution naming.

### Foundation implemented

- SQLite-backed note records with create, list, edit, and delete endpoints.
- Android/web Flutter app with initial server + username setup, locally saved settings, and note editing.
- Two-second polling on the notes screen and open editor for updates from other devices. An open,
  untouched editor refreshes from remote changes; local unsaved edits are not silently overwritten.
  This gives near-live refresh without a SignalR connection or additional Flutter package.
- Docker configuration and a persistent database volume.

### Suggested next steps

1. Add tests for API validation, per-user isolation, and note CRUD.
2. Add conflict handling for simultaneous edits; the initial version uses last-save-wins.
3. Add optional SignalR notifications if polling becomes too chatty or immediate updates are needed.
4. Add HTTPS/reverse-proxy and backup guidance before exposing the server outside a trusted network.

## Important privacy note

The username only partitions notes; **it is not authentication**. Anyone who can reach the API can
read, alter, or delete notes for any username. Keep the server on a trusted private network or behind a
VPN and HTTPS. Do not expose this API directly to the public internet.

## Run the API

Install the .NET 10 SDK, then run:

```bash
dotnet run --project src/Enotes.Api
```

The API listens on port `36241`. SQLite is created at `data/notes.db` by default. Override the path
with `Notes__DatabasePath`.
For web access, configure the exact hosted app origin with `Notes__AllowedOrigins__0`, for example
`https://notes.example.com`. The API does not enable browser CORS by default.

## Run the Flutter app

Install Flutter, then:

```bash
cd src/Enotes.App
flutter pub get
flutter run
```

For web hosting:

```bash
flutter build web
```

Deploy `build/web` to a static web host. Set the API's `Notes__AllowedOrigins__0` to that host's
exact origin, then enter the API address and username on first launch.
When the app is hosted over HTTPS, configure the API behind HTTPS too; browsers block web apps from
calling insecure HTTP APIs.

## Docker

```bash
docker compose up --build -d
curl http://localhost:36241/health
```

The compose file maps `./data` for SQLite persistence. Keep that directory in backups.

## API

All note paths include a username:

| Method | Path | Description |
|---|---|---|
| GET | `/health` | API connectivity check |
| GET | `/api/users/{userName}/notes` | List a user's notes |
| POST | `/api/users/{userName}/notes` | Create a note |
| PUT | `/api/users/{userName}/notes/{noteId}` | Update a note |
| DELETE | `/api/users/{userName}/notes/{noteId}` | Delete a note |
| GET | `/openapi/v1.json` | OpenAPI document |
| GET | `/scalar/v1` | Interactive API docs |

Create/update JSON:

```json
{
  "title": "Shopping list",
  "content": "Coffee\nApples"
}
```
