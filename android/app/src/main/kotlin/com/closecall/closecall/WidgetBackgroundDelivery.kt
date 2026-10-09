package com.closecall.closecall

import android.content.Context
import android.net.Uri
import android.util.Base64
import com.it_nomads.fluttersecurestorage.FlutterSecureStorage
import com.it_nomads.fluttersecurestorage.FlutterSecureStorageConfig
import com.it_nomads.fluttersecurestorage.SecurePreferencesCallback
import org.json.JSONObject
import org.json.JSONTokener
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Closed-app read path. It uses only the device capability from secure
 * storage, never a user session or a refresh token. Network and native writes
 * are bounded by the caller's single serialized push executor.
 */
internal object WidgetBackgroundDelivery {
    private const val CONFIG_PREFS = "CloseCallBackgroundDelivery"
    private const val SERVER_URL = "server_url"
    private const val SECURE_KEY = "closecall.widget.read_credential.v1"
    private const val FLUTTER_SECURE_PREFS = "FlutterSecureStorage"
    private const val FLUTTER_PREFIX =
        "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg"
    private const val MAX_TIMELINE_BYTES = 256 * 1024
    private const val MAX_PHOTO_BYTES = 2 * 1024 * 1024
    private const val MAX_ENCODED_PHOTO_BYTES = 3 * 1024 * 1024
    private const val MAX_TOTAL_BYTES = 24 * 1024 * 1024
    private const val HTTP_TIMEOUT_MS = 5_000
    private const val CLOCK_SKEW_MS = 5 * 60 * 1000L
    private val credentialPattern = Regex("^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$")

    enum class Result { APPLIED, NO_AUTHORITY, RETRY }

    private data class Credential(
        val secret: String,
        val deviceId: String,
        val userId: String,
        val coupleId: String,
        val expiresAt: Instant,
    )

    private data class Response(val status: Int, val body: ByteArray)

    fun configureServerUrl(context: Context, arguments: Any?) {
        val value = (arguments as? Map<*, *>)?.get("url") as? String ?: return
        val normalized = validateServerUrl(value) ?: return
        check(context.getSharedPreferences(CONFIG_PREFS, Context.MODE_PRIVATE)
            .edit().putString(SERVER_URL, normalized).commit())
    }

    fun reconcile(context: Context): Result {
        val credential = readCredential(context) ?: return Result.NO_AUTHORITY
        if (!WidgetTimelineStore.backgroundReadAllowed(context, credential.userId, credential.coupleId)) {
            return Result.NO_AUTHORITY
        }
        val base = context.getSharedPreferences(CONFIG_PREFS, Context.MODE_PRIVATE)
            .getString(SERVER_URL, null)?.let(::validateServerUrl) ?: return Result.NO_AUTHORITY
        return try {
            val timeline = postJson(
                URL("${base}widgetBackground/currentTimeline"),
                JSONObject().put("credential", credential.secret).toString(),
                MAX_TIMELINE_BYTES,
            )
            if (timeline.status == 401 || timeline.status == 403) return Result.NO_AUTHORITY
            if (timeline.status != 200) return Result.RETRY
            val payload = timelinePayload(JSONObject(String(timeline.body, Charsets.UTF_8)), credential)
            val photos = LinkedHashMap<String, ByteArray>()
            for (assetId in payload.assetIds) {
                val response = postJson(
                    URL("${base}widgetBackground/downloadPhoto"),
                    JSONObject().put("credential", credential.secret)
                        .put("assetId", assetId).toString(),
                    MAX_ENCODED_PHOTO_BYTES,
                )
                if (response.status == 401 || response.status == 403) return Result.NO_AUTHORITY
                if (response.status != 200) return Result.RETRY
                val bytes = decodeByteData(response.body) ?: return Result.RETRY
                if (bytes.isEmpty() || bytes.size > MAX_PHOTO_BYTES) return Result.RETRY
                val total = photos.values.sumOf { it.size.toLong() } + bytes.size
                if (total > MAX_TOTAL_BYTES) return Result.RETRY
                photos[assetId] = bytes
            }
            WidgetTimelineStore.runSerialized {
                if (!WidgetTimelineStore.backgroundReadAllowed(context, credential.userId, credential.coupleId) ||
                    !Instant.now().isBefore(credential.expiresAt)) {
                    Result.NO_AUTHORITY
                } else {
                    WidgetTimelineStore.cache(
                        context,
                        payload.toNativeArguments(photos),
                        System.currentTimeMillis(),
                        android.os.SystemClock.elapsedRealtime(),
                    )
                    Result.APPLIED
                }
            }
        } catch (_: Exception) {
            // A malformed response, transport error, or storage failure must
            // not become a partial native publication.
            Result.RETRY
        }
    }

    private fun readCredential(context: Context): Credential? {
        val latch = CountDownLatch(1)
        var raw: String? = null
        val storage = FlutterSecureStorage(context)
        val options = hashMapOf<String, Any>(
            "resetOnError" to "true",
            "migrateOnAlgorithmChange" to "true",
            "migrateWithBackup" to "false",
            "enforceBiometrics" to "false",
            "requireBiometricsPerOperation" to "false",
            "keyCipherAlgorithm" to "RSA_ECB_OAEPwithSHA_256andMGF1Padding",
            "storageCipherAlgorithm" to "AES_GCM_NoPadding",
            "biometricType" to "biometricOrDeviceCredential",
            "requireBiometricConfirmation" to "true",
            "preferencesKeyPrefix" to FLUTTER_PREFIX,
            "sharedPreferencesName" to FLUTTER_SECURE_PREFS,
        )
        try {
            storage.initialize(FlutterSecureStorageConfig(options), object : SecurePreferencesCallback<Void> {
                override fun onSuccess(unused: Void?) {
                    storage.read(storage.addPrefixToKey(SECURE_KEY), object : SecurePreferencesCallback<String> {
                        override fun onSuccess(value: String?) { raw = value; latch.countDown() }
                        override fun onError(error: Exception) { latch.countDown() }
                    })
                }

                override fun onError(error: Exception) { latch.countDown() }
            })
            if (!latch.await(HTTP_TIMEOUT_MS.toLong(), TimeUnit.MILLISECONDS)) return null
        } catch (_: Exception) {
            return null
        }
        return try {
            val json = raw?.takeIf { it.length <= 8192 }?.let(::JSONObject) ?: return null
            val secret = json.getString("credential")
            val device = json.getString("deviceId")
            val user = json.getString("userId")
            val couple = json.getString("coupleId")
            val expires = Instant.parse(json.getString("expiresAt"))
            val now = Instant.now()
            require(credentialPattern.matches(secret))
            require(validText(device, 256) && validText(user, 256) && validText(couple, 256))
            require(expires.isAfter(now))
            require(!expires.isAfter(now.plusMillis(24 * 60 * 60 * 1000L + CLOCK_SKEW_MS)))
            Credential(secret, device, user, couple, expires)
        } catch (_: Exception) {
            null
        }
    }

    private data class TimelinePayload(
        val serverTimeMs: Long,
        val expiresAtMs: Long,
        val fallbackAssetId: String?,
        val schedules: List<Map<String, Any>>,
        val assetIds: List<String>,
    ) {
        fun toNativeArguments(photos: Map<String, ByteArray>) = mapOf<String, Any?>(
            "scope" to "${userIdForScope}/${coupleIdForScope}",
            "serverTimeMs" to serverTimeMs,
            "expiresAtMs" to expiresAtMs,
            "fallbackAssetId" to fallbackAssetId,
            "schedules" to schedules,
            "photos" to photos,
        )

        // Set by the parser without duplicating the public payload shape.
        lateinit var userIdForScope: String
        lateinit var coupleIdForScope: String
    }

    private fun timelinePayload(json: JSONObject, credential: Credential): TimelinePayload {
        require(json.optBoolean("autoUpdateEnabled", false))
        require(json.getString("coupleId") == credential.coupleId)
        require(json.getString("recipientId") == credential.userId)
        val serverTime = epochMillis(json.getString("serverTime"))
        val now = System.currentTimeMillis()
        require(serverTime <= now + CLOCK_SKEW_MS && serverTime >= now - 24 * 60 * 60 * 1000L)
        val baseline = when {
            !json.isNull("latestAssetId") -> WidgetTimelinePolicy.id(json.getString("latestAssetId"))
            !json.isNull("fallbackAssetId") -> WidgetTimelinePolicy.id(json.getString("fallbackAssetId"))
            else -> null
        }
        val schedulesJson = json.getJSONArray("schedules")
        require(schedulesJson.length() <= 100)
        val schedules = ArrayList<Map<String, Any>>(schedulesJson.length())
        val assets = LinkedHashSet<String>()
        if (baseline != null) assets.add(baseline)
        if (!json.isNull("currentAssetId")) assets.add(WidgetTimelinePolicy.id(json.getString("currentAssetId")))
        for (index in 0 until schedulesJson.length()) {
            val row = schedulesJson.getJSONObject(index)
            val scheduleId = WidgetTimelinePolicy.id(row.getString("scheduleId"))
            val assetId = WidgetTimelinePolicy.id(row.getString("assetId"))
            require(row.getString("recipientId") == credential.userId)
            require(row.getString("senderId") != credential.userId)
            val from = epochMillis(row.getString("activeFrom"))
            val until = epochMillis(row.getString("activeUntil"))
            val created = epochMillis(row.getString("createdAt"))
            require(from < until)
            schedules += mapOf(
                "scheduleId" to scheduleId,
                "assetId" to assetId,
                "activeFromMs" to from,
                "activeUntilMs" to until,
                "createdAtMs" to created,
                "createdAtUs" to created * 1000,
            )
            assets.add(assetId)
        }
        require(assets.size <= 12)
        val expiresAt = minOf(
            credential.expiresAt.toEpochMilli(),
            serverTime + WidgetTimelinePolicy.TTL_MS,
        )
        require(expiresAt > System.currentTimeMillis())
        return TimelinePayload(serverTime, expiresAt, baseline, schedules, assets.toList()).also {
            it.userIdForScope = credential.userId
            it.coupleIdForScope = credential.coupleId
        }
    }

    private fun postJson(url: URL, body: String, maxBytes: Int): Response {
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = HTTP_TIMEOUT_MS
            readTimeout = HTTP_TIMEOUT_MS
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            useCaches = false
        }
        return try {
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            Response(status, stream?.use { readLimited(it, maxBytes) } ?: ByteArray(0))
        } finally {
            connection.disconnect()
        }
    }

    private fun readLimited(stream: InputStream, maxBytes: Int): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val count = stream.read(buffer)
            if (count < 0) break
            require(output.size() + count <= maxBytes)
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }

    private fun decodeByteData(body: ByteArray): ByteArray? = try {
        val encoded = JSONTokener(String(body, Charsets.UTF_8)).nextValue() as? String ?: return null
        val match = Regex("^decode\\('([A-Za-z0-9+/=]+)',\\s*'base64'\\)$").matchEntire(encoded)
            ?: return null
        Base64.decode(match.groupValues[1], Base64.DEFAULT)
    } catch (_: Exception) {
        null
    }

    private fun epochMillis(value: String): Long = Instant.parse(value).toEpochMilli()

    private fun validText(value: String, max: Int) =
        value.isNotEmpty() && value.length <= max && value.trim() == value &&
            value.none { it.code < 0x20 || it.code == 0x7f }

    private fun validateServerUrl(value: String): String? {
        if (value.length > 2048 || value.trim() != value) return null
        return try {
            val uri = Uri.parse(value)
            require(uri.scheme == "http" || uri.scheme == "https")
            require(!uri.host.isNullOrEmpty() && uri.userInfo == null && uri.query == null && uri.fragment == null)
            "${value.trimEnd('/')}/"
        } catch (_: Exception) {
            null
        }
    }
}
