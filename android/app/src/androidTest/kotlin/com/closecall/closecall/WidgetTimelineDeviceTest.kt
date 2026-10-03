package com.closecall.closecall

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID

/** Exercises persisted Android cache/receivers without launching a Flutter activity. */
@RunWith(AndroidJUnit4::class)
class WidgetTimelineDeviceTest {
    private val context: Context = InstrumentationRegistry.getInstrumentation().targetContext
    private val fallback = UUID.randomUUID().toString()
    private val surprise = UUID.randomUUID().toString()
    private val schedule = UUID.randomUUID().toString()
    private val fallbackBytes = png(0xff112233.toInt())
    private val surpriseBytes = png(0xffcc8844.toInt())
    private fun prefs() = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    private fun path(): String? = prefs().getString(WidgetTimelineStore.IMAGE_PATH, null)
    private fun png(color: Int): ByteArray {
        val bitmap = Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(color)
        return ByteArrayOutputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            bitmap.recycle()
            it.toByteArray()
        }
    }
    private fun payload(now: Long, until: Long = now + 60_000) = mapOf(
        "scope" to "test-account:1/test-couple/paired",
        "serverTimeMs" to now,
        "fallbackAssetId" to fallback,
        "schedules" to listOf(mapOf(
            "scheduleId" to schedule, "assetId" to surprise,
            "activeFromMs" to now - 1000, "activeUntilMs" to until,
            "createdAtMs" to now - 2000,
        )),
        "photos" to mapOf(fallback to fallbackBytes, surprise to surpriseBytes),
    )
    private fun cache(value: Map<String, Any>) {
        WidgetTimelineStore.cache(context, value, System.currentTimeMillis(), SystemClock.elapsedRealtime())
    }
    @Before fun setup() = WidgetTimelineStore.clear(context)
    @After fun cleanup() = WidgetTimelineStore.clear(context)

    @Test fun persistedTimelineRevertsThroughReceiverWithoutFlutter() {
        val now = System.currentTimeMillis()
        cache(payload(now, now + 300))
        assertArrayEquals(surpriseBytes, File(path()!!).readBytes())
        Thread.sleep(350)
        context.sendBroadcast(Intent(context, WidgetTimelineReceiver::class.java)
            .setAction("com.closecall.closecall.TIMELINE_WAKE"))
        val deadline = SystemClock.elapsedRealtime() + 5000
        while (SystemClock.elapsedRealtime() < deadline) {
            val file = path()?.let(::File)
            if (file?.isFile == true && file.readBytes().contentEquals(fallbackBytes)) return
            Thread.sleep(25)
        }
        fail("Native receiver did not apply cached fallback")
    }

    @Test fun disableRetainsManualPhotoAndClearDeletesPrivateCache() {
        cache(payload(System.currentTimeMillis()))
        WidgetTimelineStore.disable(context)
        val retained = File(path()!!)
        assertArrayEquals(surpriseBytes, retained.readBytes())
        WidgetTimelineStore.refresh(context)
        assertArrayEquals(surpriseBytes, File(path()!!).readBytes())
        WidgetTimelineStore.clear(context)
        assertNull(path())
        assertFalse(retained.exists())
        assertFalse(File(context.noBackupFilesDir, "widget_timeline").exists())
    }

    @Test fun invalidReplacementPreservesCommittedGeneration() {
        val now = System.currentTimeMillis()
        cache(payload(now))
        val previous = path()
        val invalid = payload(now).toMutableMap()
        invalid["photos"] = mapOf(surprise to byteArrayOf(1, 2, 3))
        try {
            cache(invalid)
            fail("Malformed image accepted")
        } catch (_: IllegalArgumentException) { }
        assertEquals(previous, path())
        assertArrayEquals(surpriseBytes, File(path()!!).readBytes())
    }

    @Test fun expiredPersistedCacheFailsClosed() {
        cache(payload(System.currentTimeMillis()))
        val pointer = File(context.noBackupFilesDir, "widget_timeline/active.json")
        val json = JSONObject(pointer.readText())
        json.put("receivedServerTimeMs", json.getLong("serverTimeMs") - WidgetTimelinePolicy.TTL_MS - 1)
        pointer.writeText(json.toString())
        WidgetTimelineStore.refresh(context)
        assertNull(path())
        assertFalse(pointer.exists())
    }
}
