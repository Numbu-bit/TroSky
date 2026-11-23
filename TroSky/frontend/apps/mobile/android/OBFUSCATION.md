# TroSky Android — code shrinking and obfuscation

C2 of the 21 Nov 2026 pre-launch audit. Pairs with
[SIGNING.md](./SIGNING.md). Both must be read before producing a store
build.

## What's turned on

- **R8 full-mode** on the release build type
  (`isMinifyEnabled = true`). R8 is Google's shrinker/obfuscator, the
  default when AGP sees `minifyEnabled` on. It removes unused Java/
  Kotlin classes and renames the rest.
- **Resource shrinking** (`isShrinkResources = true`). R8 drops
  unreferenced drawables, strings and layouts from the AAB/APK.
- **ProGuard-style keep rules** in
  [`app/proguard-rules.pro`](./app/proguard-rules.pro), plus
  `proguard-android-optimize.txt` from AGP, plus the consumer rules
  that Flutter ships for `io.flutter.**` and
  `GeneratedPluginRegistrant`.
- **Dart tree-shake and symbol obfuscation** when
  `flutter build … --release --obfuscate
  --split-debug-info=<dir>` is invoked (see
  [`tool/build_store.sh`](../tool/build_store.sh)). Without
  `--obfuscate`, Dart ships readable class and method names in the
  AOT snapshot.

The shipping bar: a store AAB has no plaintext Dart symbols, no
unreferenced Java/Kotlin, no unused resources, and the owner keeps
`mapping.txt` + per-platform `.symbols` files so any post-release
crash can be mapped back without source access.

## What this does **not** do

- Obfuscation **is not secrecy**. API endpoints, telemetry event names,
  localization strings and feature-flag names remain extractable from
  the APK by a determined attacker. Treat anything that must stay
  secret (keys, tokens, URLs with embedded credentials) as if it were
  public; keep it on the backend.
- R8 does **not** shrink Dart code. Only the embedding and plugin
  Java/Kotlin classes go through R8.
- `--obfuscate` does **not** encrypt Dart bytecode. It removes name
  metadata; the VM still interprets the snapshot.
- There is no DRM. Side-loaders will still side-load.

## Keep-rules policy

- Every rule in `proguard-rules.pro` has a one-line reason on the line
  above it.
- Pure-Dart packages (Hive, Dio, Riverpod, go_router, flutter_map,
  flutter_svg, qr_flutter, web_socket_channel) **do not** need keep
  rules. They never ship Java/Kotlin that R8 can see.
- Platform-channel plugins we ship (`geolocator`, `url_launcher`,
  `shared_preferences`, `path_provider`, `flutter_secure_storage`,
  `share_plus`, `package_info_plus`) register through Flutter's
  embedding, which the Flutter Gradle Plugin preserves via consumer
  rules. We do not add rules for them.
- If a future plugin uses reflection (Gson, Jackson, Moshi,
  `Class.forName`, a service loader), add a **named** `-keep` rule for
  exactly that class, with a line comment explaining why.

## Producing a store build

The reproducible entry point is [`tool/build_store.sh`](../tool/build_store.sh):

```sh
cd TroSky/frontend/apps/mobile

# Store Android App Bundle (Play)
tool/build_store.sh aab --env prod

# Side-load APK for an internal test track
tool/build_store.sh apk --env prod

# iOS archive (macOS only)
tool/build_store.sh ios --env prod
```

The script:

1. Checks that the env file exists and (for `--env prod`) does not
   enable `TESTER_MENU`.
2. Reads the `version:` line from `pubspec.yaml`.
3. Writes Dart symbols to `build/symbols/<version>/<platform>/`.
4. Runs `flutter build … --release --obfuscate --split-debug-info=…`
   with the env file loaded via `--dart-define-from-file`.
5. Copies the R8 `mapping.txt` next to the Dart symbols.

The Gradle `verifyReleaseSigningReady` task (from C1) runs first, so
a missing `key.properties` fails the build before anything is
packaged. There is never an unsigned or debug-signed AAB.

## Symbolicating a crash

Keep the `build/symbols/<version>/` folder and the `r8-mapping.txt` it
contains for every build that reaches testers or the store. Store
them out of the repo (gitignored), ideally alongside the keystore in
the owner's encrypted backup.

### Dart stack traces

```sh
flutter symbolize \
  -i obfuscated_stack.txt \
  -d build/symbols/<version>/<platform>/app.android-arm64.symbols
```

`obfuscated_stack.txt` is the raw crash log from the device or Play
Console. The `app.android-arm64.symbols` file is specific to one ABI;
match it to the architecture the crashing device reports.

### Java/Kotlin stack traces

R8 writes a mapping file at
`apps/mobile/build/app/outputs/mapping/release/mapping.txt`. The
store-build script copies it as `r8-mapping.txt` next to the Dart
symbols. Use R8's `retrace` tool:

```sh
retrace build/symbols/<version>/android/r8-mapping.txt < obfuscated_stack.txt
```

For Play Console crashes: upload the AAB's `mapping.txt` via **App
bundle explorer → Downloads → ReTrace mapping**, and Play will
de-obfuscate traces in the Crashes dashboard automatically.

### Proving a build is shrinked + obfuscated

After a store build, verify the AAB contains the expected artefacts:

```sh
# R8 mapping exists
test -s apps/mobile/build/app/outputs/mapping/release/mapping.txt

# Dart symbols exist per ABI
ls apps/mobile/build/symbols/<version>/aab/
# -> app.android-arm.symbols
#    app.android-arm64.symbols
#    app.android-x64.symbols

# R8 actually renamed things
unzip -p apps/mobile/build/app/outputs/bundle/release/app-release.aab \
  BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map | head
# -> a short header + mapping entries; the file is multiple KB

# Sanity check: common Dart class names should NOT be visible in the AOT
# snapshot after --obfuscate
```

If the AAB's `BUNDLE-METADATA` folder has no `proguard.map`, R8 didn't
run and the build must be rejected.

## Interactions with other audit items

- **C1 (signing):** this runs on top of C1. Order: C1 fails the
  release build if keys are missing; then C2's R8 + Dart obfuscation
  processes the artefact.
- **C4 (prod env):** the store-build script rejects
  `TESTER_MENU=true` in a `--env prod` build.
- **H6 (mock isolation):** mock-only credentials and seeded phone
  numbers must not reach release builds. Obfuscation does not hide
  them; H6 is the real fix. C2 only guarantees that after H6 lands,
  the code path is also inaccessible by name.
