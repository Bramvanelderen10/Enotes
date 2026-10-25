# Enotes

Enotes is a self-hosted notes app. A .NET 10 minimal API stores notes in SQLite, and a Flutter
client provides Android and web apps. Notes are grouped by the username entered in the client.

The client checks for changes from other devices every two seconds while the notes page or a note is
open. The notes page lays the notes out as a grid of small preview cards, two per row on a phone.
Tapping a note opens it on its own screen instead of a dialog, and that screen has no save button:
every edit is sent to the API shortly after typing stops. While the open note is untouched, newer
versions from the server are loaded into it. If two devices save changes to the same note, the most
recently saved version wins.

## What this repository contains

- `src/Enotes.Api`: backend service (minimal API)
- `src/Enotes.App`: Flutter client for Android and web (separate README)

## Features

- Notes API scoped by username (`GET`, `POST`, `PUT`, `DELETE`)
- SQLite storage with the schema created automatically on startup
- Server-side validation (username 1-100, title 1-200, content up to 1,000,000 characters)
- OpenAPI document + Scalar docs UI
- Optional CORS allow-list for a separately hosted web app
- Two-second change polling on the notes page and on the open note
- Notes page shown as a grid of compact preview cards: two per row on a phone and more on a wide
  window, each card showing the title and up to six lines of the content
- Full-screen note editor with two-way sync and automatic saving (no save button)
- Copy button that puts the title and text of a note on the clipboard
- Delete button on the note screen, next to the copy button
- Dark theme by default, with a matching dark Android launch screen and web page
- Flutter client for Android and web
- Docker-ready deployment with published API and web images
- GitHub Actions workflow that builds the container images, the Android APK and the web bundle

## Privacy and network access

There is no authentication. A username is only an identifier used to group notes; it is not a
password or a security boundary. Anyone who can reach the API can read, change, or delete notes for
any username.

Run Enotes only on a trusted private network or make it available through a VPN. If you host the web
app publicly, put both the API and app behind HTTPS and restrict API access appropriately. Do not
expose the API directly to the public internet.

## Quick start (Docker)

Install Docker Engine and the Docker Compose plugin on the server, then clone or copy this repository
to the server. `docker compose up -d` pulls the published API image
(`ghcr.io/bramvanelderen10/enotes:main`) and Flutter web image
(`ghcr.io/bramvanelderen10/enotes-web:main`); add `--build` to build both images from source instead.

The important detail: **the browser talks to the API directly**, so the API has to allow the origin
the web app is opened from (`ENOTES_WEB_ORIGIN`). Android clients are unaffected by CORS, and a
reverse proxy that serves the web app and the API from one origin removes the need for it entirely.

Replace `https://notes.example.com` with the web app's exact public origin, including the scheme and
any non-default port, but not a path.

> Both images come from GitHub Container Registry. GHCR packages are private by default: if a package
> is private, `docker compose up -d` cannot pull it and Compose builds that image from source
> instead. Make the package public in its GHCR settings to pull it (see Troubleshooting).

```yaml
services:
  enotes-api:
    image: ghcr.io/bramvanelderen10/enotes:main
    container_name: enotes-api
    ports:
      - "36241:36241"
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - Notes__DatabasePath=/data/notes.db
      # Origin used to open the web app in a browser. Add Notes__AllowedOrigins__1, __2, ...
      # for extra origins. Browsers enforce CORS; Android clients do not.
      - Notes__AllowedOrigins__0=${ENOTES_WEB_ORIGIN:-http://localhost:8080}
    volumes:
      # Binds the database next to this compose file, so backing up ./data is enough.
      - ./data:/data
    restart: unless-stopped

  enotes-web:
    image: ghcr.io/bramvanelderen10/enotes-web:main
    container_name: enotes-web
    ports:
      - "${ENOTES_WEB_PORT:-8080}:80"
    depends_on:
      - enotes-api
    restart: unless-stopped
```

The Compose file serves the web app on port `8080` and the API on port `36241`. If the web app and
API are served through the same origin by a reverse proxy, CORS configuration is not needed. If they
have different origins, set `ENOTES_WEB_ORIGIN` to the origin used to open the web app in the
browser. For example, use `http://192.168.1.20:8080` when accessing the web app directly over a
trusted local network. This only permits browser requests from that origin; it is not authentication
or access control.

Start and verify:

```bash
ENOTES_WEB_ORIGIN=https://notes.example.com docker compose up -d
curl http://localhost:36241/health
docker compose logs -f
```

Open `http://<server-address>:8080` to use the web app. On first launch, enter the API address
reachable by the browser, for example `http://<server-address>:36241`, and a username. Android
clients also connect to the API address on port `36241`; CORS does not apply to Android. Use the
same username on each device to see the same notes.

The SQLite database is stored at `./data/notes.db` on the server, mounted into the container at
`/data/notes.db`. Docker Compose creates the data directory as needed. Keep this directory on
persistent storage and include it in your backups.

To pick up newer published images, or to update both services after changing the repository files,
use the same web origin configuration used for deployment:

```bash
# Pull the latest published images
ENOTES_WEB_ORIGIN=https://notes.example.com docker compose pull
ENOTES_WEB_ORIGIN=https://notes.example.com docker compose up -d

# Or rebuild both images from the repository sources
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

> If the copy fails with a permission error, the file was created by the container's root user. Fix
> ownership once with `sudo chown -R "$USER":"$USER" data` (see Troubleshooting).

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
address. The client saves the server address and username on that device and prefills them when the
settings screen is opened again, so they can be edited instead of retyped; use the same username on
each device to see the same notes.

Alternatively, download the prebuilt APK attached to a version-tag GitHub Release.

### Web

Build the web app:

```bash
cd src/Enotes.App
flutter pub get
flutter build web
```

Alternatively to the Compose web container, publish the contents of `build/web` to a static web
host. Serve the app and API over HTTPS. If they are hosted on different origins, set
`ENOTES_WEB_ORIGIN` to the app's exact origin when starting the API as shown above. If a reverse
proxy serves both from the same origin, CORS configuration is not needed. Then open the hosted app
and enter the API's reachable HTTPS address and the username to use.

If the app is hosted under a URL subpath instead of the domain root, build with the appropriate
Flutter `--base-href` value for that path.

## API endpoints

### System

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check (`{"status":"ok"}`) |
| `GET` | `/openapi/v1.json` | OpenAPI document |
| `GET` | `/scalar/v1` | Interactive API documentation |

### Notes

All note endpoints include the username:

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/users/{userName}/notes` | List the user's notes, newest first |
| `POST` | `/api/users/{userName}/notes` | Create a note |
| `PUT` | `/api/users/{userName}/notes/{noteId}` | Update a note |
| `DELETE` | `/api/users/{userName}/notes/{noteId}` | Delete a note |

Create and update requests use JSON with a title and content:

```json
{
  "title": "Shopping list",
  "content": "Coffee\nApples"
}
```

Notes in responses also carry `id`, `createdAtUtc` and `updatedAtUtc`. Both timestamps are UTC in
ISO 8601 form (with the trailing `Z`), and `updatedAtUtc` changes on every save, which is what the
client uses to notice edits made on other devices.

Responses:

| Status | Meaning |
|---|---|
| `200` | Notes listed, or a note updated |
| `201` | Note created |
| `204` | Note deleted |
| `400` | Username, title, or content failed validation |
| `404` | No note with that id exists for that username |

### Examples

Create a note:

```bash
curl -X POST http://localhost:36241/api/users/bram/notes \
  -H "Content-Type: application/json" \
  -d '{"title":"Shopping list","content":"Coffee\nApples"}'
```

List notes:

```bash
curl http://localhost:36241/api/users/bram/notes
```

Update a note:

```bash
curl -X PUT http://localhost:36241/api/users/bram/notes/<noteId> \
  -H "Content-Type: application/json" \
  -d '{"title":"Shopping list","content":"Coffee\nApples\nBread"}'
```

Delete a note:

```bash
curl -X DELETE http://localhost:36241/api/users/bram/notes/<noteId>
```

## Configuration

Settings are under `Notes` in `appsettings.json` or environment variables (`__` separator).

| Key | Default | Description |
|---|---|---|
| `Notes:DatabasePath` | `data/notes.db` | SQLite database file; its directory is created on startup |
| `Notes:AllowedOrigins` | `[]` (CORS disabled) | Origins allowed to call the API from a browser |

**Docker-only environment variables** (used by `docker-compose.yml`, not part of the `Notes` config
section):

| Variable | Default | Description |
|---|---|---|
| `ENOTES_WEB_ORIGIN` | `http://localhost:8080` | Passed to `Notes__AllowedOrigins__0` |
| `ENOTES_WEB_PORT` | `8080` | Host port for the Flutter web container |

Example `appsettings.json` (the Docker examples above use environment variables instead):

```json
{
  "Notes": {
    "DatabasePath": "data/notes.db",
    "AllowedOrigins": ["http://localhost:8080"]
  }
}
```

> `AllowedOrigins` is empty by default, which disables CORS entirely. List every origin that opens
> the web app in a browser, for example `http://192.168.1.20:8080`. This only permits browser
> requests from those origins; it is not authentication or access control.

### Repo `docker-compose.yml` vs. this guide

The committed [`docker-compose.yml`](docker-compose.yml) declares the same two services with the
moving `:main` image tags plus a `build:` fallback for each image, so `docker compose up -d` pulls
the published images and `docker compose up -d --build` builds from source. It reads the web origin
and the published web port from `ENOTES_WEB_ORIGIN` and `ENOTES_WEB_PORT`, defaulting to
`http://localhost:8080` and `8080`. Pin a version tag such as `:1.0.0` instead of `:main` for
reproducible deployments.

## Development

Prerequisites: [.NET 10 SDK](https://dotnet.microsoft.com/download) and, for the client,
[Flutter](https://docs.flutter.dev/get-started/install).

Run the API from the repository root:

```bash
dotnet run --project src/Enotes.Api
```

Build the API:

```bash
dotnet build src/Enotes.Api/Enotes.Api.csproj
```

Run the Flutter client:

```bash
cd src/Enotes.App
flutter pub get
flutter run
```

Useful validation commands are `flutter analyze` and `flutter test`, run from `src/Enotes.App`.

`src/Enotes.App/pubspec.lock` and `src/Enotes.App/web` are committed on purpose: the container image
and the release builds need the web entrypoint (`flutter build web` fails without it), and the
lockfile keeps every build on the same dependency versions. Run `flutter pub get` after editing
`pubspec.yaml` so the lockfile stays in sync.

On pushes to `main` and version tags, the GitHub Actions workflow builds and pushes the API container
image (`ghcr.io/<owner>/<repository>`) and Flutter web image
(`ghcr.io/<owner>/<repository>-web`). For example:

```bash
docker pull ghcr.io/bramvanelderen10/enotes:main
docker pull ghcr.io/bramvanelderen10/enotes-web:main
```

For version tags and manual workflow runs, it builds an Android APK and a ZIP of the Flutter web
release; version-tag runs attach both client releases to the GitHub Release.

### Local API configuration

The API listens on port `36241` and creates `data/notes.db` in the API project directory by default.
To use a different database file, set `Notes__DatabasePath`, for example:

```bash
Notes__DatabasePath=/var/lib/enotes/notes.db dotnet run --project src/Enotes.Api
```

Browser CORS is disabled by default. For a local web app served separately at
`http://localhost:8080`, configure `Notes__AllowedOrigins__0=http://localhost:8080` when starting the
API. This is unnecessary for mobile clients or when a reverse proxy serves the web app and API from
the same origin.

## Repo layout

```text
src/
  Enotes.Api/            # Backend service (minimal API)
  Enotes.App/            # Flutter client (Android + web)
Dockerfile               # API container image
docker-compose.yml       # Runs the API and web containers together
.github/workflows/
  build-and-publish.yml  # Container images, APK + web bundles, GitHub Releases
```

## Troubleshooting

| Problem | Check |
|---|---|
| API not reachable | Port mapping/firewall for `36241` |
| Client cannot connect | The API address entered in the client must be reachable from that device |
| Browser console shows a CORS error | `ENOTES_WEB_ORIGIN` / `Notes:AllowedOrigins` must match the web app's origin, including scheme and port; Android clients do not use CORS |
| Notes missing on another device | Both devices need the same username and the same API address |
| A note was overwritten | Expected: the most recently saved version wins; the editor saves every edit automatically, so the latest change wins |
| "Not saved" in the note screen | The automatic save failed; check that the API is reachable and that the note still has a title of at most 200 characters |
| Edits by another device do not appear in an open note | Expected while you have local changes in that note; they are pushed first, then the newest version wins |
| `cp data/notes.db` fails with "Permission denied" | The container runs as root and created the file; run `sudo chown -R "$USER":"$USER" data` |
| `docker compose up` fails with `denied` while pulling an image | The GHCR package is private; make it public in the package settings, run `docker login ghcr.io`, or build locally with `docker compose up -d --build` |
| Ports `36241` or `8080` already in use | Change the host side of the port mappings or set `ENOTES_WEB_PORT` |
| `/scalar/v1` shows nothing | Open `/openapi/v1.json` to confirm the API is serving the document |
