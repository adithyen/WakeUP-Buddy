# Ola Maps (Krutrim Cloud) Comprehensive API & SDK Integration Guide

This guide documents the full suite of Ola Maps endpoints, SDK architectures, request/response models, and verified integration patterns for the WakeUp-Buddy project.

---

## 1. Authentication & Base URLs

- **Base URL**: `https://api.olamaps.io`
- **Default Hardcoded API Key**: `CFuHbUzDL9ntSuuVkAg3rowBOA3vf7bhZotfvRdy`
- **Query Parameter Auth**: `?api_key={API_KEY}`
- **Header Auth**: `X-Request-Id` (optional tracing), `User-Agent: WakeUpBuddy/1.0`

---

## 2. Routing APIs

### 2.1 Directions API (Turn-by-Turn Routing & Polyline)
- **Endpoint**: `POST https://api.olamaps.io/routing/v1/directions`
- **Query Parameters**:
  - `origin`: `{latitude},{longitude}` (e.g. `12.9314,77.6164`)
  - `destination`: `{latitude},{longitude}` (e.g. `12.9716,77.5946`)
  - `alternatives`: `true | false` (enables multi-route selection before trip start)
  - `steps`: `true` (enables step-by-step navigation instructions)
  - `overview`: `full | simplified`
  - `api_key`: Active API key
- **Response Structure**:
  - `status`: `"SUCCESS"`
  - `routes[]`:
    - `summary`: High-level route name
    - `overview_polyline`: Encoded polyline string (Google Encoded Polyline format)
    - `legs[]`:
      - `distance`: Total meters (e.g. `8170` = 8.17 km)
      - `duration`: Total duration in seconds (e.g. `1803` = ~30 mins)
      - `steps[]`:
        - `instructions`: Maneuver instruction (e.g. `"Turn left onto Hosur Road"`)
        - `maneuver`: `"turn-left"`, `"turn-right"`, `"continue"`, `"arrive"`
        - `distance`: Segment distance in meters
        - `duration`: Segment duration in seconds
        - `start_location`: `{"lat": ..., "lng": ...}`
        - `end_location`: `{"lat": ..., "lng": ...}`

### 2.2 Directions Basic API
- **Endpoint**: `POST https://api.olamaps.io/routing/v1/directions/basic`
- **Purpose**: Static fast-path routing without real-time congestion overlays. Ideal for low-latency background distance estimates.

### 2.3 Distance Matrix API (Instant Matrix ETAs)
- **Endpoint**: `GET https://api.olamaps.io/routing/v1/distanceMatrix`
- **Query Parameters**:
  - `origins`: `{lat},{lng}` or pipe-separated multiple origins
  - `destinations`: `{lat},{lng}` or pipe-separated multiple destinations
  - `api_key`: Active API key
- **Verified Response**:
  ```json
  {
    "status": "SUCCESS",
    "rows": [{
      "elements": [{
        "status": "OK",
        "distance": 8170,
        "duration": 1803,
        "polyline": "..."
      }]
    }]
  }
  ```
- **Use Case**: Instantly computes distance (km) and live ETA (min) for all search suggestions and recent places relative to user location.

### 2.4 Route Optimizer & Fleet Planner APIs
- **Route Optimizer**: `POST https://api.olamaps.io/routing/v1/routeOptimizer` (TSP optimization for multi-stop commutes)
- **Fleet Planner**: `POST https://api.olamaps.io/routing/v1/fleetPlanner` (Fleet multi-vehicle vehicle routing)

---

## 3. Roads APIs

### 3.1 Snap to Road API
- **Endpoint**: `GET https://api.olamaps.io/routing/v1/snapToRoad`
- **Query Parameters**: `points={lat1},{lng1}|{lat2},{lng2}&api_key={KEY}`
- **Purpose**: Snaps raw GPS traces onto legitimate road geometry, smoothing GPS drift and eliminating out-of-lane jitter.

### 3.2 Nearest Roads API
- **Endpoint**: `GET https://api.olamaps.io/routing/v1/nearestRoads`
- **Query Parameters**: `points={lat},{lng}&api_key={KEY}`
- **Verified Response**:
  ```json
  {
    "status": "SUCCESS",
    "results": [{
      "lat": 12.931502,
      "lng": 77.616340,
      "distance": 13.08,
      "snap_type": "OLAMAPS",
      "status": "SUCCESS"
    }]
  }
  ```
- **Use Case**: Accurately pinpoints the commuter on the exact road segment when starting a trip or checking diversion.

### 3.3 Speed Limits API
- **Endpoint**: `GET https://api.olamaps.io/roads/v1/speedLimits`
- **Query Parameters**: `path={lat},{lng}|...&api_key={KEY}`
- **Purpose**: Provides official speed limit thresholds for road segments.

---

## 4. Places APIs

### 4.1 Autocomplete API
- **Endpoint**: `GET https://api.olamaps.io/places/v1/autocomplete`
- **Query Parameters**:
  - `input`: Search query string (e.g. `"sree"`, `"kims"`, `"lulu"`)
  - `location`: Bias search to commuter's current location (`{lat},{lng}`)
  - `radius`: Bias radius in meters (e.g. `50000`)
  - `api_key`: Active API key
- **Verified Response**:
  - `predictions[]`:
    - `place_id`: Unique identifier (e.g. `"ola-platform:5000064981943"`)
    - `description`: Full human-readable address
    - `structured_formatting`:
      - `main_text`: Prominent title (e.g. `"Sree Padmanabhaswamy Temple"`)
      - `secondary_text`: Subtitle / locality / city (e.g. `"Fort, Pazhavangadi, Thiruvananthapuram"`)
    - `types`: List of category tokens (e.g. `["hospital"]`, `["restaurant"]`, `["school"]`, `["university"]`, `["hindu_temple"]`)
    - `geometry.location`: `{"lat": ..., "lng": ...}`

### 4.2 Place Details & Advanced Details API
- **Endpoint**: `GET https://api.olamaps.io/places/v1/details`
- **Query Parameters**: `place_id={PLACE_ID}&api_key={KEY}`
- **Verified Response**: Contains full `formatted_address`, `address_components`, viewport bounding box, category metadata, and exact pin coordinates.

### 4.3 Nearby Search & Advanced Nearby Search
- **Endpoint**: `GET https://api.olamaps.io/places/v1/nearbysearch`
- **Query Parameters**: `location={lat},{lng}&types={type}&radius={meters}&api_key={KEY}`
- **Purpose**: Finds nearby transit hubs, bus stations, metro stations, colleges, and hospitals around the user.

---

## 5. Geocoding APIs

### 5.1 Forward Geocoding API
- **Endpoint**: `GET https://api.olamaps.io/places/v1/geocode`
- **Query Parameters**: `address={QUERY}&api_key={KEY}`

### 5.2 Reverse Geocoding API
- **Endpoint**: `GET https://api.olamaps.io/places/v1/reverse-geocode`
- **Query Parameters**: `latlng={lat},{lng}&api_key={KEY}`
- **Verified Response**: Converts raw GPS coordinates into structured neighborhood, street name, and city name (e.g. `"Thachottukavu, Thiruvananthapuram"`).

---

## 6. Map Tiles (Vector & Static)

### 6.1 Vector Map Tiles (MapLibre Standard)
- **Style JSON Endpoint**:
  `https://api.olamaps.io/tiles/vector/v1/styles/{styleName}/style.json?api_key={KEY}`
- **Verified Standard Styles**:
  - `default-dark-standard`: Native dark vector theme with subtle roads, building footprints, and high-contrast labels. Matches the `Designs/` theme precisely!
  - `default-light-standard`: High-contrast day vector theme.
  - `default-dark-standard-satellite`: Satellite imagery layer.
- **Vector PBF Tiles**:
  `https://api.olamaps.io/tiles/vector/v1/data/planet/{z}/{x}/{y}.pbf`
- **Why Vector Tiles Solve the Zoom Issue**:
  Vector tiles ship geometric road vectors, polygons, and text labels rather than baked PNG images. When zooming in, roads and text dynamically re-render at crisp 60fps native resolution without stretching or pixelation.

### 6.2 Custom Style Editor ("Style1-Dark")
- Created via the Ola Maps Krutrim Console Style Editor.
- When published in the console, custom styles are referenced by their published style URL or Style ID.
- The app supports a configurable Custom Style URL field in Settings, gracefully falling back to `default-dark-standard` if not published or if offline.

### 6.3 Static Map Tiles
- **Endpoint**: `https://api.olamaps.io/tiles/v1/styles/{style}/static/{lng},{lat},{zoom}/{width}x{height}.png?api_key={KEY}`
- **Purpose**: Lightweight static snapshot generation for trip summary receipts and notification cards.

---

## 7. Native Android SDKs vs. REST Engine Architecture

| SDK / Component | File | Role & Assessment |
| :--- | :--- | :--- |
| `OlaMapSdk-1.8.4.aar` | `lib/OlaMapSdk-1.8.4.aar` | Android native library wrapping MapLibre GL v11. Requires `org.maplibre.gl:android-plugin-annotation-v9:3.0.2` for `BubbleLayout`. |
| `OlaMapNavigationSDK-1.0.242.aar` | `lib/OlaMapNavigationSDK-1.0.242.aar` | Android native turn-by-turn navigation engine. |
| `Places-sdk-2.4.0.jar` | `lib/Places-sdk-2.4.0.jar` | Android native wrapper for Places REST API. |
| **Flutter MapLibre Vector + REST Engine** | Pure Dart + `maplibre_gl` | **Optimal Architecture**: Consumes Ola vector styles directly, eliminating Android PlatformView rendering overhead, avoiding Gradle symbol linkage conflicts, and enabling seamless Flutter UI overlays (speedometer HUD, bottom sheet). |
