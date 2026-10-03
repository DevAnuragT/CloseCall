package com.closecall.closecall

import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "closecall/widget_timeline")
            .setMethodCallHandler { call, result ->
                if (call.method !in setOf("cacheTimeline", "disableTimeline", "clearTimeline")) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val receivedWallMs = System.currentTimeMillis()
                val receivedElapsedMs = SystemClock.elapsedRealtime()
                WidgetTimelineStore.executor.execute {
                    try {
                        when (call.method) {
                            "cacheTimeline" -> WidgetTimelineStore.cache(applicationContext, call.arguments, receivedWallMs, receivedElapsedMs)
                            "disableTimeline" -> WidgetTimelineStore.disable(applicationContext)
                            "clearTimeline" -> WidgetTimelineStore.clear(applicationContext)
                        }
                        runOnUiThread { result.success(null) }
                    } catch (failure: Exception) {
                        // Do not echo arguments, scope, or local file paths to logs/errors.
                        runOnUiThread { result.error("widget_timeline", "Native widget timeline operation failed (${failure.javaClass.simpleName})", null) }
                    }
                }
            }
    }
}
