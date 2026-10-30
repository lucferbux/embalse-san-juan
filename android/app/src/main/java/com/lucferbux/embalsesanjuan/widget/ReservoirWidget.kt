package com.lucferbux.embalsesanjuan.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.lucferbux.embalsesanjuan.EmbalseApplication
import com.lucferbux.embalsesanjuan.MainActivity
import com.lucferbux.embalsesanjuan.data.DailyPoint
import com.lucferbux.embalsesanjuan.data.Format
import com.lucferbux.embalsesanjuan.data.Snapshot
import com.lucferbux.embalsesanjuan.data.Trend
import java.io.IOException
import java.time.Instant
import java.util.concurrent.TimeUnit
import kotlin.math.PI
import kotlin.math.sin

private val White = ColorProvider(androidx.compose.ui.graphics.Color.White)
private val SoftWhite = ColorProvider(androidx.compose.ui.graphics.Color.White.copy(alpha = 0.8f))

private val SmallSize = DpSize(110.dp, 110.dp)
private val MediumSize = DpSize(250.dp, 110.dp)
private val LargeSize = DpSize(250.dp, 250.dp)

/**
 * One surface: the water fills the whole widget and all the text is white, so it reads the same above
 * and below the waterline. Glance can't draw freely, so the water and the curve are a bitmap.
 */
class ReservoirWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(SmallSize, MediumSize, LargeSize))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val repository = (context.applicationContext as EmbalseApplication).repository
        // A widget placed before the app was ever opened still has something to show.
        val snapshot = repository.cached() ?: runCatching { repository.load().first }.getOrNull()
        provideContent { Content(snapshot) }
    }

    @Composable
    private fun Content(snapshot: Snapshot?) {
        val context = LocalContext.current
        val size = LocalSize.current
        val modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(24.dp)
            .clickable(actionStartActivity<MainActivity>())
        if (snapshot == null) {
            val sky = androidx.compose.ui.graphics.Color(WidgetColors.resolve(context).sky)
            Box(modifier.background(ColorProvider(sky)), contentAlignment = Alignment.Center) {
                Text("Abre la app para cargar los datos", style = TextStyle(color = White), modifier = GlanceModifier.padding(16.dp))
            }
            return
        }
        val isWide = size.width >= MediumSize.width
        val isTall = size.height >= LargeSize.height
        val chartDays = if (isTall) 90 else 30
        val chart = when {
            isWide && isTall -> ChartArea(0.06f, 0.42f, 0.84f, 0.32f)
            isWide -> ChartArea(0.52f, 0.24f, 0.40f, 0.34f)
            else -> null
        }
        Box(modifier) {
            Image(
                provider = ImageProvider(sceneBitmap(context, size.width.value, size.height.value, snapshot, chart, chartDays)),
                contentDescription = "Embalse de ${snapshot.reservoir.name} al ${Format.percent(snapshot.live.percent)}",
                contentScale = ContentScale.FillBounds,
                modifier = GlanceModifier.fillMaxSize(),
            )
            when {
                isWide && isTall -> Large(snapshot)
                isWide -> Medium(snapshot)
                else -> Small(snapshot)
            }
        }
    }

    @Composable
    private fun Header(snapshot: Snapshot) {
        val observedAt = Instant.parse(snapshot.live.observedAt)
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                snapshot.reservoir.name,
                maxLines = 1,
                style = TextStyle(color = White, fontSize = 14.sp, fontWeight = FontWeight.Medium),
                modifier = GlanceModifier.defaultWeight(),
            )
            Text(
                if (snapshot.isStale()) "⚠ ${Format.dayMonth(observedAt.atZone(java.time.ZoneId.systemDefault()).toLocalDate())}" else Format.hour(observedAt),
                maxLines = 1,
                style = TextStyle(color = SoftWhite, fontSize = 11.sp),
            )
        }
    }

    @Composable
    private fun Reading(snapshot: Snapshot, size: Int) {
        val arrow = when (Trend.of(snapshot.live.trend24hHm3)) {
            Trend.Rising -> "↗"
            Trend.Falling -> "↘"
            Trend.Steady -> "→"
        }
        Column {
            Text(
                Format.percent(snapshot.live.percent),
                maxLines = 1,
                style = TextStyle(color = White, fontSize = size.sp, fontWeight = FontWeight.Bold),
            )
            Text(
                "$arrow ${Format.hm3(snapshot.live.volumeHm3)}",
                maxLines = 1,
                style = TextStyle(color = White, fontSize = 13.sp, fontWeight = FontWeight.Medium),
            )
        }
    }

    @Composable
    private fun Stat(title: String, value: String, modifier: GlanceModifier = GlanceModifier) {
        Column(modifier) {
            Text(title, maxLines = 1, style = TextStyle(color = SoftWhite, fontSize = 11.sp))
            Text(value, maxLines = 1, style = TextStyle(color = White, fontSize = 13.sp, fontWeight = FontWeight.Medium))
        }
    }

    @Composable
    private fun Small(snapshot: Snapshot) {
        Column(GlanceModifier.fillMaxSize().padding(14.dp)) {
            Header(snapshot)
            Spacer(GlanceModifier.defaultWeight())
            Reading(snapshot, 32)
        }
    }

    @Composable
    private fun Medium(snapshot: Snapshot) {
        Column(GlanceModifier.fillMaxSize().padding(14.dp)) {
            Header(snapshot)
            Spacer(GlanceModifier.defaultWeight())
            Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
                Box(GlanceModifier.defaultWeight()) { Reading(snapshot, 30) }
                Spacer(GlanceModifier.width(14.dp))
                Row(GlanceModifier.defaultWeight()) {
                    Stat("Boletín", Format.hm3(snapshot.weekly.volumeHm3, 0), GlanceModifier.defaultWeight())
                    Stat("Hace un año", snapshot.weekly.lastYearHm3?.let { Format.hm3(it, 0) } ?: "Sin dato", GlanceModifier.defaultWeight())
                }
            }
        }
    }

    @Composable
    private fun Large(snapshot: Snapshot) {
        Column(GlanceModifier.fillMaxSize().padding(16.dp)) {
            Header(snapshot)
            Spacer(GlanceModifier.height(6.dp))
            Reading(snapshot, 42)
            Spacer(GlanceModifier.height(6.dp))
            Text("Últimos 90 días", style = TextStyle(color = SoftWhite, fontSize = 11.sp))
            Spacer(GlanceModifier.defaultWeight())
            Row(GlanceModifier.fillMaxWidth()) {
                Stat("Boletín", Format.hm3(snapshot.weekly.volumeHm3, 0), GlanceModifier.defaultWeight())
                Stat("Hace un año", snapshot.weekly.lastYearHm3?.let { Format.hm3(it, 0) } ?: "Sin dato", GlanceModifier.defaultWeight())
                Stat("Caudal", Format.optional(snapshot.live.outflowM3s, "m³/s"), GlanceModifier.defaultWeight())
            }
        }
    }

    companion object {
        /** Redraws every placed widget from the saved snapshot. */
        suspend fun refreshAll(context: Context) {
            ReservoirWidget().updateAll(context)
        }
    }
}

/** Where the curve goes, as fractions of the widget's size. */
private data class ChartArea(val left: Float, val top: Float, val width: Float, val height: Float)

/** Material You's tones when the device has them, or the app's water blue on older versions. */
private data class WidgetColors(val sky: Int, val skyEnd: Int, val water: Int, val waterEnd: Int, val back: Int) {
    companion object {
        fun resolve(context: Context): WidgetColors =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                WidgetColors(
                    sky = ContextCompat.getColor(context, android.R.color.system_accent1_900),
                    skyEnd = ContextCompat.getColor(context, android.R.color.system_accent1_800),
                    water = ContextCompat.getColor(context, android.R.color.system_accent1_600),
                    waterEnd = ContextCompat.getColor(context, android.R.color.system_accent1_700),
                    back = ContextCompat.getColor(context, android.R.color.system_accent1_400),
                )
            } else {
                WidgetColors(
                    sky = Color.rgb(15, 46, 97),
                    skyEnd = Color.rgb(23, 69, 133),
                    water = Color.rgb(28, 115, 230),
                    waterEnd = Color.rgb(8, 69, 173),
                    back = Color.rgb(77, 158, 250),
                )
            }
    }
}

private fun sceneBitmap(
    context: Context,
    widthDp: Float,
    heightDp: Float,
    snapshot: Snapshot,
    chart: ChartArea?,
    chartDays: Int,
): Bitmap {
    // Twice the dp size is sharp enough, and keeps the bitmap under RemoteViews' memory limit.
    val width = (widthDp * 2).toInt().coerceAtLeast(2)
    val height = (heightDp * 2).toInt().coerceAtLeast(2)
    val colors = WidgetColors.resolve(context)
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)

    paint.shader = LinearGradient(0f, 0f, 0f, height.toFloat(), colors.sky, colors.skyEnd, Shader.TileMode.CLAMP)
    canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)

    val level = (snapshot.live.percent / 100).toFloat()
    paint.shader = null
    paint.color = colors.back
    paint.alpha = 110
    canvas.drawPath(wave(width, height, level, 2.7f), paint)
    paint.alpha = 255
    val baseline = height * (1 - level)
    paint.shader = LinearGradient(0f, baseline, 0f, height.toFloat(), colors.water, colors.waterEnd, Shader.TileMode.CLAMP)
    canvas.drawPath(wave(width, height, level, 0.6f), paint)
    paint.shader = null

    chart?.let { drawChart(canvas, width, height, it, snapshot.daily.takeLast(chartDays)) }
    return bitmap
}

private fun wave(width: Int, height: Int, level: Float, phase: Float): Path = Path().apply {
    val baseline = height * (1 - level.coerceIn(0f, 1f))
    val amplitude = height * 0.022f
    moveTo(0f, height.toFloat())
    var x = 0
    while (x <= width) {
        lineTo(x.toFloat(), baseline + sin(x.toFloat() / width * 2 * PI.toFloat() + phase) * amplitude)
        x += 4
    }
    lineTo(width.toFloat(), height.toFloat())
    close()
}

private fun drawChart(canvas: Canvas, width: Int, height: Int, area: ChartArea, points: List<DailyPoint>) {
    if (points.size < 2) return
    val left = width * area.left
    val top = height * area.top
    val chartWidth = width * area.width
    val chartHeight = height * area.height
    val low = points.minOf { it.volumeHm3 }
    val high = points.maxOf { it.volumeHm3 }
    val margin = maxOf((high - low) * 0.1, 0.5)

    fun xOf(index: Int) = left + index.toFloat() / points.lastIndex * chartWidth
    fun yOf(value: Double) = (top + chartHeight - ((value - low + margin) / (high - low + 2 * margin)) * chartHeight).toFloat()

    val line = Path()
    points.forEachIndexed { index, point ->
        if (index == 0) line.moveTo(xOf(index), yOf(point.volumeHm3)) else line.lineTo(xOf(index), yOf(point.volumeHm3))
    }
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    paint.color = Color.WHITE
    paint.style = Paint.Style.STROKE
    paint.strokeWidth = 4f
    paint.strokeCap = Paint.Cap.ROUND
    paint.strokeJoin = Paint.Join.ROUND
    canvas.drawPath(line, paint)
}

class ReservoirWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ReservoirWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetRefreshWorker.schedule(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WorkManager.getInstance(context).cancelUniqueWork(WidgetRefreshWorker.NAME)
    }
}

/** New data arrives hourly, and this keeps widgets current even if the app is never opened. */
class WidgetRefreshWorker(context: Context, parameters: WorkerParameters) : CoroutineWorker(context, parameters) {
    override suspend fun doWork(): Result = try {
        (applicationContext as EmbalseApplication).repository.load()
        ReservoirWidget.refreshAll(applicationContext)
        Result.success()
    } catch (_: IOException) {
        Result.retry()
    }

    companion object {
        const val NAME = "widget-refresh"

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<WidgetRefreshWorker>(1, TimeUnit.HOURS).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }
}
