package com.lucferbux.embalsesanjuan.data

import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.abs

/**
 * The last 12 months of SAIH daily volume, ready to draw as the water card's surface: fractions of capacity, sampled
 * every few days and ending with today's live reading, plus the same days a year earlier and the range of the four
 * years before. SAIH only; MITECO's weekly series never mixes in. Mirrors iOS's `YearSurface`.
 */
data class YearSurface(
    val start: LocalDate,
    val end: LocalDate,
    val levels: List<Double>,
    val lastYear: List<Double>?,
    val band: List<ClosedFloatingPointRange<Double>>?,
    val record: Double?,
    val capacityHm3: Double,
    val lastYearHm3: Double?,
    val todayHm3: Double,
) {
    fun date(index: Int): LocalDate = if (index >= levels.lastIndex) end else start.plusDays((index * STEP).toLong())

    val changeFromLastYearHm3: Double? get() = lastYearHm3?.let { todayHm3 - it }

    companion object {
        const val STEP = 3

        fun of(history: History, today: ReservoirReading?, capacityHm3: Double, zone: ZoneId = ZoneId.systemDefault()): YearSurface? {
            if (capacityHm3 <= 0 || history.daily.isEmpty()) return null
            val daily = history.daily.sortedBy { it.day }
            val end = today?.observedAt?.atZone(zone)?.toLocalDate() ?: daily.last().day
            val start = end.minusDays(364)

            // The last value on or before each sampled day, carried forward over gaps.
            fun values(first: LocalDate): List<Double?> {
                val result = mutableListOf<Double?>()
                var index = 0
                var current: Double? = null
                for (offset in 0..364 step STEP) {
                    val day = first.plusDays(offset.toLong())
                    while (index < daily.size && !daily[index].day.isAfter(day)) {
                        current = daily[index].volumeHm3
                        index++
                    }
                    result += current
                }
                return result
            }

            val thisYear = values(start)
            if (thisYear.count { it != null } < thisYear.size / 2) return null
            val firstKnown = thisYear.firstNotNullOfOrNull { it } ?: 0.0
            val todayVolume = today?.volumeHm3 ?: daily.last().volumeHm3
            val levels = thisYear.map { (it ?: firstKnown) / capacityHm3 } + todayVolume / capacityHm3

            fun yearsBack(years: Int): List<Double?>? {
                val first = start.minusDays(365L * years)
                return if (!daily.first().day.isAfter(first)) values(first) else null
            }
            val previous = yearsBack(1)
            val lastYear = previous?.map { (it ?: 0.0) / capacityHm3 }?.let { it + it.last() }
            val years = (1..4).mapNotNull(::yearsBack)
            val band = if (years.size >= 2) {
                thisYear.indices.map { index ->
                    val shares = years.mapNotNull { it[index] }.map { it / capacityHm3 }
                    (shares.minOrNull() ?: 0.0)..(shares.maxOrNull() ?: 0.0)
                }.let { it + it.last() }
            } else null

            return YearSurface(
                start = start,
                end = end,
                levels = levels,
                lastYear = lastYear,
                band = band,
                record = daily.maxOf { it.volumeHm3 } / capacityHm3,
                capacityHm3 = capacityHm3,
                lastYearHm3 = previous?.lastOrNull(),
                todayHm3 = todayVolume,
            )
        }
    }
}

/**
 * This year's MITECO weeks against the same weeks last year, the 10-year average and the range since 1988. Every line
 * is MITECO's weekly series. A past week counts within 3,5 days of the same date; the average needs all 10 years.
 * Mirrors iOS's `YearComparison`.
 */
data class YearComparison(
    val year: Int,
    val capacityHm3: Double,
    val thisYear: List<HistoryPoint>,
    val lastYear: List<HistoryPoint>,
    val average: List<HistoryPoint>,
    val range: List<Triple<LocalDate, Double, Double>>,
    val lowest: Pair<LocalDate, Double>?,
    val highest: Pair<LocalDate, Double>?,
) {
    val lastYearNow: Double? get() = nearest(lastYear, thisYear.lastOrNull()?.day)
    val averageNow: Double? get() = nearest(average, thisYear.lastOrNull()?.day)

    private fun nearest(points: List<HistoryPoint>, day: LocalDate?): Double? {
        day ?: return null
        val best = points.minByOrNull { abs(it.day.toEpochDay() - day.toEpochDay()) } ?: return null
        return if (abs(best.day.toEpochDay() - day.toEpochDay()) <= TOLERANCE_DAYS) best.volumeHm3 else null
    }

    companion object {
        private const val TOLERANCE_DAYS = 3
        private const val YEARS = 10

        fun of(history: History): YearComparison? {
            val weekly = history.weekly.sortedBy { it.day }
            val latest = weekly.lastOrNull() ?: return null
            val year = latest.day.year
            fun near(day: LocalDate): HistoryPoint? {
                var low = 0
                var high = weekly.lastIndex
                while (low < high) {
                    val mid = (low + high) / 2
                    if (weekly[mid].day.isBefore(day)) low = mid + 1 else high = mid
                }
                return listOf(low - 1, low).filter { it in weekly.indices }
                    .minByOrNull { abs(weekly[it].day.toEpochDay() - day.toEpochDay()) }
                    ?.let { weekly[it] }
                    ?.takeIf { abs(it.day.toEpochDay() - day.toEpochDay()) <= TOLERANCE_DAYS }
            }
            val last = weekly.filter { it.day.year == year - 1 }
            val share = { point: HistoryPoint -> point.volumeHm3 / (point.capacityHm3 ?: latest.capacityHm3 ?: 1.0) }
            val capacity = latest.capacityHm3 ?: return null
            val firstYear = weekly.first().day.year
            return YearComparison(
                year = year,
                capacityHm3 = capacity,
                thisYear = weekly.filter { it.day.year == year },
                lastYear = last.map { it.copy(day = it.day.plusYears(1)) },
                average = last.mapNotNull { week ->
                    val reference = week.day.plusYears(1)
                    val values = (1..YEARS).mapNotNull { near(reference.minusYears(it.toLong()))?.volumeHm3 }
                    if (values.size == YEARS) HistoryPoint(reference, values.average()) else null
                },
                range = last.mapNotNull { week ->
                    val reference = week.day.plusYears(1)
                    val shares = (1..maxOf(year - firstYear, 1)).mapNotNull { back -> near(reference.minusYears(back.toLong()))?.let(share) }
                    if (shares.size >= 2) Triple(reference, shares.min() * capacity, shares.max() * capacity) else null
                },
                lowest = weekly.minByOrNull(share)?.let { it.day to share(it) * 100 },
                highest = weekly.maxByOrNull(share)?.let { it.day to share(it) * 100 },
            )
        }
    }
}
