package com.lucferbux.embalsesanjuan

import com.lucferbux.embalsesanjuan.data.FirestoreClient
import com.lucferbux.embalsesanjuan.data.Format
import com.lucferbux.embalsesanjuan.data.History
import com.lucferbux.embalsesanjuan.data.Snapshot
import com.lucferbux.embalsesanjuan.data.SnapshotRepository
import com.lucferbux.embalsesanjuan.data.Suggestion
import com.lucferbux.embalsesanjuan.data.Trend
import com.lucferbux.embalsesanjuan.data.contractJson
import com.lucferbux.embalsesanjuan.ui.roundTicks
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.time.Instant
import java.time.ZoneOffset
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/** contract/fixtures/snapshot.json is built and validated by the backend, so decoding it proves both sides agree. */
private val fixtureText: String = sequenceOf("../../contract", "../contract")
    .map { File(it, "fixtures/snapshot.json") }
    .first { it.exists() }
    .readText()

private val fixture: Snapshot = contractJson.decodeFromString(fixtureText)

class ContractTest {
    @Test fun decodesTheSharedFixture() {
        assertEquals(1, fixture.schemaVersion)
        assertEquals(67.03, fixture.live.volumeHm3, 0.0)
        assertEquals(48.66, fixture.live.percent, 0.0)
        assertEquals(24, fixture.recent.size)
        assertEquals(75.0, fixture.weekly.lastYearHm3!!, 0.0)
        assertEquals("Burguillo", fixture.neighbours.first().name)
    }

    @Test fun readsThePayloadFromAFirestoreDocument() {
        val document = buildJsonObject {
            putJsonObject("fields") { putJsonObject("payload") { put("stringValue", "{\"a\":1}") } }
        }.toString()
        assertEquals("{\"a\":1}", FirestoreClient.payloadOf(document))
    }

    @Test fun reportsAMissingPayload() {
        assertThrows(IOException::class.java) { FirestoreClient.payloadOf("{\"fields\":{}}") }
    }

    @Test fun decodesCompactHistoryRows() {
        val json = contractJson.parseToJsonElement(
            """{"weekly":[["1988-01-05",131,146]],"daily":[["2026-10-29",66.99]]}""",
        ).jsonObject
        val history = History.parse(json)
        assertEquals(131.0, history.weekly.first().volumeHm3, 0.0)
        assertEquals(66.99, history.daily.first().volumeHm3, 0.0)
    }
}

class BehaviourTest {
    @Test fun formatsInSpanish() {
        assertEquals("48,7 %", Format.percent(48.66))
        assertEquals("67,0 hm³", Format.hm3(67.03))
        assertEquals("+0,12", Format.signed(0.12))
        assertEquals("−5", Format.signed(-5.0, 0))
        assertEquals("Sin dato", Format.optional(null, "m"))
    }

    @Test fun formatsTimesInTheGivenZone() {
        assertEquals("16:00", Format.hour(Instant.parse("2026-10-30T16:00:00Z"), ZoneOffset.UTC))
    }

    @Test fun compassWrapsAround() {
        assertEquals("N", Format.compass(0.0))
        assertEquals("SSE", Format.compass(147.1))
        assertEquals("N", Format.compass(359.0))
    }

    @Test fun trendIgnoresSensorNoise() {
        assertEquals(Trend.Rising, Trend.of(0.3))
        assertEquals(Trend.Falling, Trend.of(-0.5))
        assertEquals(Trend.Steady, Trend.of(0.12))
    }

    @Test fun staleAfterSixHours() {
        val observed = Instant.parse(fixture.live.observedAt)
        assertFalse(fixture.isStale(observed.plusSeconds(5 * 3600)))
        assertTrue(fixture.isStale(observed.plusSeconds(7 * 3600)))
    }

    @Test fun fallsBackToTheCacheWhenOffline() = runTest {
        val repository = SnapshotRepository(Files.createTempDirectory("cache").toFile())
        val online = repository.load { fixture to fixtureText }
        assertEquals(SnapshotRepository.Origin.Network, online.second)

        val offline = repository.load { throw IOException("offline") }
        assertEquals(SnapshotRepository.Origin.Cache, offline.second)
        assertEquals(fixture, offline.first)
    }

    @Test fun throwsWhenOfflineWithNothingSaved() = runTest {
        val repository = SnapshotRepository(Files.createTempDirectory("cache").toFile())
        var thrown: IOException? = null
        try {
            repository.load { throw IOException("offline") }
        } catch (error: IOException) {
            thrown = error
        }
        assertEquals("offline", thrown?.message)
    }
}

class ChartTest {
    @Test fun axisValuesAreRound() {
        assertEquals(listOf(0f, 50f, 100f, 150f), roundTicks(0f, 151.8f))
        assertEquals(listOf(0f, 10f, 20f), roundTicks(0f, 26.3f))
        assertEquals(3, roundTicks(66.86f, 67.14f).size)
    }
}

class SuggestionTest {
    @Test fun trimsBeforeValidating() {
        assertFalse(Suggestion(Suggestion.Kind.Bug, "  \n ").isValid)
        assertFalse(Suggestion(Suggestion.Kind.Bug, " ab ").isValid)
        assertTrue(Suggestion(Suggestion.Kind.Bug, " abc ").isValid)
    }

    @Test fun enforcesTheMaximumLength() {
        assertTrue(Suggestion(Suggestion.Kind.Other, "a".repeat(1000)).isValid)
        assertFalse(Suggestion(Suggestion.Kind.Other, "a".repeat(1001)).isValid)
    }

    @Test fun bodyHasOnlyTheFieldsTheRulesAllow() {
        val body: JsonObject = Suggestion(Suggestion.Kind.Suggestion, " Más gráficos ")
            .firestoreBody("1.0", Instant.parse("2026-10-30T19:00:00.123Z"))
        val fields = body.getValue("fields").jsonObject
        assertEquals(setOf("kind", "text", "appVersion", "createdAt"), fields.keys)
        assertEquals("suggestion", fields.getValue("kind").jsonObject.getValue("stringValue").jsonPrimitive.content)
        assertEquals("Más gráficos", fields.getValue("text").jsonObject.getValue("stringValue").jsonPrimitive.content)
        assertEquals("2026-10-30T19:00:00Z", fields.getValue("createdAt").jsonObject.getValue("timestampValue").jsonPrimitive.content)
    }
}
