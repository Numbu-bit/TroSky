# TroSky Android — release signing

This runbook replaces the previous debug-signing stop-gap (C1 in the
21 Nov 2026 pre-launch audit). It covers: generating the upload
keystore, wiring it into Gradle, enrolling in Play App Signing, keeping
the key safe, and the facts the owner needs when verifying an installed
APK, wiring App Links, or rotating keys.

## Scope and terminology

Two certificates matter and they are **not** the same thing. Confusing
them wastes hours later.

- **Upload certificate.** The signer baked into every AAB/APK shipped
  from this repository. The owner holds the private key and never
  gives it to Google. Play uses the upload certificate only to
  authenticate uploads to the Play Console.
- **Play app-signing certificate.** The signer Google uses to sign the
  APKs that end up on users' devices, after re-signing the uploaded
  AAB. Users' devices see the Play app-signing certificate, not the
  upload certificate. Google holds the private key.

Consequences:

- When Android verifies "is this update the same app as the installed
  one?", it compares against the **Play app-signing** certificate.
- App Links (`assetlinks.json`) must list the **Play app-signing**
  SHA-256 fingerprint for shipped apps (and may also list the upload
  cert fingerprint for debug/tester installs that are signed with the
  upload key directly, e.g. sideloaded internal testing tracks before
  Play re-signs).
- Facebook, Firebase, OAuth providers and SMS integrations usually
  ask for the Play app-signing fingerprint, not the upload one. Both
  are available in the Play Console under **Setup → App integrity**
  after enrollment.

## Generating the upload keystore

Do this once, on a trusted machine, offline where possible. Do not run
these commands in chat, CI logs, or a screen share.

```sh
keytool \
  -genkey -v \
  -keystore trosky-upload.jks \
  -storetype PKCS12 \
  -keyalg RSA \
  -keysize 4096 \
  -validity 25000 \
  -alias trosky-upload
```

`keytool` will prompt for a store password, a key password, and a
distinguished name. Use strong, distinct passwords. Record them in a
password manager under an entry shared with nobody except the owner and
the project's break-glass recovery contact.

Move the generated `trosky-upload.jks` to
`TroSky/frontend/apps/mobile/android/trosky-upload.jks`. That path is
already gitignored (`**/*.jks`).

## Wiring Gradle

`apps/mobile/android/app/build.gradle.kts` reads a gitignored
`apps/mobile/android/key.properties` file. Copy the template:

```sh
cp apps/mobile/android/key.properties.example apps/mobile/android/key.properties
```

Edit the copy and fill in the real values:

```properties
storeFile=../trosky-upload.jks
storePassword=<store password from password manager>
keyAlias=trosky-upload
keyPassword=<key password from password manager>
```

`key.properties` and the keystore file are gitignored. Never commit,
paste, or screenshot either.

## Debug builds are unaffected

The Gradle wiring only touches the **release** build type. `flutter run`
and `flutter build apk --debug` keep using the default debug keystore.
Developers do not need `key.properties` to work on the app.

## Release builds fail loudly when the key is missing

If `key.properties` is missing, incomplete, or points at a keystore file
that doesn't exist, `verifyReleaseSigningReady` fails
`assembleRelease` and `bundleRelease` before Gradle packages anything.
There is no fallback to the debug keystore. This is the whole point of
C1.

If a release build fails with the `verifyReleaseSigningReady` message,
check:

1. `apps/mobile/android/key.properties` exists and has all four values.
2. `storeFile` resolves (it is relative to the android/ directory).
3. The keystore file's passwords match the ones in `key.properties`.

## Store application id

`verifyStoreApplicationId` refuses to produce an AAB with the demo
applicationId (`com.trosky.app.demo`). A store build must use
`com.trosky.app`. If you ever ship `-Pdemo=true` in CI by accident, the
release build fails before the AAB is written.

## Enrolling in Play App Signing

1. Create the TroSky app in the Play Console.
2. On first AAB upload, Play offers Play App Signing. Accept it.
3. Upload the AAB signed with the upload keystore.
4. Play generates the Play app-signing certificate and signs released
   APKs with it. Record both SHA-256 fingerprints (upload + app-signing)
   under **Setup → App integrity** and paste them into the owner's
   password manager alongside the keystore passwords.

Do not opt out of Play App Signing. Without it, losing the upload key
means losing the ability to ship updates ever again. With it, losing
the upload key is recoverable: Play lets the owner register a new upload
key through a signed support ticket.

## Custody and backup

- **Primary copy.** On the owner's development machine at
  `apps/mobile/android/trosky-upload.jks`, outside the repo clone (it
  is gitignored, but keep it in a separate folder to make that
  clear).
- **Backup 1.** Encrypted copy in the owner's password manager as a
  file attachment, alongside the store/key passwords.
- **Backup 2.** Printed hex of the keystore file stored in a sealed
  envelope in a physically separate location, with a readme describing
  how to reconstruct the file. This is a last-resort recovery, not a
  routine step.
- **Do not** email, Slack, or WhatsApp the keystore. **Do not** store
  it in cloud sync folders that sync plaintext (Dropbox, Google
  Drive, iCloud Drive) without wrapping it in an age-encrypted archive
  first.

If the owner shares development with someone else later, the second
developer gets their own `key.properties` with the same values, over an
out-of-band channel (encrypted messaging, 1Password shared vault, in
person), never through this repository.

## Migrating testers off the debug-signed APKs

Devices currently holding the debug-signed TroSky APK (installed during
the Nov 2026 testing window) must **uninstall** the old app before
installing an upload-signed build. Android refuses to install an APK
over an installed app with a different signing identity. The
uninstall drops the app's local data: cached session, encrypted Hive
boxes (safety outbox, rate banner dismissals), SharedPreferences
(onboarding, selected pay method, Home store).

Announce this to the tester group before shipping the first
upload-signed APK. The owner's own TECNO BG6 device needs the same
treatment: `adb uninstall com.trosky.app` before the next install.
Demo builds (`com.trosky.app.demo`) are a separate applicationId and are
not affected.

## Verifying an installed APK's signer

To check which certificate signed an APK on a device:

```sh
# APK pulled from the device
apksigner verify --print-certs trosky.apk
```

Match the printed `SHA-256` against the fingerprints recorded in the
Play Console. An APK downloaded from the Play Store is signed with the
**Play app-signing certificate**, not the upload certificate. A
sideloaded internal-testing APK (uploaded to Play but not yet
re-signed) is signed with the **upload certificate**.

For an AAB:

```sh
jarsigner -verify -verbose -certs trosky.aab
```

## Rotation

Short answer: don't rotate the upload key unless it is compromised. If
it is compromised:

1. Open a Play Console support ticket to register a new upload key
   (Play keeps signing with the existing Play app-signing certificate —
   users are not affected).
2. Generate a new upload keystore following the instructions above.
3. Replace `apps/mobile/android/key.properties` on every machine that
   builds releases.
4. Revoke the old password manager entries after one month of overlap.

The Play app-signing certificate rotates only through Play's Key
Upgrade flow and is out of scope for this document.

## What CI checks

The frontend Github Actions workflow runs `signing-config-check` on
every PR that touches `android/app/build.gradle.kts`. It verifies:

- The file still loads `key.properties` via the documented path.
- The release build type is wired to the `release` signing config.
- There is no textual fallback to the debug keystore for release.

CI never sees the real keystore file or its passwords. CI does not
produce store AABs. Those come from a tagged release workflow with
access to encrypted secrets, which is a separate task outside C1.
