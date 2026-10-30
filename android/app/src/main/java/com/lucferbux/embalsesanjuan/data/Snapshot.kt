package com.lucferbux.embalsesanjuan.data

import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.double
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive

/** Kotlin view of contract/snapshot.schema.json. Tests decode the same fixture the backend validates. */
@Serializable
data class Snapshot(
    val schemaVersion: Int,
    val generatedAt: String,
    val reservoir: Reservoir,
    val live: Live,
    val recent: List<RecentReading>,
    val daily: List<DailyPoint>,
    val weather: Weather,
    val weekly: Weekly,
    val neighbours: List<Neighbour>,
    val rainGauges: List<RainGauge>,
    val sources: List<Source>,
) {
    /** Readings are hourly, so 6 hours without one means collection is failing. */
    fun isStale(now: Instant = Instant.now()): Boolean =
        Duration.between(Instant.parse(live.observedAt), now) > Duration.ofHours(6)
}

@Serializable
data class Reservoir(
    val id: String,
    val name: String,
    val river: String,
    val basin: String,
    val province: String,
    val municipality: String,
    val damType: String,
    val yearBuilt: Int,
    val surfaceHa: Double,
    val uses: List<String>,
)

@Serializable
data class Live(
    val observedAt: String,
    val volumeHm3: Double,
    val percent: Double,
    val elevationM: Double? = null,
    val levelM: Double? = null,
    val trend24hHm3: Double,
    val outflowM3s: Double? = null,
    val transferM3s: Double? = null,
)

@Serializable
data class RecentReading(
    val at: String,
    val volumeHm3: Double,
    val percent: Double,
    val outflowM3s: Double? = null,
) {
    val instant: Instant get() = Instant.parse(at)
}

@Serializable
data class DailyPoint(val date: String, val volumeHm3: Double) {
    val day: LocalDate get() = LocalDate.parse(date)
}

@Serializable
data class Weather(
    val observedAt: String,
    val temperatureC: Double? = null,
    val windMs: Double? = null,
    val windDirectionDeg: Double? = null,
    val humidityPct: Double? = null,
    val pressureHpa: Double? = null,
    val solarWm2: Double? = null,
    val rain1hMm: Double? = null,
    val rain24hMm: Double? = null,
)

@Serializable
data class Weekly(
    val date: String,
    val volumeHm3: Double,
    val capacityHm3: Double,
    val percent: Double,
    val changeHm3: Double,
    val lastYearHm3: Double? = null,
    val tenYearAvgHm3: Double? = null,
) {
    val day: LocalDate get() = LocalDate.parse(date)
}

@Serializable
data class Neighbour(
    val code: String,
    val name: String,
    val position: String,
    val observedAt: String,
    val volumeHm3: Double,
    val percent: Double,
)

@Serializable
data class RainGauge(
    val code: String,
    val name: String,
    val observedAt: String,
    val rain1hMm: Double? = null,
    val rain24hMm: Double? = null,
)

@Serializable
data class Source(val name: String, val publisher: String, val url: String, val note: String)

data class HistoryPoint(val day: LocalDate, val volumeHm3: Double)

/** Payload of public/history, sent as compact rows to keep the document small. */
data class History(val weekly: List<HistoryPoint>, val daily: List<HistoryPoint>) {
    companion object {
        fun parse(json: JsonObject): History {
            fun rows(name: String) = (json.getValue(name) as JsonArray).map { row ->
                val cells = row.jsonArray
                HistoryPoint(LocalDate.parse(cells[0].jsonPrimitive.content), cells[1].jsonPrimitive.double)
            }
            return History(weekly = rows("weekly"), daily = rows("daily"))
        }
    }
}

val contractJson = Json { ignoreUnknownKeys = true }
