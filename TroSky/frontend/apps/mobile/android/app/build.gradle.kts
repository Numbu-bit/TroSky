import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// `flutter build apk -P demo=true` makes "TroSky Demo" (com.trosky.app.demo),
// which installs next to TroSky: for mock-mode builds shown without a server
// (env/README.md).
val demo = project.findProperty("demo") == "true"

// Load android/key.properties (gitignored) when present. Store, alias and
// key passwords all come from this file; see android/key.properties.example
// and android/SIGNING.md. Debug builds do not need it.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val keystorePropertiesPresent = keystorePropertiesFile.exists()
if (keystorePropertiesPresent) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun keystoreProp(key: String): String? {
    val value = keystoreProperties.getProperty(key)
    return if (value.isNullOrBlank()) null else value
}

// The release build type is routed to this config when it is fully set up.
// If any value is missing we deliberately leave `signingConfigs.release`
// absent so a release build fails loudly at task execution — never silently
// falling back to the debug keystore (step 21/B, C1 hardening).
val uploadStoreFile = keystoreProp("storeFile")?.let { rootProject.file(it) }
val uploadStorePassword = keystoreProp("storePassword")
val uploadKeyAlias = keystoreProp("keyAlias")
val uploadKeyPassword = keystoreProp("keyPassword")
val uploadSigningReady =
    uploadStoreFile != null &&
        uploadStoreFile.exists() &&
        uploadStorePassword != null &&
        uploadKeyAlias != null &&
        uploadKeyPassword != null

// Each store build matches exactly one applicationId. Store (Play / App
// Store) uploads must never ship with the demo id, and demo builds must
// never ship with the store id.
val storeApplicationId = "com.trosky.app"
val demoApplicationId = "com.trosky.app.demo"

android {
    namespace = "com.trosky.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = if (demo) demoApplicationId else storeApplicationId
        manifestPlaceholders["appLabel"] = if (demo) "TroSky Demo" else "TroSky"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (uploadSigningReady) {
            create("release") {
                storeFile = uploadStoreFile
                storePassword = uploadStorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Never fall back to the debug keystore for release. The
            // upload signing config is only wired when every value in
            // android/key.properties is present (and the keystore file
            // resolves); otherwise the release build fails at task time
            // with a clear message.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// A release build without a wired upload signing config must fail before
// Gradle packages the APK/AAB with the Android default debug key. The
// check is wired as a dependency of assembleRelease and bundleRelease so
// it runs on both AAB and APK paths.
val verifyReleaseSigningReady by tasks.registering {
    group = "verification"
    description = "Fails a release build if android/key.properties is missing or incomplete."
    doFirst {
        if (!uploadSigningReady) {
            val reason = buildString {
                append("Release signing config not available. Expected android/key.properties")
                append(" with storeFile, storePassword, keyAlias and keyPassword, and the")
                append(" keystore file to resolve. See apps/mobile/android/SIGNING.md.")
                if (!keystorePropertiesPresent) {
                    append("\n  - android/key.properties was not found at ")
                    append(keystorePropertiesFile.absolutePath)
                }
                if (uploadStoreFile != null && !uploadStoreFile.exists()) {
                    append("\n  - storeFile did not resolve: ")
                    append(uploadStoreFile.absolutePath)
                }
            }
            throw GradleException(reason)
        }
    }
}

tasks.matching {
    it.name == "assembleRelease" || it.name == "bundleRelease"
}.configureEach {
    dependsOn(verifyReleaseSigningReady)
}

// Store builds must use the store application id, never the demo id. The
// --release build type gate avoids tripping during debug.
val verifyStoreApplicationId by tasks.registering {
    group = "verification"
    description = "Fails a store release build if the applicationId is not $storeApplicationId."
    doFirst {
        val effective = android.defaultConfig.applicationId
        if (demo) {
            throw GradleException(
                "Store release built with demo=true (applicationId=$effective). Drop -Pdemo for a store build."
            )
        }
        if (effective != storeApplicationId) {
            throw GradleException(
                "Store release built with applicationId=$effective; expected $storeApplicationId."
            )
        }
    }
}

tasks.matching {
    it.name == "assembleRelease" || it.name == "bundleRelease"
}.configureEach {
    dependsOn(verifyStoreApplicationId)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
