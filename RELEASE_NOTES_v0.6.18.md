# WakeUP-Buddy v0.6.18 — Release Notes (19-10-2026)

### Verified Operational Status: STABLE & WORKING

This release delivers the Map Details & Layers modal sheet, road closure detour routing via TomTom Traffic APIs, custom saved places carousel with interactive pin picker, custom Ola dark vector styling, and phone sensor speed calibration.

---

### Key Fixes & Features in this Release:

1. **Map Viewport Decluttering**:
   - Removed intrusive `● Map Styles v2` and `23 roads blocked` floating badges from both the home and active trip map views.
   - Removed the artificial "Walking" phase chip/label from the HUD speedometer; cleanly displays velocity telemetry with adaptive movement states.

2. **Sensor Speed Calibration (Snail Movement Fix)**:
   - Eliminated artificial cadence speed clamping (`(3.2 + cadence * 0.4).clamp(3.5, 5.5)`) that previously generated false 3–4 km/h spikes from minor phone tilting or slow handling.
   - Added realistic GPS ground-speed deadband filtering ($< 1.2\text{ km/h} \to 0.0\text{ km/h}$) and dynamic stillness gating ($\text{avgDynamic} < 0.25 \to 0.0\text{ km/h}$).

3. **Road Closure Detour Guarantee**:
   - Trip corridors now actively scan for TomTom traffic incidents and road closures within the trip bounding box.
   - Automatic collision check identifies any route polyline passing within 45 meters of an active road closure (e.g., Pappanamcode barricades).
   - In case of collision, the route is disqualified and replaced by an avoid-area detour calculated via TomTom Routing API using `avoidAreas=rect:...` parameters.

4. **Saved Places & Custom Labels Carousel**:
   - Rounded rectangle chips rendered beneath the search capsule: **[🏠 Home] [💼 Work] [🏋️ Gym] [🎓 School] [+ Add Place]**.
   - 1-tap direct route calculation and start trip flow when set.
   - Dual-mode configuration modal:
     - Direct address search with suggestion autocomplete.
     - Full-screen interactive map pin picker (`MapLocationPickerScreen`) with dynamic reverse geocoding and real-time crosshair coordinate tracking.
   - Persisted across app restarts using local storage.

5. **Interactive Map Details & Layers Sheet**:
   - Replaced static text layer banner with an Apple-design / Emil-motion interactive bottom sheet (`MapLayersSheet`).
   - Granular switches for:
     - **Traffic Flow** (Real-time TomTom relative speed vectors)
     - **Road Closures** (Barricades & detour symbols)
     - **Traffic Delays** (Live congestion delay badges)
     - **Incident Markers** (Accidents, hazards, and construction)
     - **Map Theme & Vector Styles** (Light / Dark)
   - Integrated custom Ola Dark Style URL (`https://api.olamaps.io/styleEditor/v1/styleEdit/styles/1a5115aa-26c8-4e8b-8433-0e2858238ca7/Style1-Dark`) dynamically applied across native Ola and Vela map renderers.

6. **Build & Release**:
   - Bumped to version `0.6.18` (build 18).
   - Zero static analysis issues (`flutter analyze` clean).
   - All regression test suites passing.
