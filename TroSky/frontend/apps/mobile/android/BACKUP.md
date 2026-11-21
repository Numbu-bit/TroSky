# TroSky Android — backup and restore isolation

C3 of the 21 Nov 2026 pre-launch audit. This runbook explains what we
exclude from Android cloud backups and device-to-device transfer, what
OEMs can still do despite our rules, and the iOS counterpart for
flutter_secure_storage.

## Shipping policy, in one sentence

Nothing TroSky writes to a device lands in Google Drive auto-backup or
Android device-transfer. A new install, even one restored from a prior
TroSky install's backup, is indistinguishable from a first install for
TroSky's purposes.

## What's on disk, and where it lives

The audit's first-step inventory of on-device state:

| Store | Domain | Contents | Sensitivity |
| --- | --- | --- | --- |
| `flutter_secure_storage` → `trosky.refresh_token` | sharedpref | Bearer refresh token | **Secret** (replays the session) |
| `flutter_secure_storage` → `trosky.safety_outbox.hive_key` | sharedpref | AES key for SOS outbox | **Secret** |
| `flutter_secure_storage` → `trosky.tickets.hive_key` | sharedpref | AES key for offline tickets | **Secret** |
| `flutter_secure_storage` → `trosky.rate_banner.hive_key` | sharedpref | AES key for rate-banner dismissals | Low (opaque key) |
| Hive `safety_outbox_v1` | file | Encrypted SOS/report queue | **PII** when decrypted |
| Hive `tickets_v1` | file | Encrypted offline QR tickets | **Bearer** when decrypted |
| Hive `rate_banner_v1` | file | Encrypted dismissal timestamps | Low |
| `SharedPreferencesUserCache` | sharedpref | Last `UserResponse` (name, email, phone, roles) | **PII** |
| `SharedPreferencesOnboardingStore` (`onboarding_seen`) | sharedpref | Onboarding seen flag | Low |
| `SharedPreferencesPayMethodStore` (`pay.default.<userId>`) | sharedpref | Default pay-method id per user | Medium (cross-user leak risk) |
| `SharedPreferencesHomeStore` (`home.*`) | sharedpref | Last-known location, nearby stops, favourite routes | PII |
| `SharedPreferencesSearchHistoryStore` (`search.recent`) | sharedpref | Recent search queries | PII |
| Flutter / plugin internal files | file / root | Dio cache, flutter_map tile cache | Mixed |

Every row above sits under one of the `sharedpref`, `file` or `root`
domains that the exclusion rules below cover.

## What this ship enforces

### `AndroidManifest.xml`

```xml
<application
    …
    android:allowBackup="false"
    android:fullBackupContent="@xml/backup_rules"
    android:dataExtractionRules="@xml/data_extraction_rules">
```

- `android:allowBackup="false"` disables Google Auto Backup for every
  supported Android version. This alone is the primary guard.
- `android:fullBackupContent` targets Android 6–11. Shipped as a belt
  because some OEM paths honor content rules even when auto-backup is
  off.
- `android:dataExtractionRules` targets Android 12+. Has two sections
  — `cloud-backup` and `device-transfer` — both populated with the
  same exclude set. Device-transfer is the critical one: it governs
  OEM migration tools (Google Setup Wizard, Samsung Smart Switch,
  Xiaomi Mi Mover, Huawei Phone Clone) which can move data between
  devices independent of allowBackup.

### `res/xml/backup_rules.xml` (legacy)

Excludes every app-local data domain:

- `root` — the top of the app's data directory
- `file` — `getFilesDir()` (Hive box files land here)
- `database` — SQLite databases (none in TroSky today)
- `sharedpref` — all SharedPreferences files and EncryptedSharedPreferences
- `external` — anything in external storage
- `device_protected_*` — direct-boot encrypted storage (unused today;
  belt rule)

### `res/xml/data_extraction_rules.xml` (Android 12+)

The same exclude list, duplicated in `<cloud-backup>` and
`<device-transfer>`. Google's documentation treats these two sections
as orthogonal; each one must repeat the full exclude set.

## iOS parallel — flutter_secure_storage

Android backup exclusions do not protect iOS. iOS uses iCloud Keychain,
iCloud backup, and encrypted iTunes/Finder backup, each with its own
inclusion policy keyed off Keychain accessibility.

The centralised [`troskySecureStorage`](../../packages/trosky_auth/lib/src/secure_storage.dart)
instance passes:

```dart
iOptions: IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
),
```

The `_ThisDeviceOnly` suffix is the critical bit. Keychain items under
`first_unlock_this_device`:

- Are never included in iCloud Keychain.
- Are never included in an iCloud device backup.
- Are never included in an encrypted iTunes / Finder backup.
- Do not migrate on a device-to-device transfer.

Without the suffix (the plugin's default is plain `first_unlock`), the
refresh token and the Hive AES keys would ride iCloud backups to any
device the Apple ID restores on. Every call site goes through the
shared const, and the CI check asserts no `const FlutterSecureStorage()`
sneaks back in.

## OEM caveats (be honest with the owner)

`allowBackup="false"` and the exclude rules together are the strongest
public guard the app can declare. They are not a cryptographic
guarantee:

- A few OEM migration tools (historically Xiaomi Mi Mover, a couple of
  Huawei flavours) have shipped firmware that ignores
  `device-transfer` rules on certain OS versions.
- Rooted / userdebug devices can read and copy any app's data directly.
- A side-loaded "backup app" with
  `android.permission.BACKUP_AGENT_PERMISSION` could override our
  policy, but that permission is `signatureOrSystem` and unavailable
  to third-party apps.

For the realistic threat model (an everyday user restoring from
Google Drive or switching phones with the stock migration tool), the
C3 policy fully excludes our state.

## Restored ciphertext without a key

If a user **does** end up with Hive box files present on disk without
the matching Keystore / Keychain entry (a backup bug, a restore from
an rooted-device flash, a corrupt uninstall), the following happens:

1. The Hive box files sit in `getApplicationDocumentsDirectory()`.
2. On first access, `troskySecureStorage.read()` returns `null` for
   `trosky.*.hive_key` because the key is not in Keystore.
3. The store generates a fresh 32-byte random AES key and writes it.
4. The old ciphertext boxes fail to decrypt — the stores wrap
   `Hive.openBox` in `try { … } on Object { … }` paths and surface an
   `AsyncError` upstream; the UI treats it as "no cache available"
   and starts clean.
5. On next clean write, the boxes are rewritten under the new key.

The `AndroidOptions(resetOnError: true, migrateWithBackup: false)`
settings on the shared `troskySecureStorage` are what guarantee step
(3). `resetOnError` makes the plugin drop poisoned entries instead of
crashing; `migrateWithBackup: false` tells it to never attempt to
import a prior-install's ciphertext.

## What happens to a user who switches phones legitimately

A user who signs in on phone A, switches to phone B, restores from
their Google backup, opens TroSky:

1. Our data is not in the backup.
2. TroSky launches to the first-time Welcome screen.
3. They sign in (password or OTP) and get a fresh session.
4. Server-side state (bookings, wallet, favourites) is already there.
5. Local-only state (pay-method default, home nearby-stops cache) is
   rebuilt on next use.

No user intervention beyond a sign-in is required. The cost of C3 to
a legitimate restore is "sign in once."

## Coordination with other audit items

- **M4 (prefs wipe on sign-out):** C3 removes the backup-restore
  vector. M4 removes the same-device cross-user vector. Both are
  needed; one does not replace the other.
- **L1 (pending payment/SOS clearance on account change):** C3
  guarantees a backup-restored install starts with no pending items.
  L1 covers the same-device account-switch case, which the backup
  policy does not.

## Verifying on a test device

Rooted or userdebug Android:

```sh
# Confirm the manifest says no
aapt dump xmltree app-release.apk AndroidManifest.xml | grep -E "allowBackup|BackupContent|ExtractionRules"

# Confirm Auto Backup is off for the package
adb shell bmgr enabled
adb shell bmgr list packages | grep com.trosky.app
# -> com.trosky.app  not allowed

# Try to run a backup anyway, inspect the result
adb shell bmgr backupnow com.trosky.app
# -> "Package is not eligible for backup"
```

Device-transfer behavior cannot be exercised from `adb`; it requires
two devices and the vendor migration tool. For the first store build,
run through at least the Google Setup Wizard migration between two
Pixels and visually confirm TroSky launches to the Welcome screen on
the destination.
