import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared [FlutterSecureStorage] instance used by every TroSky store
/// that holds secrets or an encryption key. Centralising the options
/// here is a C3 hardening: the Android and iOS defaults differ in
/// backup-inclusion behaviour, and a drift in one call site leaks
/// secrets through iCloud or Google Drive.
///
/// - Android: the ciphertext lives under the app's `sharedpref`
///   domain, excluded from Auto Backup and Device Transfer by
///   `res/xml/backup_rules.xml` and
///   `res/xml/data_extraction_rules.xml`. `migrateWithBackup` is
///   kept false so the plugin never attempts to copy ciphertext
///   across a restored install — the Keystore master key is
///   non-exportable, and a restored ciphertext without its matching
///   Keystore entry decodes to garbage. `resetOnError` is true so
///   clients that read a garbage value see a null and fall through
///   to a fresh initialisation (fresh Hive AES key, fresh refresh
///   token, sign-in prompt).
/// - iOS: Keychain with accessibility
///   `KeychainAccessibility.first_unlock_this_device`. The
///   `_ThisDeviceOnly` suffix is the critical bit — Keychain items
///   under it are excluded from iCloud Keychain, iCloud backup, and
///   encrypted iTunes/Finder backups. The default `first_unlock`
///   accessibility class (without `_ThisDeviceOnly`) migrates
///   through iCloud backups, which is the C3 ship-blocker on iOS.
const FlutterSecureStorage troskySecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    resetOnError: true,
    migrateWithBackup: false,
  ),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
