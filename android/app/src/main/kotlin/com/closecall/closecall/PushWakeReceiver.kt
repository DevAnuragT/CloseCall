package com.closecall.closecall

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Native executor for the bounded, unique push wake alarm. */
class PushWakeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != PushWakeCoordinator.ACTION_WAKE) return
        val pending = goAsync()
        WidgetTimelineStore.executor.execute {
            try {
                PushWakeCoordinator.process(context.applicationContext)
            } finally {
                pending.finish()
            }
        }
    }
}
