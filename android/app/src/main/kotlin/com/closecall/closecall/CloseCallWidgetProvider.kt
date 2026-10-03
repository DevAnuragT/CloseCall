package com.closecall.closecall

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Active timelines override manual home_widget data; missing/expired caches never reuse stale photos.
class CloseCallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        // This reloads truth, reschedules, and renders all installed widget IDs under one lock.
        WidgetTimelineStore.refresh(context)
    }

    companion object {
        internal fun render(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
            for (widgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.closecall_widget)

                val imagePath = widgetData.getString(WidgetTimelineStore.IMAGE_PATH, null)
                val bitmap = imagePath?.let {
                    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeFile(it, bounds)
                    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) null else {
                        // Bound RemoteViews/Binder memory even for a 2048px cached photo.
                        val options = BitmapFactory.Options().apply { inSampleSize = 1 }
                        while (bounds.outWidth / options.inSampleSize > 512 || bounds.outHeight / options.inSampleSize > 512) {
                            options.inSampleSize *= 2
                        }
                        BitmapFactory.decodeFile(it, options)
                    }
                }

                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_image, bitmap)
                    views.setViewVisibility(R.id.widget_image, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_empty, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_image, View.GONE)
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                }

                // Tapping the widget opens the app.
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                views.setOnClickPendingIntent(R.id.widget_image, pendingIntent)
                views.setOnClickPendingIntent(R.id.widget_empty, pendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }
    }
}
