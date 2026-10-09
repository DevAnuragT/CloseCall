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
import java.util.concurrent.FutureTask
import java.util.concurrent.TimeUnit

/** All native mutations and rendering share this lock; a wake cannot publish an old generation. */
internal object WidgetTimelineStore {
    val lock = Any()
    val executor = Executors.newSingleThreadExecutor()
    private const val ENABLED = "closecall_timeline_enabled"
    private const val SUSPENDED = "closecall_timeline_suspended"
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
    private fun ownerFile(context: Context) = AtomicFile(File(root(context), "owner.json"))
    private fun prefs(context: Context) = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    private fun boot(context: Context): Int = Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)
    private fun name() = UUID.randomUUID().toString()

    /** Run a background operation in the same queue as every native mutation. */
    fun <T> runSerialized(operation: () -> T): T {
        val task = FutureTask(operation)
        executor.execute(task)
        return task.get(35, TimeUnit.SECONDS)
    }

    private data class Owner(val scope: String, val path: String, val assetId: String?, val anchor: WidgetClockAnchor)

    /** No tokens/authentication are persisted here. The Flutter caller must first
     * validate secure auth + current membership. A held photo is not permission
     * to run alarms: startup pauses them until fresh recipient truth is cached. */
    fun suspendForStartup(context: Context) = synchronized(lock) {
        PushWakeCoordinator.clear(context)
        cancel(context)
        check(prefs(context).edit().putBoolean(SUSPENDED, true).commit())
        val owner = validOwner(context)
        if (owner == null) { clearLocked(context); renderLocked(context) }
        else armExpiry(context, owner)
    }

    fun restoreScope(context: Context, arguments: Any?): Map<String, Any?>? = synchronized(lock) {
        val input = arguments as? Map<*, *> ?: throw IllegalArgumentException("Expected map")
        val scope = input["scope"] as? String ?: throw IllegalArgumentException("Missing scope")
        WidgetTimelinePolicy.validate(scope, 0, emptyList(), emptyMap())
        cancel(context)
        check(prefs(context).edit().putBoolean(SUSPENDED, true).commit())
        val owner = validOwner(context)
        if (owner == null || owner.scope != scope ||
            (owner.assetId != null && input["allowPartnerPhoto"] != true)) {
            clearLocked(context); renderLocked(context)
            return@synchronized null
        }
        // Reading never changes the original anchor/TTL or resumes old alarms.
        armExpiry(context, owner)
        mapOf("assetId" to owner.assetId, "bytes" to File(owner.path).readBytes())
    }

    fun recordPhotoOwner(context: Context, arguments: Any?) = synchronized(lock) {
        val input = arguments as? Map<*, *> ?: throw IllegalArgumentException("Expected map")
        val scope = input["scope"] as? String ?: throw IllegalArgumentException("Missing scope")
        WidgetTimelinePolicy.validate(scope, 0, emptyList(), emptyMap())
        val assetId = input["assetId"]?.let(WidgetTimelinePolicy::id)
        val path = prefs(context).getString(IMAGE_PATH, null) ?: throw IllegalStateException("Missing photo")
        require(safeDisplayedFile(context, path) != null)
        // A newly written local photo is not permission to resume the previous
        // timeline. Flutter must publish fresh recipient truth separately.
        disable(context)
        val retainedPath = prefs(context).getString(IMAGE_PATH, null) ?: throw IllegalStateException("Missing retained photo")
        val wall = System.currentTimeMillis()
        val owner = Owner(scope, retainedPath, assetId, WidgetClockAnchor(wall, wall, SystemClock.elapsedRealtime(), boot(context)))
        writeOwner(context, owner)
        armExpiry(context, owner)
    }

    private fun safeDisplayedFile(context: Context, path: String): File? {
        val file = File(path)
        if (!isInside(file, root(context)) &&
            !(isInside(file, context.filesDir) && Regex("widget_[0-9]+(?:_[0-9]+)?\\.png").matches(file.name))) return null
        if (!file.isFile || file.length() !in 1..WidgetTimelinePolicy.MAX_PHOTO_BYTES.toLong()) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        if (bounds.outWidth !in 1..2048 || bounds.outHeight !in 1..2048) return null
        val decoded = BitmapFactory.decodeFile(file.absolutePath) ?: return null
        decoded.recycle()
        return file
    }

    private fun validOwner(context: Context): Owner? = try {
        val atomic = ownerFile(context)
        val json = atomic.openRead().use { stream ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(1024)
            while (true) {
                val count = stream.read(buffer)
                if (count < 0) break
                require(output.size() + count <= 8192)
                output.write(buffer, 0, count)
            }
            JSONObject(String(output.toByteArray(), Charsets.UTF_8))
        }
        val scope = json.getString("scope")
        WidgetTimelinePolicy.validate(scope, 0, emptyList(), emptyMap())
        val server = WidgetTimelinePolicy.time(json.getLong("serverTimeMs"))
        val received = WidgetTimelinePolicy.time(json.getLong("receivedServerTimeMs"))
        require(received <= server)
        val expiresAt = if (json.has("expiresAtMs") && !json.isNull("expiresAtMs"))
            WidgetTimelinePolicy.time(json.getLong("expiresAtMs")) else null
        require(expiresAt == null || (expiresAt >= server && expiresAt <= received + WidgetTimelinePolicy.TTL_MS))
        val anchor = WidgetClockAnchor(server, WidgetTimelinePolicy.time(json.getLong("wallTimeMs")),
            json.getLong("elapsedMs").also { require(it >= 0) }, json.getInt("bootCount"), received,
            expiresAt)
        val path = json.getString("path")
        require(path == prefs(context).getString(IMAGE_PATH, null))
        require(!anchor.expired(anchor.now(System.currentTimeMillis(), SystemClock.elapsedRealtime(), boot(context))))
        require(safeDisplayedFile(context, path) != null)
        val assetId = if (json.isNull("assetId")) null else WidgetTimelinePolicy.id(json.getString("assetId"))
        if (prefs(context).getBoolean(ENABLED, false)) {
            val state = read(context) ?: error("Invalid timeline")
            require(state.scope == scope && assetId != null)
            require(!state.anchor.expired(state.anchor.now(System.currentTimeMillis(), SystemClock.elapsedRealtime(), boot(context))))
            require(state.photos.keys.all { photo(context, state, it) != null })
            require(photo(context, state, assetId)?.absolutePath == path)
        }
        Owner(scope, path, assetId, anchor)
    } catch (_: Exception) { null }

    private fun writeOwner(context: Context, owner: Owner) {
        root(context).mkdirs()
        val json = JSONObject().apply {
            put("scope", owner.scope); put("path", owner.path); put("assetId", owner.assetId ?: JSONObject.NULL)
            put("serverTimeMs", owner.anchor.serverTimeMs); put("receivedServerTimeMs", owner.anchor.receivedServerTimeMs)
            put("wallTimeMs", owner.anchor.wallTimeMs); put("elapsedMs", owner.anchor.elapsedMs); put("bootCount", owner.anchor.bootCount)
            if (owner.anchor.expiresAtOverrideMs != null) put("expiresAtMs", owner.anchor.expiresAtOverrideMs)
        }
        val atomic = ownerFile(context)
        val stream = atomic.startWrite()
        try { stream.write(json.toString().toByteArray(Charsets.UTF_8)); atomic.finishWrite(stream) }
        catch (failure: Throwable) { atomic.failWrite(stream); throw failure }
    }

    fun cache(context: Context, arguments: Any?, receivedWallMs: Long, receivedElapsedMs: Long) = synchronized(lock) {
        val input = arguments as? Map<*, *> ?: throw IllegalArgumentException("Expected map")
        val scope = input["scope"] as? String ?: throw IllegalArgumentException("Missing scope")
        val serverTime = WidgetTimelinePolicy.time(input["serverTimeMs"])
        // Capture at receipt, not after image I/O.
        val anchor = WidgetClockAnchor(serverTime, receivedWallMs, receivedElapsedMs, boot(context))
        val expiresAt = input["expiresAtMs"]?.let(WidgetTimelinePolicy::time)
        require(expiresAt == null ||
            (expiresAt >= serverTime && expiresAt <= serverTime + WidgetTimelinePolicy.TTL_MS))
        val anchored = anchor.copy(expiresAtOverrideMs = expiresAt)
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
            val state = State(generation, scope, anchored, fallback, schedules, names)
            val json = encode(state).toString().toByteArray(Charsets.UTF_8)
            FileOutputStream(File(stage, "timeline.json")).use { it.write(json); it.fd.sync() }
            writePointer(context, json)
            exposed = true
            val currentId = WidgetTimelineResolver.cachedAsset(schedules, fallback, serverTime, names.keys)
            val current = photo(context, state, currentId)
            check(prefs(context).edit().putString(IMAGE_PATH, current?.absolutePath)
                .putBoolean(ENABLED, true).putBoolean(SUSPENDED, false).commit())
            if (current != null) writeOwner(context, Owner(scope, current.absolutePath, currentId, anchored))
            else ownerFile(context).delete()
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
        val owner = validOwner(context)
        if (current != null && isInside(current, directory) && current.isFile) {
            val retained = File(directory, "${name()}.photo")
            // Rename is atomic and uses no extra photo quota.
            check(current.renameTo(retained)) { "Cannot retain displayed photo" }
            check(data.edit().putString(IMAGE_PATH, retained.absolutePath).putBoolean(ENABLED, false).commit())
            if (owner != null) writeOwner(context, owner.copy(path = retained.absolutePath))
        } else {
            check(data.edit().putBoolean(ENABLED, false).commit())
        }
        pointer(context).delete()
        cleanup(context, null)
        if (owner != null) armExpiry(context, owner)
    }

    fun clear(context: Context) = synchronized(lock) { clearLocked(context); renderLocked(context) }

    private fun clearLocked(context: Context) {
        PushWakeCoordinator.clear(context)
        cancel(context)
        check(prefs(context).edit().remove(IMAGE_PATH).putBoolean(ENABLED, false).putBoolean(SUSPENDED, true).commit())
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

    /**
     * A closed-app read may proceed only while the foreground coordinator has
     * left a live, enabled native timeline for this identity.  The secure
     * credential is checked separately by [WidgetBackgroundDelivery].  An
     * empty cache is allowed so the first closed-app delivery can bootstrap a
     * timeline; a disabled cache is never treated as consent.
     */
    fun backgroundReadAllowed(context: Context, userId: String, coupleId: String): Boolean =
        synchronized(lock) {
            if (prefs(context).getBoolean(SUSPENDED, false)) return@synchronized false
            val state = read(context)
            if (state == null) {
                return@synchronized prefs(context).getString(IMAGE_PATH, null) == null
            }
            if (!prefs(context).getBoolean(ENABLED, false)) return@synchronized false
            state.scope == "$userId/$coupleId" ||
                (state.scope.startsWith("$userId:") &&
                    state.scope.contains("/$coupleId/paired"))
        }

    private fun refreshLocked(context: Context, expectedGeneration: String?) {
        if (prefs(context).getBoolean(SUSPENDED, false)) {
            cancel(context)
            val owner = validOwner(context)
            if (owner == null) clearLocked(context) else armExpiry(context, owner)
            renderLocked(context)
            return
        }
        if (!prefs(context).getBoolean(ENABLED, false)) {
            cancel(context)
            // A persisted tombstone wins even if the process died before deleting the pointer.
            pointer(context).delete()
            cleanup(context, null)
            val owner = validOwner(context)
            if (prefs(context).getString(IMAGE_PATH, null) != null && owner == null) clearLocked(context)
            else if (owner != null) armExpiry(context, owner)
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
        val owner = validOwner(context)
        if (prefs(context).getString(IMAGE_PATH, null) != null && (owner == null || owner.scope != state.scope)) {
            clearLocked(context); renderLocked(context); return
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
        if (image != null) writeOwner(context, Owner(state.scope, image.absolutePath,
            if (photo(context, state, resolved) != null) resolved else state.fallback, state.anchor))
        else ownerFile(context).delete()
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
            val expiresAt = if (json.has("expiresAtMs") && !json.isNull("expiresAtMs"))
                WidgetTimelinePolicy.time(json.getLong("expiresAtMs")) else null
            require(expiresAt == null ||
                (expiresAt >= serverTime && expiresAt <= receivedTime + WidgetTimelinePolicy.TTL_MS))
            val scope = json.getString("scope")
            WidgetTimelinePolicy.validate(scope, serverTime, schedules, emptyMap())
            State(WidgetTimelinePolicy.id(json.getString("generation")), scope,
                WidgetClockAnchor(serverTime, WidgetTimelinePolicy.time(json.getLong("wallTimeMs")),
                    json.getLong("elapsedMs").also { require(it >= 0) }, json.getInt("bootCount"), receivedTime,
                    expiresAt),
                if (json.isNull("fallbackAssetId")) null else WidgetTimelinePolicy.id(json.getString("fallbackAssetId")), schedules, photos)
        }
    } catch (_: Exception) { null }

    private fun encode(state: State) = JSONObject().apply {
        put("generation", state.generation); put("scope", state.scope)
        put("serverTimeMs", state.anchor.serverTimeMs); put("wallTimeMs", state.anchor.wallTimeMs)
        put("receivedServerTimeMs", state.anchor.receivedServerTimeMs)
        put("elapsedMs", state.anchor.elapsedMs); put("bootCount", state.anchor.bootCount)
        if (state.anchor.expiresAtOverrideMs != null) put("expiresAtMs", state.anchor.expiresAtOverrideMs)
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

    private fun armExpiry(context: Context, owner: Owner) {
        // While paused/identity-unknown this wake can only clear an expired
        // display; refresh's suspended/disabled branches cannot apply schedules.
        val now = owner.anchor.now(System.currentTimeMillis(), SystemClock.elapsedRealtime(), boot(context))
        arm(context, "held-photo-expiry", owner.anchor.expiresAtMs - now)
    }

    private fun cancel(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(alarmIntent(context))
    }

    private fun isInside(file: File, directory: File): Boolean =
        file.canonicalPath.startsWith(directory.canonicalPath + File.separator)

    private fun cleanup(context: Context, generation: String?) {
        val retained = prefs(context).getString(IMAGE_PATH, null)?.let(::File)
        root(context).listFiles()?.forEach { file ->
            if (file.name != generation && file.name !in setOf("active.json", "active.json.bak", "active.json.new", "owner.json", "owner.json.bak", "owner.json.new") &&
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
