# WakeUp Buddy Native Platform Views
-keep class com.wakeupbuddy.wakeup_buddy.** { *; }
-dontwarn com.wakeupbuddy.wakeup_buddy.**

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Flutter Foreground Task
-keep class com.pravera.flutter_foreground_task.** { *; }

# Alarm package
-keep class com.gdelataillade.alarm.** { *; }

# Hive (no ISAR used – plain Hive)
-keep class com.hivedb.** { *; }
-keepclassmembers class * {
    @com.hivedb.** <fields>;
}

# Keep all model classes used in Hive boxes (JSON serialization)
-keepattributes Signature
-keepattributes *Annotation*

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Google Play Core (Flutter Deferred Components Optional Dependency)
-dontwarn com.google.android.play.core.**

# MapLibre GL
-keep class org.maplibre.android.** { *; }
-dontwarn org.maplibre.android.**
-keep class org.maplibre.gl.** { *; }

# Ola Maps SDK & Places SDK
-keep class com.ola.mapsdk.** { *; }
-dontwarn com.ola.mapsdk.**
-keep class com.ola.places.** { *; }
-dontwarn com.ola.places.**
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**

