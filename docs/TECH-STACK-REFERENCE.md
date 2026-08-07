# 📦 WakeUp Buddy — Technical Stack Reference

> Quick reference for all packages, APIs, and tools used in the project.

---

## Flutter Packages (pubspec.yaml)

### Core Framework
| Package | Version | Purpose | Phase |
|---------|---------|---------|-------|
| `flutter` | SDK | Framework | P01 |
| `flutter_riverpod` | ^2.5.1 | State management + DI | P01 |
| `riverpod_annotation` | ^2.3.5 | Code generation for providers | P01 |
| `riverpod_generator` | ^2.4.3 | Code gen (dev) | P01 |
| `build_runner` | ^2.4.12 | Code gen runner (dev) | P01 |

### Maps & Location
| Package | Version | Purpose | Phase |
|---------|---------|---------|-------|
| `flutter_map` | ^7.0.2 | Map widget (raster tiles) | P04 |
| `latlong2` | ^0.9.1 | LatLng data type | P04 |
| `geolocator` | ^13.0.1 | GPS location tracking | P04, P07 |
| `geocoding` | ^3.0.0 | Address ↔ coordinates | P05 |

### HTTP & Networking
| Package | Version | Purpose | Phase |
|---------|---------|---------|-------|
| `dio` | ^5.7.0 | HTTP client (Ola Maps API) | P05 |

### Permissions
| Package | Version | Purpose | Phase |
|---------|---------|---------|-------|
| `permission_handler` | ^11.3.1 | Runtime permission requests | P03 |

### Background Service
| Package | Version | Purpose | Phase |
|---------|---------|---------|-------|
| `flutter_foreground_task` | ^8.10.0 | Foreground service + background isolate | P07 |

### Alarm & Audio
| Package | Version | Purpose | Phase |
|---------|---------|---------|-------|
| `alarm` | ^4.1.0 | Alarm over lock screen, audio playback | P08 |
| `just_audio` | ^0.9.40 | Sound preview playback | P06 |
| `vibration` | ^2.0.0 | Vibration patterns | P08 |

### Local Storage
| Package | Version | Purpose | Phase |
|---------|---------|---------|-------|
| `hive` | ^4.0.0 | NoSQL local database | P06, P11 |
| `hive_flutter` | ^1.1.0 | Hive Flutter integration | P06, P11 |
| `hive_generator` | ^2.0.1 | Hive type adapter gen (dev) | P06, P11 |
| `shared_preferences` | ^2.3.2 | Simple key-value storage | P02, P06 |

### UI & Design
| Package | Version | Purpose | Phase |
|---------|---------|---------|-------|
| `google_fonts` | ^6.2.1 | Inter font (dynamic load) | P02 |
| `flutter_animate` | ^4.5.0 | Declarative animations | P02 |
| `shimmer` | ^3.0.0 | Loading shimmer effect | P02 |
| `gap` | ^3.0.1 | SizedBox shorthand | P02 |
| `flutter_svg` | ^2.0.10+1 | SVG rendering | P02 |

### Utilities
| Package | Version | Purpose | Phase |
|---------|---------|---------|-------|
| `uuid` | ^4.4.2 | Unique ID generation | P05 |
| `intl` | ^0.19.0 | Date/time formatting | P09, P11 |
| `path_provider` | ^2.1.4 | App directory paths | P06 |
| `file_picker` | ^8.1.2 | Custom sound file import | P06 |

### Testing
| Package | Version | Purpose | Phase |
|---------|---------|---------|-------|
| `flutter_test` | SDK | Widget testing | All |
| `flutter_lints` | ^4.0.0 | Code linting | All |
| `mocktail` | ^1.0.4 | Mock objects for tests | All |
| `integration_test` | SDK | Integration testing | P12 |

### Release Tools
| Package | Version | Purpose | Phase |
|---------|---------|---------|-------|
| `flutter_launcher_icons` | ^0.14.1 | App icon generation (dev) | P12 |
| `flutter_native_splash` | ^2.4.0 | Splash screen generation (dev) | P12 |

---

## External APIs

### Ola Maps API
| Endpoint | Purpose | Phase |
|----------|---------|-------|
| `places/v1/autocomplete` | Destination search | P05 |
| `places/v1/reverse-geocode` | Address from coordinates | P05 |
| `tiles/v1/styles/default-light-standard/{z}/{x}/{y}.png` | Light map tiles | P04 |
| `tiles/v1/styles/default-dark-standard/{z}/{x}/{y}.png` | Dark map tiles | P04 |
| `routing/v1/directions` | Route display (future) | — |

**Base URL:** `https://api.olamaps.io`  
**Auth:** API key as query parameter (`?api_key=YOUR_KEY`)  
**Free tier:** ~5M calls/month  

### Fallback APIs (No Key Required)
| Service | Endpoint | Purpose |
|---------|----------|---------|
| OpenStreetMap Tiles | `tile.openstreetmap.org/{z}/{x}/{y}.png` | Fallback map tiles |
| CartoDB Dark Tiles | `cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png` | Dark fallback tiles |
| Nominatim Search | `nominatim.openstreetmap.org/search` | Fallback geocoding |
| Nominatim Reverse | `nominatim.openstreetmap.org/reverse` | Fallback reverse geocode |

---

## Android Configuration

### Permissions (AndroidManifest.xml)
| Permission | Type | Purpose |
|------------|------|---------|
| `ACCESS_FINE_LOCATION` | Runtime | GPS tracking |
| `ACCESS_COARSE_LOCATION` | Runtime | Fallback location |
| `ACCESS_BACKGROUND_LOCATION` | Runtime | Background tracking |
| `FOREGROUND_SERVICE` | Manifest | Keep-alive service |
| `FOREGROUND_SERVICE_LOCATION` | Manifest | Service type (API 34+) |
| `POST_NOTIFICATIONS` | Runtime (API 33+) | Service notification |
| `WAKE_LOCK` | Manifest | Screen wake for alarm |
| `VIBRATE` | Manifest | Vibration alert |
| `USE_FULL_SCREEN_INTENT` | Runtime (API 34+) | Alarm over lock screen |
| `SCHEDULE_EXACT_ALARM` | Runtime (API 31+) | Precise alarm |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Runtime | Battery bypass |
| `INTERNET` | Manifest | API/tile access |
| `ACCESS_NETWORK_STATE` | Manifest | Network check |
| `MODIFY_AUDIO_SETTINGS` | Manifest | Alarm volume |

### Build Configuration
| Setting | Value |
|---------|-------|
| `minSdk` | 29 (Android 10) |
| `targetSdk` | 35 |
| `compileSdk` | 35 |
| `applicationId` | `com.wakeupbuddy.wakeup_buddy` |
| `foregroundServiceType` | `location` |

---

## Architecture Patterns

| Pattern | Usage |
|---------|-------|
| **Feature-first folders** | Each feature is a self-contained module |
| **Repository pattern** | Data access abstracted behind interfaces |
| **Riverpod providers** | State management + dependency injection |
| **Background isolate** | GPS tracking in separate isolate |
| **Strategy pattern** | Ola Maps vs OSM tile providers |
| **Composite pattern** | Combined Ola + Nominatim search |
| **Observer pattern** | App lifecycle + permission changes |
