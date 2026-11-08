package com.lucferbux.embalsesanjuan.data

import java.text.NumberFormat
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * The number style shared with iOS (docs/design/DESIGN-2.0.md): a no-break space before units, the real minus sign,
 * and fixed date patterns. Spanish with Spain's formats, or English with British ones, following the device.
 */
object Format {
    /** U+00A0, so "46,6 %" never breaks before its unit. */
    const val SPACE = " "

    private val spanish: Locale = Locale.forLanguageTag("es-ES")
    private val english: Locale = Locale.forLanguageTag("en-GB")

    /** The language the app shows. Tests set it; the app follows the device. */
    @Volatile var locale: Locale = resolve(Locale.getDefault())

    fun resolve(device: Locale): Locale = if (device.language == "es") spanish else english

    val isSpanish: Boolean get() = locale.language == "es"

    fun number(value: Double, decimals: Int = 1): String =
        NumberFormat.getNumberInstance(locale).apply {
            minimumFractionDigits = decimals
            maximumFractionDigits = decimals
            isGroupingUsed = false
        }.format(value).replace("-", "−")

    fun percent(value: Double): String = "${number(value)}$SPACE%"

    fun hm3(value: Double, decimals: Int = 1): String = "${number(value, decimals)}${SPACE}hm³"

    fun volumeOfCapacity(volume: Double, capacity: Double): String =
        if (isSpanish) "${hm3(volume)} de ${hm3(capacity, 0)}" else "${hm3(volume)} of ${hm3(capacity, 0)}"

    fun signed(value: Double, decimals: Int = 2): String {
        val text = number(abs(value), decimals)
        return when {
            value > 0 -> "+$text"
            value < 0 -> "−$text"
            else -> text
        }
    }

    fun value(value: Double, unit: String, decimals: Int = 1): String = "${number(value, decimals)}$SPACE$unit"

    fun optional(value: Double?, unit: String, decimals: Int = 1): String =
        if (value == null) (if (isSpanish) "Sin dato" else "No data") else value(value, unit, decimals)

    private fun pattern(pattern: String) = DateTimeFormatter.ofPattern(pattern, locale)

    fun hour(instant: Instant, zone: ZoneId = ZoneId.systemDefault()): String = pattern("HH:mm").format(instant.atZone(zone))

    fun dayMonth(day: LocalDate): String = pattern("d MMM").format(day).replace(".", "")

    fun dayMonthHour(instant: Instant, zone: ZoneId = ZoneId.systemDefault()): String =
        "${dayMonth(instant.atZone(zone).toLocalDate())}, ${hour(instant, zone)}"

    fun monthYear(day: LocalDate): String = pattern("MMM yyyy").format(day).replace(".", "")

    fun monthShort(day: LocalDate): String = pattern("MMM").format(day).replace(".", "")

    fun weekday(day: LocalDate): String = pattern("EEE").format(day).replace(".", "")

    /** "SAIH Tajo · 8 nov, 15:00" */
    fun saihSource(instant: Instant): String = "SAIH Tajo · ${dayMonthHour(instant)}"

    /** "MITECO · semana del 3 nov" */
    fun mitecoWeek(day: LocalDate): String =
        if (isSpanish) "MITECO · semana del ${dayMonth(day)}" else "MITECO · week of ${dayMonth(day)}"

    /** 16-point compass name for a direction in degrees. */
    fun compass(degrees: Double): String {
        val names = if (isSpanish) {
            listOf("N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO")
        } else {
            listOf("N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW")
        }
        val normalised = ((degrees % 360) + 360) % 360
        return names[(normalised / 22.5).roundToInt() % names.size]
    }
}

enum class Trend(private val spanish: String, private val english: String, val arrow: String) {
    Rising("Subiendo", "Rising", "↗"),
    Falling("Bajando", "Falling", "↘"),
    Steady("Estable", "Steady", "→");

    val label: String get() = if (Format.isSpanish) spanish else english

    companion object {
        /** Wind moves the gauge by around ±0.1 hm³ in a day, so smaller changes aren't real movement. */
        private const val THRESHOLD = 0.2

        fun of(change: Double): Trend = when {
            change > THRESHOLD -> Rising
            change < -THRESHOLD -> Falling
            else -> Steady
        }

        /** "Estable · −0,15 hm³ en 24 h" */
        fun sentence(change: Double): String {
            val amount = "${Format.signed(change)}${Format.SPACE}hm³"
            return "${of(change).label} · " + if (Format.isSpanish) "$amount en 24 h" else "$amount in 24 h"
        }
    }
}
