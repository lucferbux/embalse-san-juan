package com.lucferbux.embalsesanjuan.data

import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject

private const val BASE_URL =
    "https://firestore.googleapis.com/v1/projects/embalse-san-juan/databases/(default)/documents"
private const val SUPPORTED_SCHEMA = 1

/** Reads public documents through Firestore's REST API, the same way as the iOS app. */
object FirestoreClient {
    suspend fun fetchSnapshot(): Pair<Snapshot, String> {
        val payload = payloadOf(get("$BASE_URL/public/snapshot"))
        val snapshot = contractJson.decodeFromString<Snapshot>(payload)
        if (snapshot.schemaVersion != SUPPORTED_SCHEMA) throw IOException("Unsupported schema ${snapshot.schemaVersion}")
        return snapshot to payload
    }

    suspend fun fetchHistory(): History {
        val payload = payloadOf(get("$BASE_URL/public/history"))
        return History.parse(contractJson.parseToJsonElement(payload).jsonObject)
    }

    /** Documents hold the contract JSON in one string field, `payload`. */
    fun payloadOf(document: String): String =
        contractJson.parseToJsonElement(document).jsonObject["fields"]?.jsonObject
            ?.get("payload")?.jsonObject
            ?.get("stringValue")?.jsonPrimitive?.content
            ?: throw IOException("Document has no payload")

    private suspend fun get(url: String): String = withContext(Dispatchers.IO) {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 20_000
            connection.readTimeout = 20_000
            if (connection.responseCode != 200) throw IOException("HTTP ${connection.responseCode}")
            connection.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }
}

/** Keeps the last good snapshot, so the app and widgets work offline. */
class SnapshotRepository(cacheDirectory: File) {
    enum class Origin { Network, Cache }

    private val file = File(cacheDirectory, "snapshot.json")

    fun cached(): Snapshot? = runCatching {
        contractJson.decodeFromString<Snapshot>(file.readText())
    }.getOrNull()

    /** Falls back to the last saved snapshot. Only throws when there is nothing to show at all. */
    suspend fun load(
        fetch: suspend () -> Pair<Snapshot, String> = FirestoreClient::fetchSnapshot,
    ): Pair<Snapshot, Origin> = try {
        val (snapshot, payload) = fetch()
        withContext(Dispatchers.IO) {
            val temporary = File(file.parentFile, "${file.name}.tmp")
            temporary.writeText(payload)
            temporary.renameTo(file)
        }
        snapshot to Origin.Network
    } catch (error: IOException) {
        val cached = withContext(Dispatchers.IO) { cached() } ?: throw error
        cached to Origin.Cache
    }
}

/** A suggestion sent from the app. It's anonymous, and the limits mirror firebase/firestore.rules. */
data class Suggestion(val kind: Kind, val text: String) {
    enum class Kind(val id: String, val label: String) {
        Suggestion("suggestion", "Sugerencia"),
        Bug("bug", "Algo no funciona"),
        Other("other", "Otra cosa"),
    }

    val trimmedText: String get() = text.trim()
    val isValid: Boolean get() = trimmedText.length in MINIMUM_LENGTH..MAXIMUM_LENGTH

    fun firestoreBody(appVersion: String, now: Instant = Instant.now()): JsonObject = buildJsonObject {
        putJsonObject("fields") {
            putJsonObject("kind") { put("stringValue", kind.id) }
            putJsonObject("text") { put("stringValue", trimmedText) }
            putJsonObject("appVersion") { put("stringValue", appVersion) }
            putJsonObject("createdAt") { put("timestampValue", now.truncatedTo(ChronoUnit.SECONDS).toString()) }
        }
    }

    companion object {
        const val MINIMUM_LENGTH = 3
        const val MAXIMUM_LENGTH = 1000
    }
}

object SuggestionClient {
    suspend fun send(suggestion: Suggestion, appVersion: String) = withContext(Dispatchers.IO) {
        require(suggestion.isValid)
        val connection = URL("$BASE_URL/suggestions").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.connectTimeout = 20_000
            connection.readTimeout = 20_000
            connection.setRequestProperty("Content-Type", "application/json")
            connection.outputStream.use { it.write(suggestion.firestoreBody(appVersion).toString().toByteArray()) }
            if (connection.responseCode != 200) throw IOException("HTTP ${connection.responseCode}")
        } finally {
            connection.disconnect()
        }
    }
}
