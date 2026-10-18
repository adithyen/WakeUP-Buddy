package com.wakeupbuddy.wakeup_buddy

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.View
import androidx.appcompat.view.ContextThemeWrapper
import com.ola.mapsdk.camera.MapControlSettings
import com.ola.mapsdk.interfaces.OlaMapCallback
import com.ola.mapsdk.model.BorderOptions
import com.ola.mapsdk.model.OlaCircleOptions
import com.ola.mapsdk.model.OlaLatLng
import com.ola.mapsdk.model.OlaMarkerAnchorProperty
import com.ola.mapsdk.model.OlaMarkerOptions
import com.ola.mapsdk.model.OlaPolylineOptions
import com.ola.mapsdk.view.Circle
import com.ola.mapsdk.view.Marker
import com.ola.mapsdk.view.OlaMap
import com.ola.mapsdk.view.OlaMapView
import com.ola.mapsdk.view.Polyline
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import org.maplibre.android.MapLibre

class OlaMapPlatformView(
    private val context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    args: Map<String, Any>?
) : PlatformView, MethodChannel.MethodCallHandler {

    private val methodChannel: MethodChannel = MethodChannel(messenger, "com.wakeupbuddy/ola_map_$viewId")
    private var olaMapView: OlaMapView? = null
    private val fallbackView: View = View(context)
    private var olaMap: OlaMap? = null

    private var destinationMarker: Marker? = null
    private var userMarker: Marker? = null
    private var alertRadiusCircle: Circle? = null
    private var routePolyline: Polyline? = null
    private var pendingUserLocation: Pair<OlaLatLng, String>? = null

    private val defaultApiKey = "CFuHbUzDL9ntSuuVkAg3rowBOA3vf7bhZotfvRdy"

    init {
        methodChannel.setMethodCallHandler(this)

        try {
            MapLibre.getInstance(context.applicationContext)
        } catch (t: Throwable) {
            t.printStackTrace()
        }

        try {
            val themedContext = ContextThemeWrapper(context, R.style.NormalTheme)
            val mapView = OlaMapView(themedContext)
            olaMapView = mapView
            val apiKey = (args?.get("apiKey") as? String)?.takeIf { it.isNotBlank() } ?: defaultApiKey
            val initialLat = (args?.get("initialLat") as? Number)?.toDouble() ?: 8.5241
            val initialLng = (args?.get("initialLng") as? Number)?.toDouble() ?: 76.9366
            val initialZoom = (args?.get("initialZoom") as? Number)?.toDouble() ?: 15.0
            val styleUrl = (args?.get("styleUrl") as? String)?.takeIf { it.isNotBlank() }
                ?: "https://api.olamaps.io/tiles/vector/v1/styles/default-dark-standard/style.json"

            // Pre-set style on internal IMap before getMap() triggers loadMap() (matching Nivara)
            try {
                val mapField = mapView.javaClass.getDeclaredField("map")
                mapField.isAccessible = true
                val iMap = mapField.get(mapView) as? com.ola.mapsdk.interfaces.IMap
                if (!styleUrl.isNullOrEmpty()) {
                    iMap?.setStyle(styleUrl)
                }
            } catch (e: Exception) {
                android.util.Log.w("OlaMapPlatformView", "Could not set initial style: ${e.message}")
            }

            val settings = MapControlSettings.Builder()
                .setZoomGesturesEnabled(true)
                .setScrollGesturesEnabled(true)
                .setRotateGesturesEnabled(true)
                .setDoubleTapGesturesEnabled(true)
                .build()

            mapView.getMap(apiKey, object : OlaMapCallback {
                override fun onMapReady(map: OlaMap) {
                    olaMap = map
                    try {
                        map.showCurrentLocation()
                    } catch (_: Throwable) {}

                    try {
                        map.moveCameraToLatLong(OlaLatLng(initialLat, initialLng), initialZoom, 300)
                    } catch (_: Throwable) {}

                    pendingUserLocation?.let { (pos, color) ->
                        try {
                            val userPin = createPinBitmap(color, isDestination = false)
                            val markerOptions = OlaMarkerOptions.Builder()
                                .setMarkerId("user_marker")
                                .setPosition(pos)
                                .setIconBitmap(userPin)
                                .setIconAnchor(OlaMarkerAnchorProperty.ICON_ANCHOR_CENTER)
                                .build()
                            userMarker = map.addMarker(markerOptions)
                        } catch (t: Throwable) {
                            android.util.Log.e("OlaMapPlatformView", "Failed to add initial user marker: ${t.message}")
                        }
                    }

                    try {
                        mapView.onStart()
                        mapView.onResume()
                    } catch (_: Throwable) {}

                    methodChannel.invokeMethod("onMapReady", null)
                }

                override fun onMapError(error: String) {
                    android.util.Log.e("OlaMapPlatformView", "onMapError: $error")
                    methodChannel.invokeMethod("onMapError", mapOf("error" to error))
                }
            }, settings)

            mapView.post {
                try {
                    mapView.onStart()
                    mapView.onResume()
                } catch (_: Throwable) {}
            }
        } catch (t: Throwable) {
            t.printStackTrace()
            android.util.Log.e("OlaMapPlatformView", "Initialization error: ${t.message}", t)
            olaMapView = null
            methodChannel.invokeMethod("onMapError", mapOf("error" to (t.message ?: "Failed to initialize OlaMapView")))
        }
    }

    override fun getView(): View = olaMapView ?: fallbackView

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        try {
            destinationMarker?.removeMarker()
            destinationMarker = null
            userMarker?.removeMarker()
            userMarker = null
            alertRadiusCircle?.removeCircle()
            alertRadiusCircle = null
            routePolyline?.removePolyline()
            routePolyline = null
            olaMapView?.onDestroy()
            olaMapView = null
        } catch (_: Throwable) {}
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "moveCamera" -> {
                val lat = (call.argument<Number>("lat"))?.toDouble()
                val lng = (call.argument<Number>("lng"))?.toDouble()
                val zoom = (call.argument<Number>("zoom"))?.toDouble() ?: 15.0
                val duration = (call.argument<Number>("duration"))?.toInt() ?: 400

                if (lat != null && lng != null && olaMap != null) {
                    try {
                        olaMap?.moveCameraToLatLong(OlaLatLng(lat, lng), zoom, duration)
                        result.success(true)
                    } catch (e: Throwable) {
                        result.error("CAMERA_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Missing lat/lng or map not ready", null)
                }
            }

            "setDestination" -> {
                val lat = (call.argument<Number>("lat"))?.toDouble()
                val lng = (call.argument<Number>("lng"))?.toDouble()
                val radius = (call.argument<Number>("radiusMeters"))?.toFloat() ?: 500f
                val colorHex = call.argument<String>("colorHex") ?: "#C6FF00"

                if (lat != null && lng != null && olaMap != null) {
                    try {
                        destinationMarker?.removeMarker()
                        alertRadiusCircle?.removeCircle()

                        val pinBitmap = createPinBitmap(colorHex, isDestination = true)
                        val markerOptions = OlaMarkerOptions.Builder()
                            .setMarkerId("destination_marker")
                            .setPosition(OlaLatLng(lat, lng))
                            .setIconBitmap(pinBitmap)
                            .setIconAnchor(OlaMarkerAnchorProperty.ICON_ANCHOR_BOTTOM)
                            .build()
                        destinationMarker = olaMap?.addMarker(markerOptions)

                        val border = BorderOptions.Builder()
                            .setBorderColor(colorHex)
                            .setBorderWidth(2.5f)
                            .build()

                        val circleOptions = OlaCircleOptions.Builder()
                            .setOlaLatLng(OlaLatLng(lat, lng))
                            .setRadius(radius)
                            .setColorHexCode(colorHex)
                            .setCircleOpacity(0.16f)
                            .setBorderOptions(border)
                            .build()
                        alertRadiusCircle = olaMap?.addCircle(circleOptions)

                        result.success(true)
                    } catch (e: Throwable) {
                        result.error("DEST_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Missing lat/lng", null)
                }
            }

            "updateUserLocation" -> {
                val lat = (call.argument<Number>("lat"))?.toDouble()
                val lng = (call.argument<Number>("lng"))?.toDouble()
                val colorHex = call.argument<String>("colorHex") ?: "#2979FF"

                if (lat != null && lng != null) {
                    val pos = OlaLatLng(lat, lng)
                    pendingUserLocation = Pair(pos, colorHex)
                    if (olaMap != null) {
                        try {
                            try {
                                userMarker?.removeMarker()
                            } catch (_: Throwable) {}

                            val userPin = createPinBitmap(colorHex, isDestination = false)
                            val markerOptions = OlaMarkerOptions.Builder()
                                .setMarkerId("user_marker")
                                .setPosition(pos)
                                .setIconBitmap(userPin)
                                .setIconAnchor(OlaMarkerAnchorProperty.ICON_ANCHOR_CENTER)
                                .build()
                            userMarker = olaMap?.addMarker(markerOptions)
                            result.success(true)
                        } catch (e: Throwable) {
                            result.error("USER_POS_ERROR", e.message, null)
                        }
                    } else {
                        // Map is still initializing; pendingUserLocation will be drawn in onMapReady
                        result.success(true)
                    }
                } else {
                    result.error("INVALID_ARGS", "Missing lat/lng", null)
                }
            }

            "drawRoute" -> {
                val rawPoints = call.argument<List<List<Double>>>("points")
                val colorHex = call.argument<String>("colorHex") ?: "#C6FF00"
                val width = (call.argument<Number>("width"))?.toFloat() ?: 6f

                if (rawPoints != null && rawPoints.isNotEmpty() && olaMap != null) {
                    try {
                        routePolyline?.removePolyline()

                        val latLngList = ArrayList<OlaLatLng>(rawPoints.size)
                        for (pt in rawPoints) {
                            if (pt.size >= 2) {
                                latLngList.add(OlaLatLng(pt[0], pt[1]))
                            }
                        }

                        val polylineOptions = OlaPolylineOptions.Builder()
                            .setPolylineId("active_route")
                            .setPoints(latLngList)
                            .setColor(colorHex)
                            .setWidth(width)
                            .build()

                        routePolyline = olaMap?.addPolyline(polylineOptions)
                        result.success(true)
                    } catch (e: Throwable) {
                        result.error("ROUTE_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Missing points", null)
                }
            }

            "fitBounds" -> {
                val rawPoints = call.argument<List<List<Double>>>("points")
                val padding = (call.argument<Number>("padding"))?.toInt() ?: 120

                if (rawPoints != null && rawPoints.isNotEmpty() && olaMap != null) {
                    try {
                        val latLngList = ArrayList<OlaLatLng>(rawPoints.size)
                        for (pt in rawPoints) {
                            if (pt.size >= 2) {
                                latLngList.add(OlaLatLng(pt[0], pt[1]))
                            }
                        }
                        olaMap?.easeCamera(latLngList, padding)
                        result.success(true)
                    } catch (e: Throwable) {
                        result.error("FIT_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Missing points", null)
                }
            }

            "setStyleUrl" -> {
                val newStyleUrl = call.argument<String>("styleUrl") ?: ""
                if (newStyleUrl.isNotEmpty()) {
                    try {
                        val mapField = try {
                            olaMap?.javaClass?.getDeclaredField("map")
                        } catch (_: Exception) {
                            olaMapView?.javaClass?.getDeclaredField("map")
                        }
                        mapField?.isAccessible = true
                        val iMap = (if (olaMap != null) mapField?.get(olaMap) else mapField?.get(olaMapView)) as? com.ola.mapsdk.interfaces.IMap
                        iMap?.setStyle(newStyleUrl)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STYLE_ERROR", e.message, null)
                    }
                } else {
                    result.success(false)
                }
            }

            "clearRoute" -> {
                try {
                    routePolyline?.removePolyline()
                    routePolyline = null
                    result.success(true)
                } catch (e: Throwable) {
                    result.error("CLEAR_ROUTE_ERROR", e.message, null)
                }
            }

            "clearDestination" -> {
                try {
                    destinationMarker?.removeMarker()
                    destinationMarker = null
                    alertRadiusCircle?.removeCircle()
                    alertRadiusCircle = null
                    result.success(true)
                } catch (e: Throwable) {
                    result.error("CLEAR_DEST_ERROR", e.message, null)
                }
            }

            "clearAll" -> {
                try {
                    destinationMarker?.removeMarker()
                    destinationMarker = null
                    userMarker?.removeMarker()
                    userMarker = null
                    alertRadiusCircle?.removeCircle()
                    alertRadiusCircle = null
                    routePolyline?.removePolyline()
                    routePolyline = null
                    result.success(true)
                } catch (e: Throwable) {
                    result.error("CLEAR_ERROR", e.message, null)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun createPinBitmap(colorHex: String, isDestination: Boolean): Bitmap {
        val size = if (isDestination) 140 else 160
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val parsedColor = try {
            Color.parseColor(colorHex)
        } catch (_: Throwable) {
            Color.parseColor("#2979FF")
        }

        val cx = size / 2f

        if (isDestination) {
            // Teardrop Map Pin shape
            val topCy = size * 0.35f
            val radius = size * 0.30f

            paint.color = parsedColor
            paint.style = Paint.Style.FILL
            canvas.drawCircle(cx, topCy, radius, paint)

            // Pin triangle stem pointing downwards to bottom center
            val path = android.graphics.Path()
            path.moveTo(cx - radius * 0.75f, topCy + radius * 0.45f)
            path.lineTo(cx, size.toFloat() - 4f)
            path.lineTo(cx + radius * 0.75f, topCy + radius * 0.45f)
            path.close()
            canvas.drawPath(path, paint)

            // Inner dark contrast ring
            paint.color = Color.BLACK
            paint.alpha = 180
            canvas.drawCircle(cx, topCy, radius * 0.50f, paint)

            // Center solid white dot
            paint.color = Color.WHITE
            paint.alpha = 255
            canvas.drawCircle(cx, topCy, radius * 0.30f, paint)
        } else {
            // High-visibility glowing user location puck
            val cy = size / 2f

            // Outer wide translucent radar ring
            paint.style = Paint.Style.FILL
            paint.color = parsedColor
            paint.alpha = 60
            canvas.drawCircle(cx, cy, size * 0.46f, paint)

            // Mid halo ring
            paint.alpha = 120
            canvas.drawCircle(cx, cy, size * 0.32f, paint)

            // Outer white ring border
            paint.color = Color.WHITE
            paint.alpha = 255
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 8f
            canvas.drawCircle(cx, cy, size * 0.22f, paint)

            // Core solid blue/accent dot
            paint.style = Paint.Style.FILL
            paint.color = parsedColor
            paint.alpha = 255
            canvas.drawCircle(cx, cy, size * 0.22f - 2f, paint)

            // Center bright white pinpoint dot
            paint.color = Color.WHITE
            canvas.drawCircle(cx, cy, size * 0.08f, paint)
        }

        return bitmap
    }
}
