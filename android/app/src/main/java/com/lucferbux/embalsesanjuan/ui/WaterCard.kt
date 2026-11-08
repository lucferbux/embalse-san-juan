package com.lucferbux.embalsesanjuan.ui

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lucferbux.embalsesanjuan.R
import com.lucferbux.embalsesanjuan.data.Format
import com.lucferbux.embalsesanjuan.data.ReservoirReading
import com.lucferbux.embalsesanjuan.data.Trend
import com.lucferbux.embalsesanjuan.data.YearSurface
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

enum class CardMode { Today, Year }

/** The water's own colours: fixed, like the data they show. Everything around them follows the wallpaper. */
object Water {
    fun top(percent: Double): Color {
        val empty = 1f - (percent / 100).toFloat().coerceIn(0f, 1f)
        return Color(0.05f + empty * 0.03f, 0.40f + empty * 0.10f, 0.74f - empty * 0.12f)
    }

    fun bottom(percent: Double): Color {
        val empty = 1f - (percent / 100).toFloat().coerceIn(0f, 1f)
        return Color(0.01f, 0.17f + empty * 0.08f, 0.47f - empty * 0.08f)
    }

    fun brush(percent: Double) = Brush.verticalGradient(listOf(top(percent), bottom(percent)))

    val crest = Color(0xFF8FD0FF)
    val back = Color(0x735CB3FC)
    val lastYear = Color(0xFFCC994D)
}

/** Clearance between any text and the highest crest of the waterline. */
private val Clearance = 12.dp

/** Where the figure block goes: wholly in the water, in white, or wholly in the sky. Never across the waterline. */
sealed interface Placement {
    data class InWater(val top: Float) : Placement
    data class InSky(val bottom: Float) : Placement

    companion object {
        fun decide(height: Float, percent: Double, amplitude: Float, clearance: Float, block: Float, bottomInset: Float): Placement {
            val waterline = height * (1 - (percent / 100).coerceIn(0.0, 1.0)).toFloat()
            val top = waterline + amplitude + clearance
            return if (top + block <= height - bottomInset) InWater(top) else InSky(max(waterline - amplitude - clearance, 0f))
        }
    }
}

/**
 * The water card (docs/design/review-2.0/SYNTHESIS.md): it opens on today's level with moving water; "Año" turns the
 * same surface into the last 12 months of SAIH, with last year and the range of the four years before behind it.
 */
@Composable
fun WaterCard(
    reading: ReservoirReading,
    capacityHm3: Double,
    trendHm3: Double?,
    surface: YearSurface?,
    mode: CardMode,
    onModeChange: (CardMode) -> Unit,
    modifier: Modifier = Modifier,
    figureSize: TextUnit = 64.sp,
    shape: Shape = RoundedCornerShape(36.dp),
) {
    val large = LocalDensity.current.fontScale >= 1.6f
    val showsYear = mode == CardMode.Year && surface != null
    val progress by animateFloatAsState(if (showsYear) 1f else 0f, tween(900), label = "year")
    val phase by rememberInfiniteTransition(label = "water").animateFloat(
        0f, 2 * PI.toFloat(), infiniteRepeatable(tween(6000, easing = LinearEasing), RepeatMode.Restart), label = "phase",
    )
    val sky = Brush.verticalGradient(listOf(MaterialTheme.colorScheme.surfaceContainerHigh, MaterialTheme.colorScheme.surfaceContainerLow))
    val description = listOfNotNull(
        reading.id.displayName, Format.percent(reading.percent), Format.volumeOfCapacity(reading.volumeHm3, capacityHm3),
        trendHm3?.let(Trend::sentence), Format.saihSource(reading.observedAt),
    ).joinToString(", ")

    if (large) {
        // At the largest text sizes the block can't fit in or above the water: the water keeps the top and the block
        // goes in full below it, in the label colour.
        Column(modifier.clip(shape).background(sky).padding(bottom = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Controls(surface != null, showsYear, mode, onModeChange, stacked = true)
            Box(Modifier.fillMaxWidth().height(200.dp).padding(horizontal = 10.dp).clip(RoundedCornerShape(26.dp))) {
                CardSurface(reading.percent, surface, progress, phase, topPad = 16.dp, months = false)
            }
            FigureBlock(reading, capacityHm3, if (showsYear) null else trendHm3, onWater = false, figureSize = figureSize,
                modifier = Modifier.padding(horizontal = 20.dp).semantics { contentDescription = description })
        }
        return
    }

    Box(modifier.clip(shape).background(sky)) {
        CardSurface(reading.percent, surface, progress, phase, topPad = TopPad, months = showsYear)
        PlacedFigure(reading, capacityHm3, if (showsYear) null else trendHm3, surface, showsYear, figureSize, description)
        Controls(surface != null, showsYear, mode, onModeChange, stacked = false)
    }
}

private val TopPad = 64.dp
private val Amplitude = 6.dp

@Composable
private fun Controls(hasYear: Boolean, showsYear: Boolean, mode: CardMode, onModeChange: (CardMode) -> Unit, stacked: Boolean) {
    val legend = @Composable {
        Column {
            Text(stringResource(R.string.card_legend_title), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(14.dp, 2.dp).background(Water.lastYear))
                Text(stringResource(R.string.card_legend_last_year), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Box(Modifier.size(12.dp, 9.dp).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.18f)))
                Text(stringResource(R.string.card_legend_range), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
    val switch = @Composable {
        if (hasYear) {
            SingleChoiceSegmentedButtonRow(Modifier.widthIn(max = 200.dp)) {
                CardMode.entries.forEachIndexed { index, option ->
                    SegmentedButton(
                        selected = mode == option,
                        onClick = { onModeChange(option) },
                        shape = SegmentedButtonDefaults.itemShape(index, CardMode.entries.size),
                        icon = {},
                        label = { Text(stringResource(if (option == CardMode.Today) R.string.card_today else R.string.card_year), maxLines = 1) },
                    )
                }
            }
        }
    }
    if (stacked) {
        Column(Modifier.padding(horizontal = 14.dp).padding(top = 14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            switch()
            if (showsYear) legend()
        }
    } else {
        Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp).padding(top = 12.dp), verticalAlignment = Alignment.Top) {
            // The legend takes what's left and wraps, so it never runs under the switch.
            Box(Modifier.weight(1f).padding(end = 8.dp)) { if (showsYear) legend() }
            switch()
        }
    }
}

/** The percentage, "64,3 hm³ de 138 hm³", the trend and the source, read as one sentence. */
@Composable
fun FigureBlock(
    reading: ReservoirReading,
    capacityHm3: Double,
    trendHm3: Double?,
    onWater: Boolean,
    figureSize: TextUnit,
    modifier: Modifier = Modifier,
) {
    val color = if (onWater) Color.White else MaterialTheme.colorScheme.onSurface
    Column(modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(Format.percent(reading.percent), color = color, fontSize = figureSize, fontWeight = FontWeight.ExtraBold, maxLines = 1, lineHeight = figureSize)
        Text(Format.volumeOfCapacity(reading.volumeHm3, capacityHm3), color = color, style = MaterialTheme.typography.titleMedium)
        trendHm3?.let {
            Text("${Trend.of(it).arrow}  ${Trend.sentence(it)}", color = color.copy(alpha = 0.92f), style = MaterialTheme.typography.bodyMedium)
        }
        Text(Format.saihSource(reading.observedAt), color = color.copy(alpha = 0.8f), style = MaterialTheme.typography.bodySmall)
    }
}

/** Measures the block, decides where it goes from the water under it, then draws it in the right colour. */
@Composable
private fun PlacedFigure(
    reading: ReservoirReading,
    capacityHm3: Double,
    trendHm3: Double?,
    surface: YearSurface?,
    showsYear: Boolean,
    figureSize: TextUnit,
    description: String,
) {
    SubcomposeLayout(Modifier.fillMaxSize()) { constraints ->
        val side = 20.dp.roundToPx()
        val loose = Constraints(maxWidth = (constraints.maxWidth - side * 2).coerceAtLeast(0))
        val probe = subcompose("probe") { FigureBlock(reading, capacityHm3, trendHm3, true, figureSize) }.first().measure(loose)
        val topPad = TopPad.toPx()
        val usable = constraints.maxHeight - topPad
        // The shallowest water under the block: today's level, or the lowest point of the year under its width.
        val level = if (showsYear && surface != null) {
            val share = ((probe.width + side * 2f) / constraints.maxWidth).coerceIn(0f, 1f)
            surface.levels.take((surface.levels.lastIndex * share).toInt() + 2).min()
        } else reading.percent / 100
        val placement = Placement.decide(
            usable, level * 100, Amplitude.toPx() * 1.45f, Clearance.toPx(), probe.height.toFloat(),
            bottomInset = (if (showsYear) 30.dp else 14.dp).toPx(),
        )
        val block = subcompose("block") {
            FigureBlock(reading, capacityHm3, trendHm3, placement is Placement.InWater, figureSize,
                Modifier.semantics { contentDescription = description })
        }.first().measure(loose)
        val y = when (placement) {
            is Placement.InWater -> topPad + placement.top
            // Never above the switch's band, even when the sky is short.
            is Placement.InSky -> max(topPad + placement.bottom - block.height, topPad)
        }
        layout(constraints.maxWidth, constraints.maxHeight) { block.place(side, y.toInt()) }
    }
}

/** The sky's extras, the water morphing from today's wave to the year, and the year's marks. */
@Composable
private fun CardSurface(percent: Double, surface: YearSurface?, progress: Float, phase: Float, topPad: androidx.compose.ui.unit.Dp, months: Boolean) {
    val measurer = rememberTextMeasurer()
    val band = MaterialTheme.colorScheme.primary.copy(alpha = 0.16f)
    val secondary = MaterialTheme.colorScheme.onSurfaceVariant
    val labelStyle = MaterialTheme.typography.labelSmall
    val todayLabel = stringResource(R.string.card_today).lowercase(Format.locale)
    Canvas(Modifier.fillMaxSize()) {
        val pad = topPad.toPx()
        val usable = size.height - pad
        fun y(fraction: Double) = pad + usable * (1 - fraction.coerceIn(0.0, 1.02)).toFloat()
        val eased = progress * progress * (3 - 2 * progress)
        val amplitude = Amplitude.toPx()
        val level = (percent / 100)
        val crest = surface?.levels.orEmpty()

        if (surface != null && eased > 0f) {
            surface.band?.takeIf { it.size > 1 }?.let { ranges ->
                val path = Path()
                ranges.forEachIndexed { index, range ->
                    val x = size.width * index / ranges.lastIndex
                    if (index == 0) path.moveTo(x, y(range.endInclusive)) else path.lineTo(x, y(range.endInclusive))
                }
                ranges.indices.reversed().forEach { index -> path.lineTo(size.width * index / ranges.lastIndex, y(ranges[index].start)) }
                path.close()
                drawPath(path, band, alpha = eased)
            }
            surface.record?.let {
                drawLine(secondary.copy(alpha = 0.6f * eased), Offset(0f, y(it)), Offset(size.width, y(it)), 1.dp.toPx(),
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 8f)))
            }
        }

        val samples = 96
        val points = (0 until samples).map { index ->
            val u = index.toFloat() / (samples - 1)
            val wave = y(level) + amplitude * sin(u * 2 * PI.toFloat() * 1.2f + phase) + amplitude * 0.45f * sin(u * 2 * PI.toFloat() * 2.6f - phase * 1.3f)
            val target = if (crest.size > 1) {
                val position = u * crest.lastIndex
                val lower = position.toInt().coerceAtMost(crest.lastIndex)
                val upper = min(lower + 1, crest.lastIndex)
                y(crest[lower] + (crest[upper] - crest[lower]) * (position - lower))
            } else wave
            Offset(size.width * u, wave + (target - wave) * eased)
        }
        if (eased < 1f) {
            val back = Path().apply {
                moveTo(0f, size.height)
                (0 until samples).forEach { index ->
                    val u = index.toFloat() / (samples - 1)
                    lineTo(size.width * u, y(level) - 3.dp.toPx() + amplitude * 0.8f * sin(u * 2 * PI.toFloat() + phase + 2.1f))
                }
                lineTo(size.width, size.height)
                close()
            }
            drawPath(back, Water.back, alpha = 1f - eased)
        }
        val line = Path().apply { points.forEachIndexed { index, point -> if (index == 0) moveTo(point.x, point.y) else lineTo(point.x, point.y) } }
        val area = Path().apply {
            addPath(line)
            lineTo(size.width, size.height)
            lineTo(0f, size.height)
            close()
        }
        drawPath(area, Water.brush(percent))
        drawPath(line, Water.crest, style = Stroke(2.dp.toPx(), join = StrokeJoin.Round))

        if (surface != null && eased > 0f) {
            surface.lastYear?.takeIf { it.size > 1 }?.let { values ->
                val path = Path()
                values.forEachIndexed { index, value ->
                    val x = size.width * index / values.lastIndex
                    if (index == 0) path.moveTo(x, y(value)) else path.lineTo(x, y(value))
                }
                drawPath(path, Water.lastYear.copy(alpha = eased), style = Stroke(1.6.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(14f, 10f))))
            }
            val today = Offset(size.width - 7.dp.toPx(), y(crest.lastOrNull() ?: level))
            drawLine(Color.White.copy(alpha = 0.5f * eased), today, Offset(today.x, size.height), 1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f, 8f)))
            drawCircle(Color.White.copy(alpha = eased), 5.5.dp.toPx(), today)
            drawCircle(Water.top(percent).copy(alpha = eased), 5.5.dp.toPx(), today, style = Stroke(2.5.dp.toPx()))
            val text = measurer.measure(todayLabel, labelStyle.copy(color = secondary.copy(alpha = eased), fontWeight = FontWeight.SemiBold))
            drawText(text, topLeft = Offset(today.x - text.size.width - 6.dp.toPx(), today.y - text.size.height - 8.dp.toPx()))
            if (months) drawMonths(surface, measurer, labelStyle, eased)
        }
    }
}

private fun DrawScope.drawMonths(surface: YearSurface, measurer: androidx.compose.ui.text.TextMeasurer, style: androidx.compose.ui.text.TextStyle, alpha: Float) {
    var previous = surface.date(0).monthValue
    for (index in 1..surface.levels.lastIndex) {
        val day = surface.date(index)
        if (day.monthValue != previous && day.monthValue % 2 == 1) {
            val x = size.width * index / surface.levels.lastIndex
            if (x > 8.dp.toPx() && x < size.width - 30.dp.toPx()) {
                val text = measurer.measure(Format.monthShort(day), style.copy(color = Color.White.copy(alpha = 0.65f * alpha)))
                drawText(text, topLeft = Offset(x + 4.dp.toPx(), size.height - text.size.height - 6.dp.toPx()))
            }
        }
        previous = day.monthValue
    }
}

/** The card collapsed while scrolling: the figure and the trend on a strip of water. */
@Composable
fun WaterStrip(reading: ReservoirReading, trendHm3: Double?, modifier: Modifier = Modifier) {
    Row(
        modifier
            .clip(RoundedCornerShape(28.dp))
            .background(Water.brush(reading.percent))
            .padding(horizontal = 18.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(Format.percent(reading.percent), color = Color.White, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.ExtraBold)
        Column(Modifier.weight(1f)) {
            trendHm3?.let { Text(Trend.sentence(it), color = Color.White, style = MaterialTheme.typography.labelLarge, maxLines = 1) }
            Text(Format.saihSource(reading.observedAt), color = Color.White.copy(alpha = 0.8f), style = MaterialTheme.typography.labelSmall, maxLines = 1)
        }
        Spacer(Modifier.width(0.dp))
    }
}
