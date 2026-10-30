package com.lucferbux.embalsesanjuan.ui

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import kotlin.math.PI
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.pow
import kotlin.math.sin

/** The water, or with `above` the air over it. `level` is the fraction of the height that is full. */
fun wavePath(size: Size, level: Float, phase: Float, amplitude: Float, above: Boolean = false): Path = Path().apply {
    val baseline = size.height * (1f - level.coerceIn(0f, 1f))
    val closingY = if (above) 0f else size.height
    moveTo(0f, closingY)
    var x = 0f
    while (x <= size.width) {
        lineTo(x, baseline + sin(x / size.width * 2 * PI.toFloat() + phase) * amplitude)
        x += 4f
    }
    lineTo(size.width, baseline + sin(2 * PI.toFloat() + phase) * amplitude)
    lineTo(size.width, closingY)
    close()
}

/** Moving water, with text that stays readable as it crosses the waterline. */
@Composable
fun WaterHero(percent: Double, modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    val level = (percent / 100).toFloat()
    val colors = MaterialTheme.colorScheme
    val phase by rememberInfiniteTransition(label = "water").animateFloat(
        initialValue = 0f,
        targetValue = 2 * PI.toFloat(),
        animationSpec = infiniteRepeatable(tween(6000, easing = LinearEasing), RepeatMode.Restart),
        label = "phase",
    )
    val amplitudeDp = 7.dp

    Box(modifier.clip(MaterialTheme.shapes.extraLarge)) {
        Canvas(Modifier.fillMaxSize()) {
            val amplitude = amplitudeDp.toPx()
            drawRect(colors.primaryContainer)
            drawPath(wavePath(size, level, phase + 2.1f, amplitude), colors.primary.copy(alpha = 0.35f))
            drawPath(wavePath(size, level, phase, amplitude), colors.primary)
        }
        Box(
            Modifier
                .fillMaxSize()
                .drawWithContent {
                    clipPath(wavePath(size, level, phase, amplitudeDp.toPx(), above = true)) {
                        this@drawWithContent.drawContent()
                    }
                },
        ) {
            androidx.compose.runtime.CompositionLocalProvider(
                androidx.compose.material3.LocalContentColor provides colors.onPrimaryContainer,
            ) { content() }
        }
        Box(
            Modifier
                .fillMaxSize()
                .drawWithContent {
                    clipPath(wavePath(size, level, phase, amplitudeDp.toPx())) {
                        this@drawWithContent.drawContent()
                    }
                },
        ) {
            androidx.compose.runtime.CompositionLocalProvider(
                androidx.compose.material3.LocalContentColor provides colors.onPrimary,
            ) { content() }
        }
    }
}

data class ChartPoint(val x: Float, val y: Float)

/** About three axis values at a round step (1, 2 or 5 times a power of ten), inside the range. */
fun roundTicks(low: Float, high: Float): List<Float> {
    val rough = (high - low) / 3f
    val power = 10f.pow(floor(log10(rough)))
    // A step a little under the rough one still counts, or 151 would get only two values, 0 and 100.
    val step = listOf(1f, 2f, 5f, 10f).first { it * power >= rough * 0.8f } * power
    return generateSequence(ceil(low / step)) { it + 1f }
        .takeWhile { it * step <= high }
        .map { it * step }
        .toList()
}

/** A simple line chart, with an area below it and labels drawn in the theme's colours. */
@Composable
fun LineChart(
    points: List<ChartPoint>,
    description: String,
    modifier: Modifier = Modifier,
    yLabel: (Float) -> String,
    xLabels: List<Pair<Float, String>> = emptyList(),
    yMin: Float? = null,
    yMax: Float? = null,
    reference: Pair<Float, String>? = null,
    stepped: Boolean = false,
) {
    if (points.size < 2) return
    val colors = MaterialTheme.colorScheme
    val measurer = rememberTextMeasurer()
    val labelStyle = MaterialTheme.typography.labelSmall.copy(color = colors.onSurfaceVariant)

    val minX = points.minOf { it.x }
    val maxX = points.maxOf { it.x }
    val dataMin = points.minOf { it.y }
    val dataMax = points.maxOf { it.y }
    val margin = ((dataMax - dataMin) * 0.2f).coerceAtLeast(0.02f)
    val low = yMin ?: (dataMin - margin)
    val high = yMax ?: (dataMax + margin)

    Canvas(modifier.semantics { contentDescription = description }) {
        val labelWidth = 44.dp.toPx()
        val labelHeight = if (xLabels.isEmpty()) 0f else 20.dp.toPx()
        val plot = Size(size.width - labelWidth, size.height - labelHeight)
        fun xOf(value: Float) = (value - minX) / (maxX - minX).coerceAtLeast(0.0001f) * plot.width
        fun yOf(value: Float) = plot.height - (value - low) / (high - low).coerceAtLeast(0.0001f) * plot.height

        roundTicks(low, high).forEach { value ->
            val y = yOf(value)
            drawLine(colors.outlineVariant, Offset(0f, y), Offset(plot.width, y), strokeWidth = 1.dp.toPx())
            val text = measurer.measure(yLabel(value), labelStyle)
            drawText(text, topLeft = Offset(plot.width + 6.dp.toPx(), y - text.size.height / 2f))
        }

        xLabels.forEach { (value, label) ->
            val text = measurer.measure(label, labelStyle)
            val x = (xOf(value) - text.size.width / 2f).coerceIn(0f, size.width - text.size.width)
            drawText(text, topLeft = Offset(x, plot.height + 4.dp.toPx()))
        }

        val line = Path()
        points.forEachIndexed { index, point ->
            val x = xOf(point.x)
            val y = yOf(point.y)
            when {
                index == 0 -> line.moveTo(x, y)
                stepped -> {
                    line.lineTo(x, yOf(points[index - 1].y))
                    line.lineTo(x, y)
                }
                else -> line.lineTo(x, y)
            }
        }
        val area = Path().apply {
            addPath(line)
            lineTo(xOf(points.last().x), plot.height)
            lineTo(xOf(points.first().x), plot.height)
            close()
        }
        drawPath(area, Brush.verticalGradient(listOf(colors.primary.copy(alpha = 0.28f), Color.Transparent), endY = plot.height))
        drawPath(line, colors.primary, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))

        reference?.let { (value, label) ->
            val y = yOf(value)
            drawLine(
                colors.onSurfaceVariant,
                Offset(0f, y),
                Offset(plot.width, y),
                strokeWidth = 1.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 10f)),
            )
            val text = measurer.measure(label, TextStyle(color = colors.onSurfaceVariant, fontSize = labelStyle.fontSize))
            drawText(text, topLeft = Offset(plot.width - text.size.width, y - text.size.height - 2.dp.toPx()))
        }
    }
}

/** A titled card, the app's section. */
@Composable
fun SectionCard(
    title: String?,
    modifier: Modifier = Modifier,
    footer: String? = null,
    content: @Composable () -> Unit,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        title?.let {
            Text(
                it,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }
        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
            shape = MaterialTheme.shapes.extraLarge,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column(Modifier.padding(vertical = 8.dp)) { content() }
        }
        footer?.let {
            Text(
                it,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }
    }
}

/** One label and value, the most common row. */
@Composable
fun ValueRow(label: String, value: String, icon: ImageVector? = null) {
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        icon?.let {
            Icon(it, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(14.dp))
        }
        Text(label, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Spacer(Modifier.width(12.dp))
        Text(value, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
