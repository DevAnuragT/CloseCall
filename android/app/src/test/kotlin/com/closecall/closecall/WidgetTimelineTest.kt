package com.closecall.closecall

import org.junit.Assert.*
import org.junit.Test

class WidgetTimelineTest {
    private val a = "00000000-0000-4000-8000-000000000001"
    private val z = "00000000-0000-4000-8000-000000000002"
    private val photo = "10000000-0000-4000-8000-000000000001"
    private val fallback = "10000000-0000-4000-8000-000000000002"
    private fun schedule(id: String = a, asset: String = photo, from: Long = 100, until: Long = 200, created: Long = 1) =
        WidgetSchedule(id, asset, from, until, created)
    private fun rejects(action: () -> Unit) {
        try { action(); fail("Expected invalid input") } catch (_: IllegalArgumentException) { }
    }

    @Test fun pushVersionsAreBoundedAndMonotonic() {
        assertEquals(8L, PushWakeCoordinator.parseVersion("8"))
        assertNull(PushWakeCoordinator.parseVersion("-1"))
        assertNull(PushWakeCoordinator.parseVersion("9000000000000001"))
        assertNull(PushWakeCoordinator.parseVersion("secret"))
    }

    @Test fun emptyAndExpiredUseFallback() {
        assertEquals(fallback, WidgetTimelineResolver.resolve(emptyList(), fallback, 150))
        assertEquals(fallback, WidgetTimelineResolver.resolve(listOf(schedule()), fallback, 201))
        assertNull(WidgetTimelineResolver.resolve(emptyList(), null, 150))
    }
    @Test fun activeWindowAndFutureWindow() {
        assertEquals(photo, WidgetTimelineResolver.resolve(listOf(schedule()), fallback, 150))
        assertEquals(fallback, WidgetTimelineResolver.resolve(listOf(schedule()), fallback, 99))
        assertEquals(100L, WidgetTimelineResolver.nextBoundary(listOf(schedule()), fallback, 99, 1000))
        assertEquals(200L, WidgetTimelineResolver.nextBoundary(listOf(schedule()), fallback, 150, 1000))
    }
    @Test fun startInclusiveEndExclusive() {
        assertEquals(photo, WidgetTimelineResolver.resolve(listOf(schedule()), fallback, 100))
        assertEquals(fallback, WidgetTimelineResolver.resolve(listOf(schedule()), fallback, 200))
    }
    @Test fun newestCreationWinsRegardlessOfInputOrder() {
        val old = schedule(created = 1)
        val newer = schedule(id = z, asset = fallback, created = 2)
        assertEquals(fallback, WidgetTimelineResolver.resolve(listOf(old, newer), null, 150))
        assertEquals(fallback, WidgetTimelineResolver.resolve(listOf(newer, old), null, 150))
    }
    @Test fun higherLexicographicIdWinsCreationTieMatchingDart() {
        val first = schedule()
        val second = schedule(id = z, asset = fallback)
        assertEquals(fallback, WidgetTimelineResolver.resolve(listOf(first, second), null, 150))
        assertEquals(fallback, WidgetTimelineResolver.resolve(listOf(second, first), null, 150))
    }
    @Test fun submillisecondCreationPriorityMatchesServer() {
        val older = WidgetSchedule(z, fallback, 100, 200, 1, 1001)
        val newer = WidgetSchedule(a, photo, 100, 200, 1, 1002)
        assertEquals(photo, WidgetTimelineResolver.resolve(listOf(older, newer), null, 150))
        assertEquals(photo, WidgetTimelineResolver.resolve(listOf(newer, older), null, 150))
        rejects { WidgetTimelinePolicy.creationTime(2000L, 1) }
    }
    @Test fun newWindowEndsAndOlderWindowResumes() {
        val old = schedule(until = 300)
        val newer = schedule(id = z, asset = fallback, until = 200, created = 2)
        assertEquals(fallback, WidgetTimelineResolver.resolve(listOf(old, newer), null, 199))
        assertEquals(photo, WidgetTimelineResolver.resolve(listOf(old, newer), null, 200))
    }
    @Test fun invalidIntervalsAreIgnoredByResolver() {
        val invalid = listOf(schedule(from = 100, until = 100), schedule(id = z, from = 300, until = 100))
        assertEquals(fallback, WidgetTimelineResolver.resolve(invalid, fallback, 150))
        assertEquals(1000L, WidgetTimelineResolver.nextBoundary(invalid, fallback, 150, 1000))
    }
    @Test fun sameAssetSeamDoesNotCauseFalseTransition() {
        val windows = listOf(schedule(), schedule(id = z, from = 200, until = 300))
        assertEquals(300L, WidgetTimelineResolver.nextBoundary(windows, fallback, 150, 1000))
    }
    @Test fun shadowedBoundariesAreSkipped() {
        val windows = listOf(schedule(from = 110, until = 190), schedule(id = z, asset = fallback, created = 2))
        assertEquals(200L, WidgetTimelineResolver.nextBoundary(windows, null, 100, 1000))
    }
    @Test fun ttlIsAlwaysScheduledEvenWithNoVisualTransition() {
        assertEquals(180L, WidgetTimelineResolver.nextBoundary(listOf(schedule()), fallback, 150, 180))
        assertEquals(180L, WidgetTimelineResolver.nextBoundary(emptyList(), fallback, 150, 180))
    }
    @Test fun delayedWakeCalculatesCurrentTruthNotOriginalTransition() {
        val windows = listOf(schedule(), schedule(id = z, asset = fallback, from = 200, until = 300))
        assertEquals(fallback, WidgetTimelineResolver.resolve(windows, null, 250))
        assertNull(WidgetTimelineResolver.resolve(windows, null, 350))
    }
    @Test fun missingCurrentPhotoUsesCachedFallbackOtherwiseEmpty() {
        assertEquals(fallback, WidgetTimelineResolver.cachedAsset(listOf(schedule()), fallback, 150, setOf(fallback)))
        assertNull(WidgetTimelineResolver.cachedAsset(listOf(schedule()), fallback, 150, emptySet()))
        assertEquals(photo, WidgetTimelineResolver.cachedAsset(listOf(schedule()), fallback, 150, setOf(photo, fallback)))
    }
    @Test fun sameBootUsesMonotonicTimeDespiteWallChanges() {
        val anchor = WidgetClockAnchor(1000, 5000, 100, 4)
        assertEquals(1100L, anchor.now(9999999, 200, 4))
        assertEquals(1100L, anchor.now(0, 200, 4))
    }
    @Test fun rebootUsesWallOffset() {
        val anchor = WidgetClockAnchor(1000, 5000, 100, 4)
        assertEquals(1200L, anchor.now(5200, 20, 5))
        // A new boot may already have elapsed beyond the old anchor; boot count still wins.
        assertEquals(1200L, anchor.now(5200, 20000, 5))
    }
    @Test fun rebootOffsetIsBoundedAndTimeDoesNotPrecedeReceipt() {
        val ttl = WidgetTimelinePolicy.TTL_MS
        val anchor = WidgetClockAnchor(ttl * 10, 0, 100, 4)
        assertEquals(ttl * 21, anchor.now(ttl * 20, 1, 5))
        assertEquals(ttl * 10, anchor.now(0, 1, 5))
        val negative = WidgetClockAnchor(0, ttl * 10, 100, 4)
        assertEquals(ttl * 19, negative.now(ttl * 20, 1, 5))
    }
    @Test fun unknownBootCountDoesNotTrustMonotonicAnchor() {
        val anchor = WidgetClockAnchor(1000, 5000, 100, -1)
        assertEquals(1200L, anchor.now(5200, 900000, -1))
    }
    @Test fun ttlExpiresAtExactly24HoursFromServerReceipt() {
        val anchor = WidgetClockAnchor(1000, 5000, 100, 4)
        assertFalse(anchor.expired(1000 + WidgetTimelinePolicy.TTL_MS - 1))
        assertTrue(anchor.expired(1000 + WidgetTimelinePolicy.TTL_MS))
    }

    @Test fun explicitCredentialExpiryCapsNativeCacheLifetime() {
        val expires = 1000L + 60_000L
        val anchor = WidgetClockAnchor(1000, 5000, 100, 4, expiresAtOverrideMs = expires)
        assertEquals(expires, anchor.expiresAtMs)
        assertFalse(anchor.expired(expires - 1))
        assertTrue(anchor.expired(expires))
        assertEquals(expires, anchor.reanchor(5200, 20, 5).expiresAtMs)
    }
    @Test fun newBootReanchorUsesMonotonicTimeAndDoesNotRenewTtl() {
        val anchor = WidgetClockAnchor(1000, 5000, 100, 4)
        val newBoot = anchor.reanchor(5200, 20, 5)
        assertEquals(1200L, newBoot.serverTimeMs)
        assertEquals(1300L, newBoot.now(9999999, 120, 5))
        assertEquals(anchor.expiresAtMs, newBoot.expiresAtMs)
        assertTrue(newBoot.expired(1000 + WidgetTimelinePolicy.TTL_MS))
    }
    @Test fun strictUuidRejectsPathsAndJavaUuidAbbreviations() {
        assertEquals(a, WidgetTimelinePolicy.id(a.uppercase()))
        rejects { WidgetTimelinePolicy.id("1-1-1-1-1") }
        rejects { WidgetTimelinePolicy.id("../../image.png") }
        rejects { WidgetTimelinePolicy.id("https://server/photo") }
        rejects { WidgetTimelinePolicy.id(null) }
    }
    @Test fun timestampsMustBeIntegersAndBounded() {
        assertEquals(1L, WidgetTimelinePolicy.time(1))
        assertEquals(1L, WidgetTimelinePolicy.time(1L))
        rejects { WidgetTimelinePolicy.time(1.0) }
        rejects { WidgetTimelinePolicy.time(-1) }
        rejects { WidgetTimelinePolicy.time(Long.MAX_VALUE) }
    }
    @Test fun validScopeAndPayload() {
        WidgetTimelinePolicy.validate("$a:1/$z/paired", 1000, listOf(schedule()), mapOf(photo to byteArrayOf(1)))
        WidgetTimelinePolicy.validate(a, 1000, emptyList(), emptyMap())
    }
    @Test fun invalidScopeRejected() {
        rejects { WidgetTimelinePolicy.validate("", 1000, emptyList(), emptyMap()) }
        rejects { WidgetTimelinePolicy.validate("x".repeat(257), 1000, emptyList(), emptyMap()) }
        rejects { WidgetTimelinePolicy.validate("https://host/secret?token=x", 1000, emptyList(), emptyMap()) }
        rejects { WidgetTimelinePolicy.validate("https://host/photo", 1000, emptyList(), emptyMap()) }
    }
    @Test fun duplicateSchedulesAndInvalidIntervalsRejected() {
        rejects { WidgetTimelinePolicy.validate(a, 1000, listOf(schedule(), schedule()), emptyMap()) }
        rejects { WidgetTimelinePolicy.validate(a, 1000, listOf(schedule(until = 100)), emptyMap()) }
        rejects { WidgetTimelinePolicy.validate(a, 1000, listOf(schedule(until = 99)), emptyMap()) }
    }
    @Test fun scheduleCountBound() {
        val rows = (1..100).map { schedule(id = "00000000-0000-4000-8000-${it.toString().padStart(12, '0')}") }
        WidgetTimelinePolicy.validate(a, 1000, rows, emptyMap())
        rejects { WidgetTimelinePolicy.validate(a, 1000, rows + schedule(), emptyMap()) }
    }
    @Test fun photoCountAndIndividualByteLimits() {
        val bytes = ByteArray(WidgetTimelinePolicy.MAX_PHOTO_BYTES)
        val photos = (1..12).associate { "10000000-0000-4000-8000-${it.toString().padStart(12, '0')}" to bytes }
        WidgetTimelinePolicy.validate(a, 1000, emptyList(), photos)
        rejects { WidgetTimelinePolicy.validate(a, 1000, emptyList(), photos + (z to byteArrayOf(1))) }
        rejects { WidgetTimelinePolicy.validate(a, 1000, emptyList(), mapOf(photo to ByteArray(bytes.size + 1))) }
        rejects { WidgetTimelinePolicy.validate(a, 1000, emptyList(), mapOf(photo to byteArrayOf())) }
    }
    @Test fun decodeDimensionBounds() {
        WidgetTimelinePolicy.validateDimensions(2048, 2048)
        rejects { WidgetTimelinePolicy.validateDimensions(2049, 100) }
        rejects { WidgetTimelinePolicy.validateDimensions(100, 2049) }
        rejects { WidgetTimelinePolicy.validateDimensions(-1, -1) }
        rejects { WidgetTimelinePolicy.validateDimensions(0, 100) }
    }
}
