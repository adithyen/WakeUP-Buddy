# OLA Maps API Reference

Stored locally for offline reference. All endpoints use base URL: `https://api.olamaps.io`

## Authentication
All API calls require `api_key` query parameter:  
`?api_key=YOUR_KEY`

---

## Map Tiles

| Style | URL Pattern |
|---|---|
| Custom Dark (Style1-Dark) | `/tiles/v1/styles/Style1-Dark/tiles/{z}/{x}/{y}.png?api_key=KEY` |
| Default Light | `/tiles/v1/styles/default-light/tiles/{z}/{x}/{y}.png?api_key=KEY` |
| Default Dark | `/tiles/v1/styles/default-dark/tiles/{z}/{x}/{y}.png?api_key=KEY` |

---

## Places APIs

### Autocomplete
```
GET /places/v1/autocomplete?input=query&location=lat,lng&api_key=KEY
```
Returns suggestions with `place_id`, `description`, `structured_formatting`.

### Place Details
```
GET /places/v1/details?place_id=ID&api_key=KEY
```
Returns `geometry.location.lat/lng`, `name`, `formatted_address`, `types`.

### Reverse Geocode
```
GET /places/v1/reverse-geocode?latlng=lat,lng&api_key=KEY
```
Returns `results[].formatted_address`, `results[].place_id`.

### Nearby Search
```
GET /places/v1/nearbysearch?location=lat,lng&radius=500&type=restaurant&api_key=KEY
```

---

## Routing APIs

### Directions API (POST)
```
POST /routing/v1/directions?api_key=KEY
Body: {
  "origin": "lat,lng",
  "destination": "lat,lng",
  "alternatives": true,
  "steps": true,
  "overview": "full",
  "language": "en"
}
```
Returns `routes[]` with:
- `legs[].distance.value` — metres
- `legs[].duration.value` — seconds
- `overview_polyline.points` — encoded polyline
- `legs[].steps[]` — turn-by-turn instructions

### Distance Matrix API (GET)
```
GET /routing/v1/distanceMatrix?origins=lat,lng&destinations=lat,lng&api_key=KEY
```
Returns `rows[].elements[].distance.value` and `duration.value`.

### Route Optimizer API
```
POST /routing/v1/routeOptimizer
Body: { trips: [...], vehicles: [...] }
```

---

## Roads APIs

### Snap to Road
```
GET /roads/v1/snapToRoads?path=lat,lng|lat,lng&interpolate=true&api_key=KEY
```

### Nearest Roads
```
GET /roads/v1/nearestRoads?points=lat,lng&api_key=KEY
```

### Speed Limits
```
GET /roads/v1/speedLimits?path=lat,lng|lat,lng&api_key=KEY
```

---

## Polyline Encoding
Ola Maps uses **Google Encoded Polyline** format (same as Google Maps).
Decode with: `flutter_polyline_points` package → `PolylinePoints().decodePolyline(encoded)`.

---

## Style Editor
Custom map styles created at: https://maps.olakrutrim.com/style-editor
Export style ID from URL — use as style name in tile URL.
