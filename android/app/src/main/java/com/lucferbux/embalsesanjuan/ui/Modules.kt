package com.lucferbux.embalsesanjuan.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Height
import androidx.compose.material.icons.outlined.Route
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Thermostat
import androidx.compose.material.icons.outlined.WaterDrop
import androidx.compose.material.icons.outlined.Umbrella
import androidx.compose.material.icons.outlined.WbCloudy
import androidx.compose.material.icons.outlined.WbSunny
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lucferbux.embalsesanjuan.R
import com.lucferbux.embalsesanjuan.data.Format
import com.lucferbux.embalsesanjuan.data.ReservoirId
import com.lucferbux.embalsesanjuan.data.ReservoirReading
import com.lucferbux.embalsesanjuan.data.Snapshot
import com.lucferbux.embalsesanjuan.data.Trend
import java.time.Instant
import kotlin.math.PI
import kotlin.math.sin

/** What a module opens: the full panel it summarises. */
enum class NowDetail { Recent, Outflow, Weather, Miteco }

/**
 * The modules under the water card. Each has a single source (SAIH, MITECO or AEMET) with its date, and most open
 * their full panel. Two columns on a phone, one at the largest text sizes.
 */
@Composable
fun Modules(
    snapshot: Snapshot,
    columns: Int,
    onOpenDetail: (NowDetail) -> Unit,
    onOpenReservoir: (ReservoirId) -> Unit,
    modifier: Modifier = Modifier,
) {
    val saih = Format.saihSource(Instant.parse(snapshot.live.observedAt))
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        TwoUp(columns, { Outflow(snapshot, saih, it) { onOpenDetail(NowDetail.Outflow) } }, { Miteco(snapshot, it) { onOpenDetail(NowDetail.Miteco) } })
        Recent(snapshot, saih) { onOpenDetail(NowDetail.Recent) }
        snapshot.forecast?.let { ForecastModule(it) }
        TwoUp(columns, { Weather(snapshot, it) { onOpenDetail(NowDetail.Weather) } }, { Elevation(snapshot, saih, it) { onOpenDetail(NowDetail.Recent) } })
        River(snapshot, onOpenReservoir)
    }
}

@Composable
private fun TwoUp(columns: Int, first: @Composable (Modifier) -> Unit, second: @Composable (Modifier) -> Unit) {
    if (columns >= 2) {
        Row(Modifier.fillMaxWidth().height(IntrinsicSize.Max), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            first(Modifier.weight(1f).fillMaxHeight())
            second(Modifier.weight(1f).fillMaxHeight())
        }
    } else {
        first(Modifier.fillMaxWidth())
        second(Modifier.fillMaxWidth())
    }
}

/** One module: a title with its symbol, the content, and the source at the bottom. */
@Composable
fun ModuleTile(
    title: String,
    icon: ImageVector,
    source: String,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    Card(
        onClick = onClick ?: {},
        enabled = onClick != null,
        shape = RoundedCornerShape(28.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            disabledContainerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            disabledContentColor = MaterialTheme.colorScheme.onSurface,
        ),
        modifier = modifier,
    ) {
        Column(Modifier.padding(16.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
                Text(title, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(start = 8.dp).weight(1f))
                if (onClick != null) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MaterialTheme.colorScheme.outline)
            }
            content()
            Spacer(Modifier.weight(1f, fill = false))
            Text(source, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun Figure(text: String) {
    Text(text, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
}

@Composable
private fun Detail(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
private fun Outflow(snapshot: Snapshot, source: String, modifier: Modifier, onClick: () -> Unit) {
    ModuleTile(stringResource(R.string.module_outflow), Icons.Outlined.WaterDrop, source, modifier, onClick) {
        Figure(Format.optional(snapshot.live.outflowM3s, "m³/s", 2))
        val readings = snapshot.recent.filter { it.outflowM3s != null }
        if (readings.size > 1) {
            StepChart(readings.map { it.outflowM3s!! }, Modifier.fillMaxWidth().height(40.dp))
            val peak = readings.maxBy { it.outflowM3s!! }
            if (peak.outflowM3s!! >= 2 * maxOf(snapshot.live.outflowM3s ?: 0.0, 0.5)) {
                Detail(stringResource(R.string.module_outflow_peak, Format.value(peak.outflowM3s, "m³/s"), Format.hour(peak.instant)))
            }
        }
    }
}

@Composable
private fun Miteco(snapshot: Snapshot, modifier: Modifier, onClick: () -> Unit) {
    val weekly = snapshot.weekly
    ModuleTile(stringResource(R.string.module_weekly), Icons.Outlined.CalendarMonth, Format.mitecoWeek(weekly.day), modifier, onClick) {
        Figure(Format.percent(weekly.percent))
        Detail(stringResource(R.string.module_weekly_change, Format.hm3(weekly.volumeHm3, 0), Format.signed(weekly.changeHm3, 0)))
        weekly.tenYearAvgHm3?.let { Detail(stringResource(R.string.module_weekly_average, Format.hm3(it))) }
    }
}

@Composable
private fun Recent(snapshot: Snapshot, source: String, onClick: () -> Unit) {
    ModuleTile(stringResource(R.string.module_recent), Icons.Outlined.Schedule, source, Modifier.fillMaxWidth(), onClick) {
        Text("${Trend.of(snapshot.live.trend24hHm3).arrow}  ${Trend.sentence(snapshot.live.trend24hHm3)}", style = MaterialTheme.typography.titleSmall)
        RecentChart(snapshot, Modifier.fillMaxWidth().height(110.dp))
    }
}

@Composable
fun RecentChart(snapshot: Snapshot, modifier: Modifier) {
    val points = snapshot.recent.map { ChartPoint(it.instant.epochSecond.toFloat(), it.volumeHm3.toFloat()) }
    LineChart(
        points = points,
        description = stringResource(R.string.chart_recent, Format.hm3(snapshot.recent.first().volumeHm3), Format.hm3(snapshot.recent.last().volumeHm3)),
        yLabel = { Format.number(it.toDouble()) },
        xLabels = snapshot.recent.filterIndexed { index, _ -> index % 6 == 0 }.map { it.instant.epochSecond.toFloat() to Format.hour(it.instant) },
        modifier = modifier,
    )
}

@Composable
private fun ForecastModule(forecast: com.lucferbux.embalsesanjuan.data.Forecast) {
    ModuleTile(
        stringResource(R.string.module_forecast), Icons.Outlined.WbCloudy,
        stringResource(R.string.module_forecast_source, Format.dayMonthHour(Instant.parse(forecast.issuedAt))),
        Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            forecast.days.take(7).forEach { day ->
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(Format.weekday(day.day), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold)
                    Icon(
                        if ((day.rainProbabilityPct ?: 0.0) >= 50) Icons.Outlined.Umbrella else Icons.Outlined.WbSunny,
                        contentDescription = null,
                        tint = if ((day.rainProbabilityPct ?: 0.0) >= 50) MaterialTheme.colorScheme.primary else Color(0xFFE3A21A),
                        modifier = Modifier.size(22.dp),
                    )
                    Text(day.rainProbabilityPct?.let { Format.value(it, "%", 0) } ?: "—", style = MaterialTheme.typography.labelMedium)
                    day.maxTemperatureC?.let { Text("${Format.number(it, 0)}°", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                }
            }
        }
        Detail(stringResource(R.string.module_forecast_note))
    }
}

@Composable
private fun Weather(snapshot: Snapshot, modifier: Modifier, onClick: () -> Unit) {
    val weather = snapshot.weather
    ModuleTile(stringResource(R.string.module_weather), Icons.Outlined.Thermostat, Format.saihSource(Instant.parse(weather.observedAt)), modifier, onClick) {
        Figure(Format.optional(weather.temperatureC, "°C", 0))
        Detail(stringResource(R.string.module_weather_humidity, Format.optional(weather.humidityPct, "%", 0)))
        Detail(stringResource(R.string.module_weather_rain, Format.optional(weather.rain24hMm, "mm")))
    }
}

@Composable
private fun Elevation(snapshot: Snapshot, source: String, modifier: Modifier, onClick: () -> Unit) {
    ModuleTile(stringResource(R.string.module_elevation), Icons.Outlined.Height, source, modifier, onClick) {
        Figure(Format.optional(snapshot.live.elevationM, "m", 2))
        Detail(stringResource(R.string.module_elevation_level, Format.optional(snapshot.live.levelM, "m", 2)))
        Detail(stringResource(R.string.module_elevation_transfer, Format.optional(snapshot.live.transferM3s, "m³/s", 2)))
    }
}

@Composable
private fun River(snapshot: Snapshot, onOpenReservoir: (ReservoirId) -> Unit) {
    ModuleTile(stringResource(R.string.module_river), Icons.Outlined.Route, "SAIH Tajo", Modifier.fillMaxWidth()) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            snapshot.chain.forEach { reading ->
                Tank(reading, isCurrent = reading.id == ReservoirId.SanJuan, height = 72.dp,
                    modifier = Modifier.weight(1f).clickable { onOpenReservoir(reading.id) })
            }
        }
    }
}

/** A reservoir as a small tank at its own level, with its name, percentage and SAIH time. */
@Composable
fun Tank(reading: ReservoirReading, isCurrent: Boolean, height: androidx.compose.ui.unit.Dp, modifier: Modifier = Modifier, details: Boolean = true) {
    val sky = MaterialTheme.colorScheme.surfaceContainerHighest
    val outline = MaterialTheme.colorScheme.outline
    Column(modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(height)
                .clip(RoundedCornerShape(16.dp))
                .background(sky)
                .then(if (isCurrent) Modifier.border(2.dp, outline, RoundedCornerShape(16.dp)) else Modifier),
        ) {
            Canvas(Modifier.fillMaxSize()) {
                val level = (reading.percent / 100).toFloat().coerceIn(0f, 1f)
                val baseline = size.height * (1 - level)
                val path = Path().apply {
                    moveTo(0f, size.height)
                    var x = 0f
                    while (x <= size.width) {
                        lineTo(x, baseline + sin(x / size.width * 2 * PI.toFloat() + 0.6f) * 2.5.dp.toPx())
                        x += 3f
                    }
                    lineTo(size.width, size.height)
                    close()
                }
                drawPath(path, Water.brush(reading.percent))
            }
        }
        if (details) {
            Text(reading.id.displayName, style = MaterialTheme.typography.labelLarge, fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.SemiBold, maxLines = 1)
            Text(Format.percent(reading.percent), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(Format.hour(reading.observedAt), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/** A small step chart for the outflow, from zero. */
@Composable
fun StepChart(values: List<Double>, modifier: Modifier) {
    val color = MaterialTheme.colorScheme.primary
    Canvas(modifier) {
        val high = (values.maxOrNull() ?: 1.0).coerceAtLeast(1.0)
        fun x(index: Int) = size.width * index / values.lastIndex
        fun y(value: Double) = size.height * (1 - value / high).toFloat()
        val line = Path().apply {
            moveTo(0f, y(values.first()))
            values.forEachIndexed { index, value -> if (index > 0) { lineTo(x(index), y(values[index - 1])); lineTo(x(index), y(value)) } }
        }
        val area = Path().apply { addPath(line); lineTo(size.width, size.height); lineTo(0f, size.height); close() }
        drawPath(area, color.copy(alpha = 0.18f))
        drawPath(line, color, style = Stroke(1.8.dp.toPx()))
    }
}
