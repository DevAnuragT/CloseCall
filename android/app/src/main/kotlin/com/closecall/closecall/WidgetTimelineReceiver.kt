package com.closecall.closecall

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Manifest receiver works without a Flutter engine. Alarms deliberately aren't exact. */
class WidgetTimelineReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        WidgetTimelineStore.executor.execute {
            try {
                WidgetTimelineStore.refresh(context.applicationContext,
                    if (intent.action == "com.closecall.closecall.TIMELINE_WAKE") intent.getStringExtra("generation") else null)
            } finally { pending.finish() }
        }
    }
}
