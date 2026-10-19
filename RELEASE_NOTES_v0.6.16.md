# WakeUP-Buddy v0.6.16 — Rollback Point Checkpoint (18-10-2026)

### Verified Operational Status: STABLE & WORKING

This release serves as a comprehensive rollback point containing all fixes, architectural enhancements, sensor fusion updates, and map renderer integrations finalized on **October 18, 2026**.

---

### Key Fixes & Features in this Release:

1. **Persistent Search Suggestion Cleanup**:
   - Switched `destinationSearchProvider` to `StateNotifierProvider.autoDispose` so search state cleanly unmounts upon screen exit.
   - Introduced monotonic `_currentRequestId` tokens and query validation to strictly discard delayed in-flight API responses.
   - Gated suggestions rendering so that an empty search query instantly displays the pristine initial state.

2. **Native Ola Maps SDK Integration**:
   - Native integration with `OlaMapSdk-1.8.5.aar` via Android PlatformView (`OlaMapPlatformView.kt`).
   - Smooth vector rendering without raster tile distortion, pixelation, or blurry zoom artifacts.
   - Fixed `pendingUserLocation` caching so the user location pin renders immediately when the native map view initializes.

3. **High-Visibility Location Pin & Recenter Functionality**:
   - Modern multi-ring pulsing radar halo beacon with 8px white border and vibrant blue core.
   - Fixed the Recenter / My Location button to immediately pan and center camera on user location across all 3 map renderers.

4. **Multi-Map Renderer Architecture**:
   - Clean runtime switching in Settings between:
     - **Ola Maps** (Native Vector SDK)
     - **Vela Maps** (MapLibre Native Vector)
     - **OpenStreetMap** (Standard Raster Tiles)
   - Fully decoupled implementations with zero cross-contamination.

5. **Realistic Road Distance & Duration Metrics**:
   - Integrated single-call batch **Ola Maps Distance Matrix API** in `OlaPlacesRepository`.
   - Replaced mathematical Euclidean lat-lng approximations with authentic by-road travel times and real road distance.

6. **Recent Places Panel Polish**:
   - Automatic place deduplication.
   - Dynamic, compact card height that scales to content instead of occupying a fixed 1/4 screen.

7. **Sensor Fusion for Real-World Transit**:
   - Built universal accelerometer step cadence and variance filtering in `SensorSpeedService`.
   - Accurately differentiates **Walking** (>0.85 m/s² step impact peaks), **Slow Traffic**, **Transit**, and **Stationary** states on physical devices.

8. **Navigation & Dynamic Rerouting**:
   - Active route polyline stays intact throughout trip navigation and cleanly tears down on back/cancel.
   - Robust off-route detection (<65m perpendicular distance threshold) with automatic dynamic ETA and route updates.
