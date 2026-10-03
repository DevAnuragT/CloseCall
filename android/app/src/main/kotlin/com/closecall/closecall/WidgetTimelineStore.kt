package com.closecall.closecall

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.SystemClock
import android.provider.Settings
import android.system.Os
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import java.util.concurrent.Executors

/** All native mutations and rendering share this lock; a wake cannot publish an old generation. */
internal object WidgetTimelineStore {
    val lock = Any()
    val executor = Executors.newSingleThreadExecutor()
    private const val ENABLED = "closecall_timeline_enabled"
    const val IMAGE_PATH = "widget_image_path"
    private const val ALARM_ACTION = "com.closecall.closecall.TIMELINE_WAKE"

    private data class State(
        val generation: String,
        val scope: String,
        val anchor: WidgetClockAnchor,
        val fallback: String?,
        val schedules: List<WidgetSchedule>,
        val photos: Map<String, String>,
    )

    // Offline photos and opt-in metadata must not participate in Android's cloud/device backup.
    private fun root(context: Context) = File(context.noBackupFilesDir, "widget_timeline")
    private fun pointer(context: Context) = AtomicFile(File(root(context), "active.json"))
    private fun prefs(context: Context) = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    private fun boot(context: Context): Int = Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)
    private fun name() = UUID.randomUUID().toString()

    fun cache(context: Context, arguments: Any?, receivedWallMs: Long, receivedElapsedMs: Long) = synchronized(lock) {
        val input = arguments as? Map<*, *> ?: throw IllegalArgumentException("Expected map")
        val scope = input["scope"] as? String ?: throw IllegalArgumentException("Missing scope")
        val serverTime = WidgetTimelinePolicy.time(input["serverTimeMs"])
        // Capture at receipt, not after image I/O.
        val anchor = WidgetClockAnchor(serverTime, receivedWallMs, receivedElapsedMs, boot(context))
        val fallback = input["fallbackAssetId"]?.let(WidgetTimelinePolicy::id)
        val rawSchedules = input["schedules"] as? List<*> ?: throw IllegalArgumentException("Missing schedules")
        require(rawSchedules.size <= 100)
        val schedules = rawSchedules.map {
            val row = it as? Map<*, *> ?: throw IllegalArgumentException("Invalid schedule")
            WidgetSchedule(WidgetTimelinePolicy.id(row["scheduleId"]), WidgetTimelinePolicy.id(row["assetId"]),
                WidgetTimelinePolicy.time(row["activeFromMs"]), WidgetTimelinePolicy.time(row["activeUntilMs"]),
                WidgetTimelinePolicy.time(row["createdAtMs"]),
                WidgetTimelinePolicy.creationTime(row["createdAtUs"], WidgetTimelinePolicy.time(row["createdAtMs"])))
        }
        val rawPhotos = input["photos"] as? Map<*, *> ?: throw IllegalArgumentException("Missing photos")
        require(rawPhotos.size <= 12)
        val photos = rawPhotos.entries.associate { WidgetTimelinePolicy.id(it.key) to
            (it.value as? ByteArray ?: throw IllegalArgumentException("Expected photo bytes")) }
        require(photos.size == rawPhotos.size) { "Duplicate normalized asset ID" }
        WidgetTimelinePolicy.validate(scope, serverTime, schedules, photos)
        photos.values.forEach { bytes ->
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            WidgetTimelinePolicy.validateDimensions(bounds.outWidth, bounds.outHeight)
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                ?: throw IllegalArgumentException("Invalid image")
            bitmap.recycle()
        }

        val directory = root(context).apply { mkdirs() }
        val previous = if (prefs(context).getBoolean(ENABLED, false)) read(context) else null
        cleanup(context, previous?.generation)
        val reusable = photos.mapNotNull { (id, bytes) ->
            val existing = previous?.let { photo(context, it, id) }
            if (existing != null && existing.readBytes().contentEquals(bytes)) id to existing else null
        }.toMap()
        // The old generation must survive failed publication. Enforce quota even during staging.
        val existingBytes = directory.walkTopDown().filter { it.isFile && it.extension == "photo" }.sumOf { it.length() }
        val additionalBytes = photos.filterKeys { it !in reusable }.values.sumOf { it.size.toLong() }
        require(existingBytes + additionalBytes <= WidgetTimelinePolicy.MAX_TOTAL_BYTES) {
            "Insufficient private cache quota for atomic replacement"
        }
        val generation = name()
        val stage = File(directory, generation).apply { check(mkdir()) }
        var exposed = false
        try {
            val names = photos.mapValues { (id, bytes) ->
                val filename = "${name()}.photo"
                val destination = File(stage, filename)
                // Immutable identical photos share disk blocks during atomic replacement. Removing
                // the previous generation after publication doesn't invalidate the new hard link.
                val existing = reusable[id]
                if (existing != null) Os.link(existing.absolutePath, destination.absolutePath)
                else FileOutputStream(destination).use { it.write(bytes); it.fd.sync() }
                filename
            }
            val state = State(generation, scope, anchor, fallback, schedules, names)
            val json = encode(state).toString().toByteArray(Charsets.UTF_8)
            FileOutputStream(File(stage, "timeline.json")).use { it.write(json); it.fd.sync() }
            writePointer(context, json)
            exposed = true
            check(prefs(context).edit().putBoolean(ENABLED, true).commit())
            refreshLocked(context, null)
            cleanup(context, generation)
        } finally {
            if (!exposed) stage.deleteRecursively()
        }
    }

    fun disable(context: Context) = synchronized(lock) {
        cancel(context)
        // If a scheduled file is currently displayed, detach it from the disposable generation.
        val data = prefs(context)
        val current = data.getString(IMAGE_PATH, null)?.let(::File)
        val directory = root(context)
        if (current != null && isInside(current, directory) && current.isFile) {
            val retained = File(directory, "${name()}.photo")
            // Rename is atomic and uses no extra photo quota.
            check(current.renameTo(retained)) { "Cannot retain displayed photo" }
            check(data.edit().putString(IMAGE_PATH, retained.absolutePath).putBoolean(ENABLED, false).commit())
        } else {
            check(data.edit().putBoolean(ENABLED, false).commit())
        }
        pointer(context).delete()
        cleanup(context, null)
    }

    fun clear(context: Context) = synchronized(lock) { clearLocked(context); renderLocked(context) }

    private fun clearLocked(context: Context) {
        cancel(context)
        check(prefs(context).edit().remove(IMAGE_PATH).putBoolean(ENABLED, false).commit())
        pointer(context).delete()
        val directory = root(context)
        if (directory.exists() && !directory.deleteRecursively()) {
            // Fail explicitly, but don't leave the old photo on the home screen on a disk error.
            renderLocked(context)
            error("Cannot delete private widget cache")
        }
    }

    /** Also called by widget updates, boot, package replacement, and clock broadcasts. */
    fun refresh(context: Context, expectedGeneration: String? = null) = synchronized(lock) {
        refreshLocked(context, expectedGeneration)
    }

    private fun refreshLocked(context: Context, expectedGeneration: String?) {
        if (!prefs(context).getBoolean(ENABLED, false)) {
            cancel(context)
            // A persisted tombstone wins even if the process died before deleting the pointer.
            pointer(context).delete()
            cleanup(context, null)
            renderLocked(context)
            return
        }
        var state = read(context)
        if (expectedGeneration != null && state != null && state.generation != expectedGeneration) return
        if (state == null) {
            cancel(context)
            if (prefs(context).getBoolean(ENABLED, false) || pointer(context).baseFile.exists()) clearLocked(context)
            renderLocked(context)
            return
        }
        val wallNow = System.currentTimeMillis()
        val elapsedNow = SystemClock.elapsedRealtime()
        val bootNow = boot(context)
        val now = state.anchor.now(wallNow, elapsedNow, bootNow)
        if (state.anchor.expired(now)) {
            clearLocked(context)
            renderLocked(context)
            return
        }
        if (bootNow >= 0 && state.anchor.bootCount != bootNow) {
            // Re-establish monotonic truth for this boot without renewing the original 24h TTL.
            state = state.copy(anchor = state.anchor.reanchor(wallNow, elapsedNow, bootNow))
            writePointer(context, encode(state).toString().toByteArray(Charsets.UTF_8))
        }
        val resolved = WidgetTimelineResolver.cachedAsset(state.schedules, state.fallback, now, state.photos.keys)
        // Never fall through to the previous/manual preference when an active cache misses.
        val image = photo(context, state, resolved) ?: photo(context, state, state.fallback)
        check(prefs(context).edit().putString(IMAGE_PATH, image?.absolutePath).putBoolean(ENABLED, true).commit())
        renderLocked(context)
        val next = WidgetTimelineResolver.nextBoundary(state.schedules, state.fallback, now, state.anchor.expiresAtMs)
        arm(context, state.generation, next - now)
        cleanup(context, state.generation)
    }

    private fun photo(context: Context, state: State, id: String?): File? {
        val filename = state.photos[id] ?: return null
        val file = File(File(root(context), state.generation), filename)
        if (!file.isFile || file.length() !in 1..WidgetTimelinePolicy.MAX_PHOTO_BYTES.toLong()) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        if (bounds.outWidth !in 1..2048 || bounds.outHeight !in 1..2048) return null
        val options = BitmapFactory.Options().apply { inSampleSize = 1 }
        while (bounds.outWidth / options.inSampleSize > 512 || bounds.outHeight / options.inSampleSize > 512) options.inSampleSize *= 2
        val decoded = BitmapFactory.decodeFile(file.absolutePath, options) ?: return null
        decoded.recycle()
        return file
    }

    private fun read(context: Context): State? = try {
        val atomic = pointer(context)
        if (!atomic.baseFile.exists() && !File(atomic.baseFile.path + ".bak").exists()) null else {
            val bytes = atomic.openRead().use { stream ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(4096)
                while (true) {
                    val count = stream.read(buffer)
                    if (count < 0) break
                    require(output.size() + count <= 128 * 1024)
                    output.write(buffer, 0, count)
                }
                val data = output.toByteArray()
                require(data.size <= 128 * 1024)
                data
            }
            val json = JSONObject(String(bytes, Charsets.UTF_8))
            val schedulesJson = json.getJSONArray("schedules")
            require(schedulesJson.length() <= 100)
            val schedules = (0 until schedulesJson.length()).map { index ->
                val row = schedulesJson.getJSONObject(index)
                WidgetSchedule(WidgetTimelinePolicy.id(row.getString("scheduleId")), WidgetTimelinePolicy.id(row.getString("assetId")),
                    WidgetTimelinePolicy.time(row.getLong("activeFromMs")), WidgetTimelinePolicy.time(row.getLong("activeUntilMs")),
                    WidgetTimelinePolicy.time(row.getLong("createdAtMs")),
                    WidgetTimelinePolicy.creationTime(if (row.has("createdAtUs")) row.getLong("createdAtUs") else null,
                        WidgetTimelinePolicy.time(row.getLong("createdAtMs"))))
            }
            val photoJson = json.getJSONObject("photos")
            require(photoJson.length() <= 12)
            val photos = photoJson.keys().asSequence().associate { key ->
                val filename = photoJson.getString(key)
                require(filename.endsWith(".photo"))
                WidgetTimelinePolicy.id(filename.removeSuffix(".photo"))
                WidgetTimelinePolicy.id(key) to filename
            }
            require(photos.size == photoJson.length())
            val serverTime = WidgetTimelinePolicy.time(json.getLong("serverTimeMs"))
            val receivedTime = WidgetTimelinePolicy.time(json.getLong("receivedServerTimeMs"))
            require(receivedTime <= serverTime)
            val scope = json.getString("scope")
            WidgetTimelinePolicy.validate(scope, serverTime, schedules, emptyMap())
            State(WidgetTimelinePolicy.id(json.getString("generation")), scope,
                WidgetClockAnchor(serverTime, WidgetTimelinePolicy.time(json.getLong("wallTimeMs")),
                    json.getLong("elapsedMs").also { require(it >= 0) }, json.getInt("bootCount"), receivedTime),
                if (json.isNull("fallbackAssetId")) null else WidgetTimelinePolicy.id(json.getString("fallbackAssetId")), schedules, photos)
        }
    } catch (_: Exception) { null }

    private fun encode(state: State) = JSONObject().apply {
        put("generation", state.generation); put("scope", state.scope)
        put("serverTimeMs", state.anchor.serverTimeMs); put("wallTimeMs", state.anchor.wallTimeMs)
        put("receivedServerTimeMs", state.anchor.receivedServerTimeMs)
        put("elapsedMs", state.anchor.elapsedMs); put("bootCount", state.anchor.bootCount)
        put("fallbackAssetId", state.fallback ?: JSONObject.NULL)
        put("schedules", JSONArray().apply { state.schedules.forEach { row ->
            put(JSONObject().apply {
                put("scheduleId", row.scheduleId); put("assetId", row.assetId)
                put("activeFromMs", row.activeFromMs); put("activeUntilMs", row.activeUntilMs); put("createdAtMs", row.createdAtMs)
                put("createdAtUs", row.createdAtUs)
            })
        } })
        put("photos", JSONObject(state.photos))
    }

    private fun writePointer(context: Context, bytes: ByteArray) {
        val atomic = pointer(context)
        val stream = atomic.startWrite()
        try { stream.write(bytes); atomic.finishWrite(stream) } catch (failure: Throwable) {
            atomic.failWrite(stream)
            throw failure
        }
    }

    private fun alarmIntent(context: Context, generation: String? = null): PendingIntent = PendingIntent.getBroadcast(
        context, 7821, Intent(context, WidgetTimelineReceiver::class.java).setAction(ALARM_ACTION).apply {
            if (generation != null) putExtra("generation", generation)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun arm(context: Context, generation: String, delay: Long) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP,
            SystemClock.elapsedRealtime() + delay.coerceAtLeast(1), alarmIntent(context, generation))
    }

    private fun cancel(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(alarmIntent(context))
    }

    private fun isInside(file: File, directory: File): Boolean =
        file.canonicalPath.startsWith(directory.canonicalPath + File.separator)

    private fun cleanup(context: Context, generation: String?) {
        val retained = prefs(context).getString(IMAGE_PATH, null)?.let(::File)
        root(context).listFiles()?.forEach { file ->
            if (file.name != generation && file.name !in setOf("active.json", "active.json.bak", "active.json.new") &&
                (retained == null || (file.canonicalPath != retained.canonicalPath && !isInside(retained, file)))) {
                file.deleteRecursively()
            }
        }
    }

    private fun renderLocked(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, CloseCallWidgetProvider::class.java))
        CloseCallWidgetProvider.render(context, manager, ids, prefs(context))
    }
}
