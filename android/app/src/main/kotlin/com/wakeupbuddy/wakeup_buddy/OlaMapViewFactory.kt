package com.wakeupbuddy.wakeup_buddy

import android.content.Context
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class OlaMapViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    @Suppress("UNCHECKED_CAST")
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any>
        return try {
            OlaMapPlatformView(context, messenger, viewId, creationParams)
        } catch (t: Throwable) {
            t.printStackTrace()
            object : PlatformView {
                private val fallback = View(context)
                override fun getView(): View = fallback
                override fun dispose() {}
            }
        }
    }
}
