# sallehly_app

A new Flutter project.

## Running locally

`flutter run` with no extra flags connects to the **live production
backend** (`https://sallehly.com`) — anything you do (register, create
requests, top up a wallet) writes real data. In debug mode the app now
prints a loud warning in the terminal at startup confirming which backend
it's talking to (see `[FIX-DEVCLEARTEXT-01]` in `lib/main.dart`).

To develop against a local backend instead, run it and pass its address
explicitly:

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

(`10.0.2.2` is how the Android emulator reaches `localhost` on your
machine — use your machine's LAN IP instead for a physical device.) See
`lib/config/app_config.dart` for how this is resolved.

CI/release builds (`flutter build appbundle --release`, etc.) don't pass
`--dart-define` either, so they also fall through to the production
default — this is intentional and matches what actually ships.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
