package com.wakeupbuddy.wakeup_buddy

import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import org.maplibre.android.MapLibre

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            MapLibre.getInstance(applicationContext)
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            flutterEngine
                .platformViewsController
                .registry
                .registerViewFactory(
                    "ola_native_map_view",
                    OlaMapViewFactory(flutterEngine.dartExecutor.binaryMessenger)
                )
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }
}
