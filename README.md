# simon_says

Simon Says is a Flutter mobile app.

The app now supports a shared FastAPI/PostgreSQL backend for auth, synced
sessions, player stats, and the leaderboard.

## Prerequisites

- Install the Flutter SDK
- Install a device emulator or connect a physical device

Verify Flutter is available:

```bash
flutter --version
flutter doctor
```

## Project Setup

Clone the repository and install all project dependencies declared in `pubspec.yaml`:

```bash
git clone https://github.com/ansobai/CMPE408-simon-says.git
cd CMPE408-simon-says
flutter pub get
```

## Backend Setup

Create a backend virtual environment, install the API dependencies, and copy the
example environment file:

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r backend/requirements.txt
copy backend\.env.example backend\.env
```

Run the API with:

```bash
python -m uvicorn backend.app.main:create_app --factory --reload
```

By default the Flutter app expects the API at `http://89.167.98.133:8000`. Override
it for devices, emulators, or deployed environments with:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.example.com
```

If you want to keep using the old local-only repositories for development, add:

```bash
flutter run --dart-define=USE_LOCAL_DATA=true
```

## Docker Deployment

The current repo is ready to deploy the shared backend with Docker Compose:

- `api`: FastAPI app
- `db`: PostgreSQL with a named Docker volume for persistence

The Flutter app itself is still primarily a mobile/desktop client. It is not
ready for browser deployment yet because runtime code imports `dart:io`, so the
remote Docker deployment target is the backend API.

### On the remote server

Clone the repo, copy the deployment env file, and set real secrets:

```bash
git clone https://github.com/ansobai/CMPE408-simon-says.git
cd CMPE408-simon-says
cp .env.example .env
```

Edit `.env` and change at least:

- `POSTGRES_PASSWORD`
- `JWT_SECRET`
- `CORS_ORIGINS` if you later add a browser client

Start the stack:

```bash
docker compose up -d --build
```

Check that both services are healthy:

```bash
docker compose ps
docker compose logs -f api
curl http://YOUR_SERVER_IP:8000/healthz
```

If your server firewall is enabled, allow the API port:

```bash
sudo ufw allow 8000/tcp
```

### Point the Flutter app at the server

Run the app with the remote API URL:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:8000
```

If you later put the API behind a reverse proxy with TLS, switch that URL to
`https://...`.

## Library Installation Commands

If you want to add the libraries used by this project manually, run:

```bash
flutter pub add cupertino_icons
flutter pub add audioplayers
flutter pub add crypto
flutter pub add http
flutter pub add path
flutter pub add shared_preferences
flutter pub add sqflite
flutter pub add --dev flutter_lints
```

## Run The App

```bash
flutter run
```

## Test

```bash
flutter test
python -m pytest backend/tests
```
