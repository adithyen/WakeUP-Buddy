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
