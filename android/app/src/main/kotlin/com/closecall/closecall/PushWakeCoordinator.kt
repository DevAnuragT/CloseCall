package com.closecall.closecall

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.SystemClock

/**
 * Closed-app FCM is only an invalidation hint. This coordinator stores the
 * greatest bounded version and schedules one coalesced native wake. It never
 * stores an FCM token, auth token, payload, or photo bytes.
 */
internal object PushWakeCoordinator {
    const val ACTION_WAKE = "com.closecall.closecall.PUSH_WAKE"
    private const val PREFS = "CloseCallPushWake"
    private const val PENDING = "pending_version"
    private const val APPLIED = "applied_version"
    private const val SEEN = "seen_version"
    private const val MAX_VERSION = 9_000_000_000_000_000L
    private const val REQUEST_CODE = 7822
    private val lock = Any()

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun parseVersion(value: Any?): Long? {
        val parsed = when (value) {
            is Number -> value.toLong().takeIf { value.toDouble() == it.toDouble() }
            is String -> value.toLongOrNull()
            else -> null
        }
        return parsed?.takeIf { it >= 0L && it <= MAX_VERSION }
    }

    /** Returns false for malformed, duplicate, or reordered invalidations. */
    fun accept(context: Context, type: Any?, rawVersion: Any?): Boolean {
        if (type != "invalidation") return false
        val version = parseVersion(rawVersion) ?: return false
        synchronized(lock) {
            val data = prefs(context)
            val pending = data.getLong(PENDING, -1L)
            val applied = data.getLong(APPLIED, -1L)
            val seen = data.getLong(SEEN, -1L)
            val greatest = maxOf(pending, applied, seen)
            if (version <= greatest) return false
            check(data.edit().putLong(PENDING, version).putLong(SEEN, version).commit())
            schedule(context)
            return true
        }
    }

    /**
     * Applies only the native, already-cached timeline. A suspended or invalid
     * identity is handled by WidgetTimelineStore and cannot become authorized
     * because a push was received.
     */
    fun process(context: Context) {
        val version: Long
        synchronized(lock) {
            val data = prefs(context)
            val pending = data.getLong(PENDING, -1L)
            val applied = data.getLong(APPLIED, -1L)
            if (pending < 0L || pending <= applied) {
                cancel(context)
                return
            }
            version = pending
        }

        // Do not let a malformed/corrupt cache create a receiver crash loop.
        try {
            WidgetTimelineStore.refresh(context)
        } catch (_: Exception) {
            // Foreground reconciliation remains authoritative.
        }

        synchronized(lock) {
            val data = prefs(context)
            val newest = data.getLong(PENDING, -1L)
            val applied = data.getLong(APPLIED, -1L)
            val editor = data.edit().putLong(APPLIED, maxOf(applied, version))
            if (newest <= version) editor.remove(PENDING)
            check(editor.commit())
            if (newest > version) schedule(context) else cancel(context)
        }
    }

    /**
     * Identity cleanup removes a queued wake for the previous account/pair.
     * Keep the high-water mark so an old reordered FCM version cannot become a
     * wake for a newly paired identity.
     */
    fun clear(context: Context) = synchronized(lock) {
        check(prefs(context).edit().remove(PENDING).commit())
        cancel(context)
    }

    @androidx.annotation.VisibleForTesting
    fun pendingVersion(context: Context): Long? = prefs(context).getLong(PENDING, -1L)
        .takeIf { it >= 0L }

    @androidx.annotation.VisibleForTesting
    fun appliedVersion(context: Context): Long? = prefs(context).getLong(APPLIED, -1L)
        .coerceAtLeast(prefs(context).getLong(SEEN, -1L))
        .takeIf { it >= 0L }

    @androidx.annotation.VisibleForTesting
    fun resetForTesting(context: Context) = synchronized(lock) {
        check(prefs(context).edit().clear().commit())
        cancel(context)
    }

    private fun alarmIntent(context: Context) = PendingIntent.getBroadcast(
        context,
        REQUEST_CODE,
        Intent(context, PushWakeReceiver::class.java).setAction(ACTION_WAKE),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun schedule(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.setAndAllowWhileIdle(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            SystemClock.elapsedRealtime() + 1L,
            alarmIntent(context),
        )
    }

    private fun cancel(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
            .cancel(alarmIntent(context))
    }
}
