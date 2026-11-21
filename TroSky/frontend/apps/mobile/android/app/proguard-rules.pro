# TroSky — minimal R8 / ProGuard rules for release builds.
#
# Scope. R8 only shrinks the Java/Kotlin code that ships inside the
# Android app module (the embedding and plugin platform code), never
# Dart code — Dart tree-shaking and obfuscation happen in the Dart VM
# snapshot at compile time via `flutter build … --release --obfuscate
# --split-debug-info=…`. Hive, Dio, Riverpod and go_router are pure
# Dart; they need no Java-side keep rules.
#
# Flutter's Gradle plugin injects its own consumer rules for the engine
# and `GeneratedPluginRegistrant`, so the list here is intentionally
# short. Only add a new rule with a one-line reason explaining the
# reflection/JNI path it protects.

# Keep line numbers in release stack traces (minification still renames
# classes/methods). `retrace`/R8 symbol-maps are preserved via
# `android.buildTypes.release.mappingFileName` by default, so a prod
# crash can be mapped back through the mapping.txt attached to the
# build.
-keepattributes SourceFile,LineNumberTable

# Keep annotations so platform-channel plugins that depend on
# `@Keep`-marked classes survive shrinking.
-keepattributes *Annotation*

# Defensive: keep AndroidX / Flutter `@Keep` and
# `@dalvik.annotation.optimization.FastNative`-annotated members.
-keep,allowobfuscation @interface androidx.annotation.Keep
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep <methods>;
    @androidx.annotation.Keep <fields>;
}

# `url_launcher` and other platform-channel plugins reach the engine
# through the embedding; the default Flutter rules cover them. Nothing
# we ship uses reflection, Gson, Jackson, or JNI from the Java/Kotlin
# side, so there is no extra plugin keep rule here.
