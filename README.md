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

By default the Flutter app expects the API at `http://localhost:8000`. Override
it for devices, emulators, or deployed environments with:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.example.com
```

If you want to keep using the old local-only repositories for development, add:

```bash
flutter run --dart-define=USE_LOCAL_DATA=true
```

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
