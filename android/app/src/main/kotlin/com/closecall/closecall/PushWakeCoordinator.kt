package com.closecall.closecall

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import java.util.concurrent.Executors

/**
 * Closed-app FCM carries only an invalidation hint. This coordinator stores
 * the greatest bounded version and schedules one coalesced native wake. The
 * wake obtains its separate device capability from secure storage and never
 * stores an FCM token, user-session token, payload, or photo bytes.
 */
internal object PushWakeCoordinator {
    const val ACTION_WAKE = "com.closecall.closecall.PUSH_WAKE"
    private const val PREFS = "CloseCallPushWake"
    private const val PENDING = "pending_version"
    private const val APPLIED = "applied_version"
    private const val SEEN = "seen_version"
    private const val RETRIES = "background_retries"
    private const val MAX_VERSION = 9_000_000_000_000_000L
    private const val MAX_RETRIES = 3
    private const val WATCHDOG_MS = 15_000L
    private const val REQUEST_CODE = 7822
    private val lock = Any()
    val executor = Executors.newSingleThreadExecutor()

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
            check(data.edit().putLong(PENDING, version).putLong(SEEN, version)
                .putInt(RETRIES, 0).commit())
            schedule(context)
            return true
        }
    }

    /**
     * Fetches current authorized state, then applies it through the serialized
     * native timeline store. A suspended or invalid identity cannot become
     * authorized because a push was received.
     */
    fun process(context: Context) {
        val version: Long
        val attempt: Int
        synchronized(lock) {
            val data = prefs(context)
            val pending = data.getLong(PENDING, -1L)
            val applied = data.getLong(APPLIED, -1L)
            if (pending < 0L || pending <= applied) {
                cancel(context)
                return
            }
            version = pending
            // Counted up front: a run frozen by the OS never reaches the end.
            attempt = data.getInt(RETRIES, 0) + 1
            if (attempt > MAX_RETRIES) {
                check(data.edit().putLong(APPLIED, maxOf(applied, version))
                    .remove(PENDING).remove(RETRIES).commit())
                cancel(context)
                return
            }
            check(data.edit().putInt(RETRIES, attempt).commit())
        }

        // Vendor task freezers can stop this process mid-fetch. Arm a retry
        // first; every outcome below replaces or cancels it.
        schedule(context, WATCHDOG_MS)

        var completed = false
        try {
            when (WidgetBackgroundDelivery.reconcile(context)) {
                WidgetBackgroundDelivery.Result.APPLIED,
                WidgetBackgroundDelivery.Result.NO_AUTHORITY -> completed = true
                WidgetBackgroundDelivery.Result.RETRY -> Unit
            }
        } catch (_: Exception) {
            // A malformed/corrupt response must not create a receiver crash loop.
        }
        try {
            // Preserve the prior cached-transition behavior even when this
            // wake has no usable background authority or the network failed.
            WidgetTimelineStore.runSerialized { WidgetTimelineStore.refresh(context) }
        } catch (_: Exception) {
            // Foreground reconciliation remains authoritative for bad cache data.
        }

        synchronized(lock) {
            val data = prefs(context)
            val newest = data.getLong(PENDING, -1L)
            val highestApplied = data.getLong(APPLIED, -1L)
            if (newest > version) {
                schedule(context)
            } else if (completed) {
                val editor = data.edit().putLong(APPLIED, maxOf(highestApplied, version))
                    .remove(PENDING).remove(RETRIES)
                check(editor.commit())
                cancel(context)
            } else {
                if (attempt >= MAX_RETRIES) {
                    check(data.edit().putLong(APPLIED, maxOf(highestApplied, version))
                        .remove(PENDING).remove(RETRIES).commit())
                    cancel(context)
                } else {
                    schedule(context, 30_000L)
                }
            }
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

    private fun schedule(context: Context, delayMs: Long = 1L) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.setAndAllowWhileIdle(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            SystemClock.elapsedRealtime() + delayMs.coerceAtLeast(1L),
            alarmIntent(context),
        )
    }

    private fun cancel(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
            .cancel(alarmIntent(context))
    }
}
