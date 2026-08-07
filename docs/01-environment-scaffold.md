# Phase 01 — Environment & Project Scaffold

> **Goal:** Go from zero to a running Flutter app with branded splash screen, correct project structure, all dependencies declared, and linting configured.  
> **Dependencies:** None  
> **Deliverable:** `flutter run` shows a branded WakeUp Buddy splash → navigates to empty Home Screen shell.

---

## 1.1 — Flutter SDK Installation

### 1.1.1 Install Flutter SDK
- [ ] Download Flutter SDK (latest stable 3.x) from https://docs.flutter.dev/get-started/install/windows
- [ ] Extract to `C:\flutter` (or preferred location)
- [ ] Add `C:\flutter\bin` to system PATH
- [ ] Verify: `flutter --version` shows 3.x.x

### 1.1.2 Install Android Studio / SDK
- [ ] Install Android Studio (latest)
- [ ] Install Android SDK via SDK Manager:
  - Android SDK Platform API 35 (latest)
  - Android SDK Build-Tools 35.x
  - Android SDK Command-line Tools
  - Android Emulator
  - Android SDK Platform-Tools
- [ ] Set `ANDROID_HOME` environment variable
- [ ] Accept licenses: `flutter doctor --android-licenses`

### 1.1.3 Verify Environment
- [ ] Run `flutter doctor -v` — all checks pass (except iOS, which we skip)
- [ ] Ensure connected Android device or emulator is detected: `flutter devices`

### 1.1.4 IDE Setup
- [ ] Install Flutter & Dart extensions in VS Code (or Android Studio plugin)
- [ ] Configure VS Code settings for Flutter:
  ```json
  {
    "dart.flutterSdkPath": "C:\\flutter",
    "editor.formatOnSave": true,
    "dart.lineLength": 100
  }
  ```

---

## 1.2 — Project Creation

### 1.2.1 Create Flutter Project
```bash
cd d:\Projects\WakeUP-Buddy
flutter create --org com.wakeupbuddy --project-name wakeup_buddy --platforms android ./app
```

**Parameters explained:**
| Param | Value | Why |
|-------|-------|-----|
| `--org` | `com.wakeupbuddy` | Android package name prefix |
| `--project-name` | `wakeup_buddy` | Dart package name (snake_case) |
| `--platforms` | `android` | Android only for now |
| `./app` | — | Project lives in `WakeUP-Buddy/app/` |

### 1.2.2 Verify Fresh Build
- [ ] `cd app && flutter run` — default counter app launches on device/emulator
- [ ] `flutter analyze` — zero issues
- [ ] `flutter test` — default test passes

---

## 1.3 — Project Structure Setup

### 1.3.1 Create Feature-First Directory Structure
Create the following directories inside `lib/`:

```
lib/
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   ├── services/
│   └── widgets/
├── features/
│   ├── home/
│   │   ├── presentation/
│   │   │   └── widgets/
│   │   └── providers/
│   ├── destination/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── presentation/
│   │   │   └── widgets/
│   │   └── providers/
│   ├── alert_config/
│   │   ├── data/
│   │   │   └── models/
│   │   ├── presentation/
│   │   │   └── widgets/
│   │   └── providers/
│   ├── tracking/
│   │   ├── data/
│   │   │   └── models/
│   │   ├── services/
│   │   ├── presentation/
│   │   │   └── widgets/
│   │   └── providers/
│   ├── alarm/
│   │   ├── services/
│   │   ├── presentation/
│   │   │   └── widgets/
│   │   └── providers/
│   ├── settings/
│   │   ├── presentation/
│   │   └── providers/
│   └── history/
│       ├── data/
│       │   └── models/
│       ├── presentation/
│       │   └── widgets/
│       └── providers/
└── background/
```

### 1.3.2 Create Placeholder Files
Create `.gitkeep` or placeholder Dart files in each directory to establish structure:
- `lib/core/constants/app_constants.dart` — empty class
- `lib/core/utils/logger.dart` — simple print wrapper
- `lib/features/home/presentation/home_screen.dart` — Scaffold with "WakeUp Buddy" title

---

## 1.4 — Dependencies (pubspec.yaml)

### 1.4.1 Core Dependencies
Add all dependencies that will be used across phases. This prevents version conflicts later.

```yaml
name: wakeup_buddy
description: A smart location-based alarm for commuters
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Map & Location
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  geolocator: ^13.0.1
  geocoding: ^3.0.0

  # HTTP & API
  dio: ^5.7.0

  # Permissions
  permission_handler: ^11.3.1

  # Background Service
  flutter_foreground_task: ^8.10.0

  # Alarm & Audio
  alarm: ^4.1.0
  just_audio: ^0.9.40
  vibration: ^2.0.0

  # Storage
  hive: ^4.0.0
  hive_flutter: ^1.1.0
  shared_preferences: ^2.3.2

  # UI Utilities
  google_fonts: ^6.2.1
  flutter_animate: ^4.5.0
  shimmer: ^3.0.0
  gap: ^3.0.1
  flutter_svg: ^2.0.10+1

  # Utilities
  uuid: ^4.4.2
  intl: ^0.19.0
  path_provider: ^2.1.4
  file_picker: ^8.1.2       # For custom alarm sound import

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.12
  hive_generator: ^2.0.1
  mocktail: ^1.0.4
  integration_test:
    sdk: flutter
```

### 1.4.2 Install Dependencies
```bash
flutter pub get
```

### 1.4.3 Verify No Conflicts
```bash
flutter pub outdated
flutter analyze
```

---

## 1.5 — Android Configuration

### 1.5.1 Update `android/app/build.gradle`
```groovy
android {
    namespace "com.wakeupbuddy.wakeup_buddy"
    compileSdk 35  // or flutter.compileSdkVersion

    defaultConfig {
        applicationId "com.wakeupbuddy.wakeup_buddy"
        minSdk 29       // Android 10
        targetSdk 35
        versionCode 1
        versionName "1.0.0"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug  // Temp for dev
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

### 1.5.2 Update `android/app/src/main/AndroidManifest.xml`
Add all permissions that will be needed (even if features come later):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Location Permissions -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>

    <!-- Foreground Service -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>

    <!-- Alarm & Wake -->
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <!-- Audio -->
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>

    <!-- Battery -->
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>

    <!-- Internet (for map tiles & API) -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

    <application
        android:label="WakeUp Buddy"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:enableOnBackInvokedCallback="true">

        <!-- Main Activity -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize"
            android:showWhenLocked="true"
            android:turnScreenOn="true">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme"/>
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <!-- Foreground Service (for flutter_foreground_task) -->
        <service
            android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
            android:foregroundServiceType="location"
            android:exported="false"/>

        <!-- Alarm Service (for alarm package) -->
        <!-- Will be configured by the alarm package automatically -->

    </application>
</manifest>
```

### 1.5.3 Update `android/build.gradle` (project-level)
Ensure Kotlin and Gradle versions are compatible:
```groovy
buildscript {
    ext.kotlin_version = '1.9.22'
    // ...
}
```

---

## 1.6 — App Entry Point & Routing Shell

### 1.6.1 `lib/main.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode (optimal for one-hand use)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize Hive for local storage
  await Hive.initFlutter();

  runApp(
    const ProviderScope(
      child: WakeUpBuddyApp(),
    ),
  );
}
```

### 1.6.2 `lib/app.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/home/presentation/home_screen.dart';

class WakeUpBuddyApp extends ConsumerWidget {
  const WakeUpBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'WakeUp Buddy',
      debugShowCheckedModeBanner: false,
      // Theme will be set up in Phase 02
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
```

### 1.6.3 `lib/features/home/presentation/home_screen.dart`
```dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.alarm_on,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'WakeUp Buddy',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Phase 01 Complete ✓',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 1.7 — Linting & Code Quality

### 1.7.1 `analysis_options.yaml`
```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  errors:
    invalid_annotation_target: ignore
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_locals
    - sort_constructors_first
    - sort_unnamed_constructors_first
    - use_key_in_widget_constructors
    - avoid_print
    - require_trailing_commas
```

### 1.7.2 `.gitignore`
Ensure Flutter-specific ignores are in place:
```
# Flutter/Dart
.dart_tool/
.packages
build/
*.iml
.idea/
.vscode/
*.lock    # Keep pubspec.lock for apps (remove this line)

# Android
android/.gradle
android/local.properties
android/captures/
android/gradlew
android/gradlew.bat
android/**/GeneratedPluginRegistrant.java

# Environment
.env
*.env.local
```

---

## 1.8 — Assets Directory

### 1.8.1 Create Asset Directories
```
app/assets/
├── sounds/          # Alarm sounds (Phase 06)
├── images/          # App images & markers (Phase 02, 04)
│   ├── markers/
│   └── onboarding/
└── fonts/           # If bundling fonts (usually Google Fonts is dynamic)
```

### 1.8.2 Register in `pubspec.yaml`
```yaml
flutter:
  uses-material-design: true

  assets:
    - assets/sounds/
    - assets/images/
    - assets/images/markers/
```

---

## 1.9 — Git Initialization

### 1.9.1 Initialize Repository
```bash
cd d:\Projects\WakeUP-Buddy\app
git init
git add .
git commit -m "chore: Phase 01 — Project scaffold with dependencies and structure"
```

### 1.9.2 Branch Strategy
```
main          ← stable releases
├── develop   ← integration branch
│   ├── feature/phase-01-scaffold
│   ├── feature/phase-02-design-system
│   ├── feature/phase-03-permissions
│   └── ...
```

---

## ✅ Phase 01 — Acceptance Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| 1 | Flutter SDK installed and in PATH | `flutter --version` returns 3.x.x |
| 2 | Android SDK configured | `flutter doctor` shows no Android issues |
| 3 | Project builds without errors | `flutter build apk --debug` succeeds |
| 4 | App launches on device/emulator | `flutter run` shows home screen |
| 5 | All dependencies resolve | `flutter pub get` exits cleanly |
| 6 | Linting passes | `flutter analyze` returns zero issues |
| 7 | Directory structure exists | All directories from 1.3.1 present |
| 8 | Default test passes | `flutter test` exits with 0 failures |

---

## ⚠️ Common Pitfalls

| Issue | Solution |
|-------|----------|
| `flutter` not found after install | Restart terminal; verify PATH includes `C:\flutter\bin` |
| Gradle build fails with JDK error | Install JDK 17; set `JAVA_HOME` |
| `minSdk` version conflict | Ensure ALL dependency `build.gradle` files use `minSdk 29` |
| Dependency version conflicts | Run `flutter pub outdated` and pin compatible versions |
| Android license not accepted | Run `flutter doctor --android-licenses` and accept all |
