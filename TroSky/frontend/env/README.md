# Environments

Each app reads `API_BASE_URL`, `WS_BASE_URL` and `API_MODE` (`mock` or `live`)
as compile-time defines. To use one:

1. Copy a template: `cp env/dev.example.json env/dev.json` (real `env/*.json`
   files are gitignored).
2. From the app's folder, pass it to Flutter:
   `flutter run --dart-define-from-file=../../env/dev.json`

On the Android emulator the host machine is `10.0.2.2`, not `localhost`.
The staging and prod hosts are placeholders until real ones exist.
