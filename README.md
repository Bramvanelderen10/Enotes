# Enotes

Enotes is a self-hosted notes app. A .NET 10 minimal API stores notes in SQLite, and a Flutter
client provides Android and web apps. Notes are grouped by the username entered in the client.

The client checks for changes from other devices every two seconds while the notes list or an editor
is open. If an open editor has no unsaved changes, it displays updates from the server. If there are
local unsaved changes, it warns instead of replacing them. If two devices save changes to the same
note, the most recently saved version wins.

## Privacy and network access

There is no authentication. A username is only an identifier used to group notes; it is not a
password or a security boundary. Anyone who can reach the API can read, change, or delete notes for
any username.

Run Enotes only on a trusted private network or make it available through a VPN. If you host the web
app publicly, put both the API and app behind HTTPS and restrict API access appropriately. Do not
expose the API directly to the public internet.

## Install the API on a server with Docker Compose

Install Docker Engine and the Docker Compose plugin on the server. Clone or copy this repository to
the server, then run these commands from the repository directory:

```bash
ENOTES_WEB_ORIGIN=https://notes.example.com docker compose up -d --build
```

Replace `https://notes.example.com` with the exact origin where the web app will be hosted. Include
the scheme and any non-default port, but no path. For example, use `http://192.168.1.20:8080` for a
web app served locally over HTTP. The compose configuration passes this origin to the API to allow
browser requests from that web app. Set it to the correct value whenever you create or update the
service.

The API listens on port `36241`. Check that it is running with:

```bash
curl http://localhost:36241/health
docker compose logs -f enotes
```

The SQLite database is stored at `./data/notes.db` on the server, mounted into the container at
`/data/notes.db`. Docker Compose creates the data directory as needed. Keep this directory on
persistent storage and include it in your backups.

To update the API after changing the repository files:

```bash
ENOTES_WEB_ORIGIN=https://notes.example.com docker compose up -d --build
```

To stop the service without deleting notes:

```bash
docker compose down
```

Do not remove the `data` directory when stopping or updating the service. To make a consistent
backup, stop the service, copy `data/notes.db` to a safe location, then start the service again:

```bash
docker compose down
cp data/notes.db /path/to/backup/notes.db
ENOTES_WEB_ORIGIN=https://notes.example.com docker compose up -d
```

## Install the client

### Android

Build a release APK from the repository root:

```bash
cd src/Enotes.App
flutter pub get
flutter build apk --release
```

Install `build/app/outputs/flutter-apk/app-release.apk` on the Android device. On first launch,
enter the server address, such as `https://notes.example.com` or `http://192.168.1.20:36241`, and
choose a username. The address is the API's reachable URL, not necessarily the server's internal
address. The client saves the server address and username on that device; use the same username on
each device to see the same notes.

### Web

Build the web app:

```bash
cd src/Enotes.App
flutter pub get
flutter build web
```

Publish the contents of `build/web` to a static web host. Configure that host to serve the app over
HTTPS, and set `ENOTES_WEB_ORIGIN` to the app's exact origin when starting the API as shown above.
Configure a reverse proxy or gateway to serve the API over HTTPS as well. Then open the hosted app
and enter the API's HTTPS address and the username to use.

If the app is hosted under a URL subpath instead of the domain root, build with the appropriate
Flutter `--base-href` value for that path.

## Run locally

### API

Install the .NET 10 SDK and run the API from the repository root:

```bash
dotnet run --project src/Enotes.Api
```

The API listens on port `36241` and creates `data/notes.db` by default. To use a different database
file, set `Notes__DatabasePath`, for example:

```bash
Notes__DatabasePath=/var/lib/enotes/notes.db dotnet run --project src/Enotes.Api
```

Browser access is disabled by default. To allow a local web app hosted at `http://localhost:8080`,
configure `Notes__AllowedOrigins__0=http://localhost:8080` when starting the API. Mobile clients do
not use browser CORS.

### Flutter app

Install Flutter, then run:

```bash
cd src/Enotes.App
flutter pub get
flutter run
```

Useful validation commands are `flutter analyze` and `flutter test`, run from `src/Enotes.App`.

## API endpoints

All note endpoints include the username:

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | API health check |
| `GET` | `/api/users/{userName}/notes` | List the user's notes |
| `POST` | `/api/users/{userName}/notes` | Create a note |
| `PUT` | `/api/users/{userName}/notes/{noteId}` | Update a note |
| `DELETE` | `/api/users/{userName}/notes/{noteId}` | Delete a note |
| `GET` | `/openapi/v1.json` | OpenAPI document |
| `GET` | `/scalar/v1` | Interactive API documentation |

Create and update requests use JSON with a title and content:

```json
{
  "title": "Shopping list",
  "content": "Coffee\nApples"
}
```
