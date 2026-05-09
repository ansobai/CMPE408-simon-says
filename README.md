# simon_says

Simon Says is a Flutter mobile app.

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

## Library Installation Commands

If you want to add the libraries used by this project manually, run:

```bash
flutter pub add cupertino_icons
flutter pub add audioplayers
flutter pub add crypto
flutter pub add path
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
```
