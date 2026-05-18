# simon_says

Simon Says is a Flutter mobile app.

The app now supports Clerk-backed authentication plus a shared
FastAPI/PostgreSQL backend for synced
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

By default the Flutter app expects the API at `https://simonthats.com`. When you
run the app against the shared backend, pass both the API URL and your Clerk
publishable key:

```bash
flutter run ^
  --dart-define=API_BASE_URL=https://your-api.example.com ^
  --dart-define=CLERK_PUBLISHABLE_KEY=pk_test_your_publishable_key
```

If you want to keep using the old local-only repositories for development, add:

```bash
flutter run --dart-define=USE_LOCAL_DATA=true
```

## Docker Deployment

The current repo is ready to deploy the shared backend with Docker Compose and
an Nginx TLS edge proxy:

- `api`: FastAPI app on the internal Docker network
- `db`: PostgreSQL with a named Docker volume for persistence
- `nginx`: terminates TLS on `443`, redirects `80` to `443`, and proxies to `api`

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
- `CLERK_SECRET_KEY`
- `CLERK_AUTHORIZED_PARTIES` if you want Clerk to enforce specific app origins
- `SERVER_NAME` to the DNS name clients will use, for example `api.example.com`
- `CORS_ORIGINS` if you later add a browser client

Place your TLS certificate and key at:

```bash
deploy/nginx/certs/fullchain.pem
deploy/nginx/certs/privkey.pem
```

Those files are mounted into the Nginx container and are intentionally ignored by
Git. The expected production setup is a real certificate for `SERVER_NAME`
issued by a CA such as Let's Encrypt.

Start the stack:

```bash
docker compose up -d --build
```

Check that the services are healthy:

```bash
docker compose ps
docker compose logs -f api
docker compose logs -f nginx
curl -I http://YOUR_SERVER_DOMAIN/healthz
curl https://YOUR_SERVER_DOMAIN/healthz
```

If your server firewall is enabled, allow the web ports:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Point the Flutter app at the server

Run the app with the remote API URL and Clerk publishable key:

```bash
flutter run ^
  --dart-define=API_BASE_URL=https://YOUR_SERVER_DOMAIN ^
  --dart-define=CLERK_PUBLISHABLE_KEY=pk_live_your_publishable_key
```

The Flutter client now rejects insecure non-local `http://` API URLs at startup,
so production deployments must use HTTPS. Plain `http://` is only accepted for
local development hosts such as `localhost` or Android emulator loopback
`10.0.2.2`.

## Library Installation Commands

If you want to add the libraries used by this project manually, run:

```bash
flutter pub add cupertino_icons
flutter pub add audioplayers
flutter pub add clerk_flutter
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
