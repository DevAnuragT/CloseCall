package com.closecall.closecall

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.BitmapFactory
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Renders the couple's current photo on the home screen. Reads the image path
/// written from Dart via `HomeWidget.saveWidgetData('widget_image_path', ...)`.
class CloseCallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.closecall_widget)

            val imagePath = widgetData.getString("widget_image_path", null)
            val bitmap = imagePath?.let { BitmapFactory.decodeFile(it) }

            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_image, bitmap)
                views.setViewVisibility(R.id.widget_image, View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_image, View.GONE)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            }

            // Tapping the widget opens the app.
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
            )
            views.setOnClickPendingIntent(R.id.widget_image, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_empty, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
