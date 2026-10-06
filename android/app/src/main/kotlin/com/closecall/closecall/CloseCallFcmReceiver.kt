package com.closecall.closecall

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
/**
 * Observes the Firebase delivery broadcast without replacing FlutterFire's
 * messaging service. Only the opaque invalidation type/version are inspected;
 * no message data is logged or forwarded to native storage.
 */
class CloseCallFcmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.google.android.c2dm.intent.RECEIVE") return
        // FCM normally initializes Firebase before delivery. Resolving the
        // messaging singleton here makes that closed-app path explicit and
        // idempotent.
        try {
            // firebase_messaging keeps its Firebase SDK dependency
            // implementation-scoped. Resolve the already-installed SDK rather
            // than adding a second native dependency to the app.
            Class.forName("com.google.firebase.messaging.FirebaseMessaging")
                .getMethod("getInstance")
                .invoke(null)
        } catch (_: Exception) {
            // A delivery hint must not crash the receiver or expose config.
        }
        val type = intent.extras?.get("type")
        val version = intent.extras?.get("version")
        PushWakeCoordinator.accept(context.applicationContext, type, version)
    }
}
