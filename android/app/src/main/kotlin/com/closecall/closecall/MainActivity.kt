package com.closecall.closecall

import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Before Flutter restores auth, prevent a wake from applying an old
        // couple's timeline. Fresh owned display may remain during validation.
        WidgetTimelineStore.suspendForStartup(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "closecall/background_reliability")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "status" -> result.success(BackgroundReliability.status(applicationContext))
                        "requestBatteryExemption" -> result.success(BackgroundReliability.requestBatteryExemption(this))
                        "openAutostart" -> result.success(BackgroundReliability.openAutostart(this))
                        else -> result.notImplemented()
                    }
                } catch (failure: Exception) {
                    result.error("background_reliability", "Background settings are unavailable (${failure.javaClass.simpleName})", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "closecall/widget_timeline")
            .setMethodCallHandler { call, result ->
                if (call.method !in setOf("cacheTimeline", "disableTimeline", "clearTimeline", "suspendForStartup", "restoreScope", "recordPhotoOwner", "configureBackgroundServerUrl")) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val receivedWallMs = System.currentTimeMillis()
                val receivedElapsedMs = SystemClock.elapsedRealtime()
                WidgetTimelineStore.executor.execute {
                    try {
                        val response = when (call.method) {
                            "cacheTimeline" -> WidgetTimelineStore.cache(applicationContext, call.arguments, receivedWallMs, receivedElapsedMs)
                            "disableTimeline" -> WidgetTimelineStore.disable(applicationContext)
                            "clearTimeline" -> WidgetTimelineStore.clear(applicationContext)
                            "suspendForStartup" -> WidgetTimelineStore.suspendForStartup(applicationContext)
                            "restoreScope" -> WidgetTimelineStore.restoreScope(applicationContext, call.arguments)
                            "recordPhotoOwner" -> WidgetTimelineStore.recordPhotoOwner(applicationContext, call.arguments)
                            "configureBackgroundServerUrl" -> WidgetBackgroundDelivery.configureServerUrl(applicationContext, call.arguments)
                            else -> null
                        }
                        runOnUiThread { result.success(if (call.method == "restoreScope") response else null) }
                    } catch (failure: Exception) {
                        // Do not echo arguments, scope, or local file paths to logs/errors.
                        runOnUiThread { result.error("widget_timeline", "Native widget timeline operation failed (${failure.javaClass.simpleName})", null) }
                    }
                }
            }
    }
}
