package com.wakeupbuddy.wakeup_buddy

import android.content.Context
import android.util.Log
import android.view.View
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.sources.GeoJsonSource

/** A small, keyless MapLibre/OpenFreeMap view following Vela's basemap model. */
class VelaMapPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    args: Map<String, Any>?
) : PlatformView, MethodChannel.MethodCallHandler {
    private val mapView = MapView(context)
    private val channel = MethodChannel(messenger, "com.wakeupbuddy/vela_map_$viewId")
    private val initialLat = (args?.get("initialLat") as? Number)?.toDouble() ?: 8.5241
    private val initialLng = (args?.get("initialLng") as? Number)?.toDouble() ?: 76.9366
    private val initialZoom = (args?.get("initialZoom") as? Number)?.toDouble() ?: 15.0
    private val styleUrl = (args?.get("styleUrl") as? String)
        ?.takeIf { it.isNotBlank() }
        ?: "https://tiles.openfreemap.org/styles/liberty"
    private var map: org.maplibre.android.maps.MapLibreMap? = null
    private var style: Style? = null
    private var userPoint: LatLng? = null
    private var destinationPoint: LatLng? = null
    private var routePoints: List<LatLng> = emptyList()
    private var accentColor = "#C6FF00"

    init {
        mapView.onCreate(null)
        channel.setMethodCallHandler(this)
        mapView.getMapAsync { mapInstance ->
            map = mapInstance
            mapInstance.setCameraPosition(
                CameraPosition.Builder()
                    .target(LatLng(initialLat, initialLng))
                    .zoom(initialZoom)
                    .build()
            )
            mapInstance.setStyle(
                Style.Builder().fromUri(styleUrl),
                object : Style.OnStyleLoaded {
                    override fun onStyleLoaded(style: Style) {
                        this@VelaMapPlatformView.style = style
                        renderOverlays()
                        Log.i("VelaMapPlatformView", "OpenFreeMap style loaded")
                    }
                }
            )
        }
    }

    override fun getView(): View = mapView

    override fun dispose() {
        channel.setMethodCallHandler(null)
        mapView.onPause()
        mapView.onStop()
        mapView.onDestroy()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "moveCamera" -> {
                val lat = call.argument<Number>("lat")?.toDouble()
                val lng = call.argument<Number>("lng")?.toDouble()
                val zoom = call.argument<Number>("zoom")?.toDouble() ?: 15.0
                if (lat == null || lng == null) return result.error("INVALID_ARGS", "Missing lat/lng", null)
                map?.animateCamera(CameraUpdateFactory.newLatLngZoom(LatLng(lat, lng), zoom))
                result.success(true)
            }
            "updateUserLocation" -> {
                userPoint = point(call) ?: return result.error("INVALID_ARGS", "Missing lat/lng", null)
                accentColor = call.argument<String>("colorHex") ?: accentColor
                renderOverlays(); result.success(true)
            }
            "setDestination" -> {
                destinationPoint = point(call) ?: return result.error("INVALID_ARGS", "Missing lat/lng", null)
                accentColor = call.argument<String>("colorHex") ?: accentColor
                renderOverlays(); result.success(true)
            }
            "drawRoute" -> {
                val raw = call.argument<List<List<Number>>>("points") ?: emptyList()
                routePoints = raw.mapNotNull { if (it.size >= 2) LatLng(it[0].toDouble(), it[1].toDouble()) else null }
                accentColor = call.argument<String>("colorHex") ?: accentColor
                renderOverlays(); result.success(true)
            }
            "fitBounds" -> {
                val bounds = routePointsBounds(call.argument<List<List<Number>>>("points"))
                if (bounds != null) map?.animateCamera(CameraUpdateFactory.newLatLngBounds(bounds, call.argument<Number>("padding")?.toInt() ?: 120))
                result.success(true)
            }
            "clearRoute" -> {
                routePoints = emptyList()
                renderOverlays()
                result.success(true)
            }
            "clearDestination" -> {
                destinationPoint = null
                renderOverlays()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun point(call: MethodCall): LatLng? = LatLng(
        call.argument<Number>("lat")?.toDouble() ?: return null,
        call.argument<Number>("lng")?.toDouble() ?: return null,
    )

    private fun routePointsBounds(raw: List<List<Number>>?): LatLngBounds? {
        val points = raw.orEmpty().mapNotNull { if (it.size >= 2) LatLng(it[0].toDouble(), it[1].toDouble()) else null }
        if (points.isEmpty()) return null
        val builder = LatLngBounds.Builder()
        points.forEach(builder::include)
        return builder.build()
    }

    private fun featureCollection(geometry: JsonObject): String {
        val feature = JsonObject().apply { addProperty("type", "Feature"); add("geometry", geometry) }
        return JsonObject().apply {
            addProperty("type", "FeatureCollection")
            add("features", JsonArray().apply { add(feature) })
        }.toString()
    }

    private fun renderOverlays() {
        val currentStyle = style ?: return
        currentStyle.removeLayer("vela-route")
        currentStyle.removeLayer("vela-user")
        currentStyle.removeLayer("vela-destination")
        currentStyle.removeSource("vela-route-source")
        currentStyle.removeSource("vela-user-source")
        currentStyle.removeSource("vela-destination-source")

        if (routePoints.size > 1) {
            val coords = JsonArray().apply { routePoints.forEach { add(JsonArray().apply { add(it.longitude); add(it.latitude) }) } }
            val geometry = JsonObject().apply { addProperty("type", "LineString"); add("coordinates", coords) }
            currentStyle.addSource(GeoJsonSource("vela-route-source", featureCollection(geometry)))
            currentStyle.addLayer(LineLayer("vela-route", "vela-route-source").withProperties(
                PropertyFactory.lineColor(accentColor), PropertyFactory.lineWidth(6f), PropertyFactory.lineCap("round"), PropertyFactory.lineJoin("round")
            ))
        }
        addPointLayer(currentStyle, "vela-user", "vela-user-source", userPoint, 7f)
        addPointLayer(currentStyle, "vela-destination", "vela-destination-source", destinationPoint, 10f)
    }

    private fun addPointLayer(style: Style, layerId: String, sourceId: String, point: LatLng?, radius: Float) {
        if (point == null) return
        val geometry = JsonObject().apply {
            addProperty("type", "Point")
            add("coordinates", JsonArray().apply { add(point.longitude); add(point.latitude) })
        }
        style.addSource(GeoJsonSource(sourceId, featureCollection(geometry)))
        style.addLayer(CircleLayer(layerId, sourceId).withProperties(
            PropertyFactory.circleColor(accentColor), PropertyFactory.circleRadius(radius), PropertyFactory.circleStrokeColor("#FFFFFF"), PropertyFactory.circleStrokeWidth(2f)
        ))
    }
}
