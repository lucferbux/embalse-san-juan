package com.lucferbux.embalsesanjuan.data

import java.text.NumberFormat
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

/** Spanish number and date formats, whatever the device's region. */
object Format {
    private val spanish: Locale = Locale.forLanguageTag("es-ES")
    private val hourFormat = DateTimeFormatter.ofPattern("HH:mm", spanish)
    private val dayMonthFormat = DateTimeFormatter.ofPattern("d MMM", spanish)
    private val monthYearFormat = DateTimeFormatter.ofPattern("MMM yyyy", spanish)

    fun number(value: Double, decimals: Int = 1): String =
        NumberFormat.getNumberInstance(spanish).apply {
            minimumFractionDigits = decimals
            maximumFractionDigits = decimals
            isGroupingUsed = false
        }.format(value)

    fun percent(value: Double): String = "${number(value)} %"

    fun hm3(value: Double, decimals: Int = 1): String = "${number(value, decimals)} hm³"

    fun signed(value: Double, decimals: Int = 2): String {
        val text = number(abs(value), decimals)
        return when {
            value > 0 -> "+$text"
            value < 0 -> "−$text"
            else -> text
        }
    }

    fun optional(value: Double?, unit: String, decimals: Int = 1): String =
        if (value == null) "Sin dato" else "${number(value, decimals)} $unit"

    fun hour(instant: Instant, zone: ZoneId = ZoneId.systemDefault()): String =
        hourFormat.format(instant.atZone(zone))

    fun dayMonth(day: LocalDate): String = dayMonthFormat.format(day).replace(".", "")

    fun dayMonthHour(instant: Instant, zone: ZoneId = ZoneId.systemDefault()): String =
        "${dayMonth(instant.atZone(zone).toLocalDate())}, ${hour(instant, zone)}"

    fun monthYear(day: LocalDate): String = monthYearFormat.format(day).replace(".", "")

    /** 16-point compass name for a direction in degrees. */
    fun compass(degrees: Double): String {
        val names = listOf("N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO")
        val normalised = ((degrees % 360) + 360) % 360
        return names[(normalised / 22.5).roundToInt() % names.size]
    }
}

enum class Trend(val label: String) {
    Rising("Subiendo"),
    Falling("Bajando"),
    Steady("Estable");

    companion object {
        /** Wind moves the gauge by around ±0.1 hm³ in a day, so smaller changes aren't real movement. */
        private const val THRESHOLD = 0.2

        fun of(change: Double): Trend = when {
            change > THRESHOLD -> Rising
            change < -THRESHOLD -> Falling
            else -> Steady
        }
    }
}
