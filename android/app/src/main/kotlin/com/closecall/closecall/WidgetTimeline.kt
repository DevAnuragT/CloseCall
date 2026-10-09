package com.closecall.closecall

import java.util.UUID

/** Android-free policy, also used when reading persisted (untrusted) metadata. */
internal object WidgetTimelinePolicy {
    const val TTL_MS = 24 * 60 * 60 * 1000L
    const val MAX_PHOTO_BYTES = 2 * 1024 * 1024
    const val MAX_TOTAL_BYTES = 24 * 1024 * 1024L
    const val MAX_DIMENSION = 2048
    private const val MAX_TIME = 253402300799999L
    private val uuid = Regex("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")

    fun id(value: Any?): String {
        require(value is String && uuid.matches(value)) { "Invalid UUID" }
        return UUID.fromString(value).toString()
    }

    fun time(value: Any?): Long {
        require(value is Long || value is Int) { "Expected integer timestamp" }
        return (value as Number).toLong().also { require(it in 0..MAX_TIME) }
    }

    fun creationTime(value: Any?, millis: Long): Long {
        if (value == null) return millis * 1000
        require(value is Long || value is Int) { "Expected integer creation time" }
        return (value as Number).toLong().also {
            require(it in 0..(MAX_TIME * 1000 + 999) && it / 1000 == millis)
        }
    }

    fun validate(scope: String, serverTime: Long, schedules: List<WidgetSchedule>, photos: Map<String, ByteArray>) {
        require(scope.length in 1..256 && scope.matches(Regex("[a-zA-Z0-9:_/.-]+"))) { "Invalid scope" }
        require(!scope.contains("://")) { "Scope must be an identity, not a URL" }
        time(serverTime)
        require(schedules.size <= 100) { "At most 100 schedules" }
        require(schedules.map { it.scheduleId }.toSet().size == schedules.size) { "Duplicate schedule" }
        schedules.forEach {
            id(it.scheduleId); id(it.assetId)
            time(it.activeFromMs); time(it.activeUntilMs); time(it.createdAtMs)
            creationTime(it.createdAtUs, it.createdAtMs)
            require(it.activeFromMs < it.activeUntilMs) { "Invalid interval" }
        }
        require(photos.size <= 12) { "At most 12 photos" }
        photos.forEach { (key, bytes) ->
            id(key)
            require(bytes.size in 1..MAX_PHOTO_BYTES) { "Photo exceeds 2 MiB" }
        }
        require(photos.values.sumOf { it.size.toLong() } <= MAX_TOTAL_BYTES) { "Photo quota exceeded" }
    }

    fun validateDimensions(width: Int, height: Int) {
        require(width in 1..MAX_DIMENSION && height in 1..MAX_DIMENSION) { "Invalid image dimensions" }
    }
}

internal data class WidgetSchedule(
    val scheduleId: String,
    val assetId: String,
    val activeFromMs: Long,
    val activeUntilMs: Long,
    val createdAtMs: Long,
    val createdAtUs: Long = createdAtMs * 1000,
)

internal object WidgetTimelineResolver {
    fun resolve(schedules: List<WidgetSchedule>, fallback: String?, now: Long): String? =
        schedules.filter { it.activeFromMs <= now && now < it.activeUntilMs }
            .sortedWith(compareByDescending<WidgetSchedule> { it.createdAtUs }.thenByDescending { it.scheduleId })
            .firstOrNull()?.assetId ?: fallback

    fun nextBoundary(schedules: List<WidgetSchedule>, fallback: String?, now: Long, expiresAt: Long): Long {
        val current = resolve(schedules, fallback, now)
        return schedules.filter { it.activeFromMs < it.activeUntilMs }
            .flatMap { listOf(it.activeFromMs, it.activeUntilMs) }.distinct().sorted()
            .firstOrNull { it > now && it < expiresAt && resolve(schedules, fallback, it) != current }
            ?: expiresAt
    }

    fun cachedAsset(schedules: List<WidgetSchedule>, fallback: String?, now: Long, available: Set<String>): String? =
        resolve(schedules, fallback, now)?.takeIf { it in available } ?: fallback?.takeIf { it in available }
}

internal data class WidgetClockAnchor(
    val serverTimeMs: Long,
    val wallTimeMs: Long,
    val elapsedMs: Long,
    val bootCount: Int,
    val receivedServerTimeMs: Long = serverTimeMs,
    val expiresAtOverrideMs: Long? = null,
) {
    fun now(wallNow: Long, elapsedNow: Long, currentBoot: Int): Long {
        if (bootCount >= 0 && bootCount == currentBoot && elapsedNow >= elapsedMs) {
            return serverTimeMs + (elapsedNow - elapsedMs)
        }
        // Reboot destroys elapsedRealtime's anchor. Never trust an unbounded wall offset.
        val offset = (serverTimeMs - wallTimeMs).coerceIn(-WidgetTimelinePolicy.TTL_MS, WidgetTimelinePolicy.TTL_MS)
        return (wallNow + offset).coerceAtLeast(serverTimeMs)
    }

    val expiresAtMs: Long get() = expiresAtOverrideMs ?: receivedServerTimeMs + WidgetTimelinePolicy.TTL_MS

    fun expired(now: Long): Boolean = now >= expiresAtMs

    fun reanchor(wallNow: Long, elapsedNow: Long, currentBoot: Int): WidgetClockAnchor =
        WidgetClockAnchor(
            now(wallNow, elapsedNow, currentBoot), wallNow, elapsedNow, currentBoot,
            receivedServerTimeMs, expiresAtOverrideMs,
        )
}
