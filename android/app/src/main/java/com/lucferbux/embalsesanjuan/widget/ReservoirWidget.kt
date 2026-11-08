package com.lucferbux.embalsesanjuan.widget

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
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
import com.lucferbux.embalsesanjuan.R
import com.lucferbux.embalsesanjuan.data.Format
import com.lucferbux.embalsesanjuan.data.History
import com.lucferbux.embalsesanjuan.data.ReservoirId
import com.lucferbux.embalsesanjuan.data.Snapshot
import com.lucferbux.embalsesanjuan.data.Trend
import com.lucferbux.embalsesanjuan.data.YearSurface
import com.lucferbux.embalsesanjuan.ui.Water
import java.io.IOException
import java.time.Instant
import java.util.concurrent.TimeUnit
import kotlin.math.PI
import kotlin.math.sin

private val SmallSize = DpSize(110.dp, 110.dp)
private val MediumSize = DpSize(250.dp, 110.dp)
private val LargeSize = DpSize(250.dp, 250.dp)
private val White = ColorProvider(Color.White)

/** Room at the top for the name and the time; the level is drawn below it. */
private fun topRoom(heightDp: Float, stale: Boolean) = (if (heightDp >= LargeSize.height.value) 56f else 34f) + if (stale) 14f else 0f

private fun isNight(context: Context) =
    context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES

/** The sky, the water card's: light by day, dark at night. */
private fun skyColors(context: Context): Pair<Int, Int> =
    if (isNight(context)) Color(0xFF0D1524).toArgb() to Color(0xFF17243A).toArgb()
    else Color(0xFFE8F4FF).toArgb() to Color(0xFFF7FBFF).toArgb()

private fun labelColor(context: Context) = ColorProvider(if (isNight(context)) Color.White else Color(0xFF1B1B21))
private fun secondaryColor(context: Context) = ColorProvider(if (isNight(context)) Color(0xB3FFFFFF) else Color(0xB31B1B21))

/**
 * "Ahora" (docs/design/review-2.0/SYNTHESIS.md): the water card's light sky and the real level. The figure goes wholly in
 * the water, in white, or wholly in the sky, in the label colour, never across the waterline; the name and time sit
 * at the top, always in the sky. Glance can't draw freely, so the sky and water are a bitmap.
 */
class ReservoirWidget : GlanceAppWidget() {
    // Exact, not responsive: the gap that keeps the figure clear of the waterline is in dp of the real size.
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val repository = (context.applicationContext as EmbalseApplication).repository
        // A widget placed before the app was ever opened still has something to show.
        val snapshot = repository.cached() ?: runCatching { repository.load().first }.getOrNull()
        Format.locale = Format.resolve(context.resources.configuration.locales[0])
        provideContent { Content(snapshot) }
    }

    @Composable
    private fun Content(snapshot: Snapshot?) {
        val context = LocalContext.current
        val size = LocalSize.current
        val modifier = GlanceModifier.fillMaxSize().cornerRadius(24.dp).clickable(actionStartActivity<MainActivity>())
        if (snapshot == null) {
            Box(modifier.padding(16.dp), contentAlignment = Alignment.Center) {
                Text(context.getString(R.string.widget_open_app), style = TextStyle(color = labelColor(context)))
            }
            return
        }
        val wide = size.width >= MediumSize.width
        val tall = size.height >= LargeSize.height
        val stale = snapshot.isStale()
        val top = topRoom(size.height.value, stale)
        // Text is in sp, so the block grows with the font scale.
        val scale = context.resources.configuration.fontScale
        val full = (if (tall) 112f else if (wide) 58f else 54f) * scale
        val compactBlock = (if (tall) 64f else 40f) * scale
        // Where the block goes: the same rule as the app, in dp. In the water it needs the waterline's crest and 12 dp
        // above it and 10 dp below; in the sky, the same above the crest. A compact block drops the second line.
        val usable = size.height.value - top
        val water = usable * (snapshot.live.percent / 100).toFloat().coerceIn(0f, 1f)
        val (inWater, compact) = WidgetPlacement.decide(usable, water, full, compactBlock)
        val color = if (inWater) White else labelColor(context)
        val bottomGap = if (inWater) 10f else water + 16f

        Box(modifier) {
            Image(
                provider = ImageProvider(levelBitmap(context, size.width.value, size.height.value, snapshot.live.percent, top)),
                contentDescription = "${snapshot.reservoir.name}, ${Format.percent(snapshot.live.percent)}",
                contentScale = ContentScale.FillBounds,
                modifier = GlanceModifier.fillMaxSize(),
            )
            Column(GlanceModifier.fillMaxSize().padding(horizontal = 14.dp).padding(top = 12.dp)) {
                Header(context, snapshot, stale, if (wide) "SAIH Tajo · " else "SAIH ")
                Spacer(GlanceModifier.defaultWeight())
                Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
                    Column(GlanceModifier.defaultWeight()) {
                        Text(Format.percent(snapshot.live.percent), maxLines = 1,
                            style = TextStyle(color = color, fontSize = (if (tall) 46 else if (compact) 26 else if (wide) 34 else 30).sp, fontWeight = FontWeight.Bold))
                        if (!compact) {
                            Text(
                                if (wide) Trend.sentence(snapshot.live.trend24hHm3) else "${Trend.of(snapshot.live.trend24hHm3).arrow} ${Trend.of(snapshot.live.trend24hHm3).label}",
                                maxLines = 1, style = TextStyle(color = color, fontSize = 12.sp, fontWeight = FontWeight.Medium),
                            )
                        }
                    }
                    if (wide && !compact) {
                        Column(horizontalAlignment = Alignment.End) {
                            Text(Format.volumeOfCapacity(snapshot.live.volumeHm3, snapshot.weekly.capacityHm3), maxLines = 1,
                                style = TextStyle(color = color, fontSize = 12.sp, fontWeight = FontWeight.Medium))
                            if (tall) {
                                Text(Format.optional(snapshot.live.outflowM3s, "m³/s", 2), maxLines = 1, style = TextStyle(color = color, fontSize = 12.sp))
                                Text(Format.optional(snapshot.live.elevationM, "m"), maxLines = 1, style = TextStyle(color = color, fontSize = 12.sp))
                            }
                        }
                    }
                }
                Spacer(GlanceModifier.height(bottomGap.dp))
            }
        }
    }

    companion object {
        /** Redraws every placed widget from the saved snapshot and history. */
        suspend fun refreshAll(context: Context) {
            ReservoirWidget().updateAll(context)
            YearWidget().updateAll(context)
        }
    }
}

@Composable
private fun Header(context: Context, snapshot: Snapshot, stale: Boolean, prefix: String) {
    val observedAt = Instant.parse(snapshot.live.observedAt)
    Column(GlanceModifier.fillMaxWidth()) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(snapshot.reservoir.name, maxLines = 1, modifier = GlanceModifier.defaultWeight(),
                style = TextStyle(color = labelColor(context), fontSize = 14.sp, fontWeight = FontWeight.Medium))
            if (!stale) Text(prefix + Format.hour(observedAt), maxLines = 1, style = TextStyle(color = secondaryColor(context), fontSize = 11.sp))
        }
        if (stale) {
            Text("⚠ ${Format.dayMonthHour(observedAt)}", maxLines = 1,
                style = TextStyle(color = ColorProvider(Color(0xFFE65100)), fontSize = 11.sp, fontWeight = FontWeight.Bold))
        }
    }
}

/**
 * "Último año": the last 12 months of SAIH as the water's surface, with last year's line, standing on a strip of water
 * that holds the figure, so the figure is always in the water and never over the curve.
 */
class YearWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val app = context.applicationContext as EmbalseApplication
        val snapshot = app.repository.cached() ?: runCatching { app.repository.load().first }.getOrNull()
        val history = app.histories.cached(ReservoirId.SanJuan) ?: runCatching { app.histories.load(ReservoirId.SanJuan) }.getOrNull()
        Format.locale = Format.resolve(context.resources.configuration.locales[0])
        provideContent { Content(snapshot, history) }
    }

    @Composable
    private fun Content(snapshot: Snapshot?, history: History?) {
        val context = LocalContext.current
        val size = LocalSize.current
        val modifier = GlanceModifier.fillMaxSize().cornerRadius(24.dp).clickable(actionStartActivity<MainActivity>())
        val reading = snapshot?.reading(ReservoirId.SanJuan)
        val surface = if (snapshot != null && history != null) YearSurface.of(history, reading, snapshot.weekly.capacityHm3) else null
        if (snapshot == null || surface == null) {
            Box(modifier.padding(16.dp), contentAlignment = Alignment.Center) {
                Text(context.getString(R.string.widget_open_app), style = TextStyle(color = labelColor(context)))
            }
            return
        }
        val tall = size.height >= LargeSize.height
        val floor = (if (tall) 86f else 56f) * context.resources.configuration.fontScale
        Box(modifier) {
            Image(
                provider = ImageProvider(yearBitmap(context, size.width.value, size.height.value, surface, snapshot.live.percent, floor)),
                contentDescription = context.getString(R.string.widget_year_name),
                contentScale = ContentScale.FillBounds,
                modifier = GlanceModifier.fillMaxSize(),
            )
            Column(GlanceModifier.fillMaxSize().padding(horizontal = 14.dp, vertical = 12.dp)) {
                Header(context, snapshot, snapshot.isStale(), "SAIH Tajo · ")
                Spacer(GlanceModifier.defaultWeight())
                Text(Format.percent(snapshot.live.percent), maxLines = 1,
                    style = TextStyle(color = White, fontSize = (if (tall) 40 else 28).sp, fontWeight = FontWeight.Bold))
                surface.changeFromLastYearHm3?.let { change ->
                    Text(
                        context.getString(if (change < 0) R.string.widget_less_than_last_year else R.string.widget_more_than_last_year, Format.hm3(kotlin.math.abs(change))),
                        maxLines = 1, style = TextStyle(color = White, fontSize = 12.sp),
                    )
                }
            }
        }
    }
}

/**
 * Where a widget's block goes, in dp: in the water it needs 12 dp above the crest (4 dp) and 10 dp below; in the sky,
 * the same above the crest. It tries the full block, then a compact one without its second line, and when neither
 * fits, the compact one goes wherever there is more room. Returns (in water, compact).
 */
object WidgetPlacement {
    fun decide(usable: Float, water: Float, full: Float, compact: Float): Pair<Boolean, Boolean> {
        fun fitsWater(block: Float) = water >= block + 12f + 4f + 10f
        fun fitsSky(block: Float) = usable - water - 12f - 4f >= block
        return when {
            fitsWater(full) -> true to false
            fitsSky(full) -> false to false
            fitsWater(compact) -> true to true
            fitsSky(compact) -> false to true
            else -> (water >= usable - water) to true
        }
    }
}

// MARK: Bitmaps

private fun bitmapOf(widthDp: Float, heightDp: Float): Pair<Bitmap, Float> {
    // Twice the dp size is sharp enough, and keeps the bitmap under RemoteViews' memory limit.
    val scale = 2f
    return Bitmap.createBitmap((widthDp * scale).toInt().coerceAtLeast(2), (heightDp * scale).toInt().coerceAtLeast(2), Bitmap.Config.ARGB_8888) to scale
}

private fun Canvas.sky(context: Context, paint: Paint) {
    val (top, bottom) = skyColors(context)
    paint.shader = LinearGradient(0f, 0f, 0f, height.toFloat(), top, bottom, Shader.TileMode.CLAMP)
    drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
    paint.shader = null
}

private fun waterShader(top: Float, bottom: Float, percent: Double) =
    LinearGradient(0f, top, 0f, bottom, Water.top(percent).toArgb(), Water.bottom(percent).toArgb(), Shader.TileMode.CLAMP)

private fun levelBitmap(context: Context, widthDp: Float, heightDp: Float, percent: Double, topDp: Float): Bitmap {
    val (bitmap, scale) = bitmapOf(widthDp, heightDp)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    canvas.sky(context, paint)
    val top = topDp * scale
    val baseline = top + (canvas.height - top) * (1 - (percent / 100).toFloat().coerceIn(0f, 1f))
    fun wave(phase: Float, lift: Float) = Path().apply {
        moveTo(0f, canvas.height.toFloat())
        var x = 0
        while (x <= canvas.width) {
            lineTo(x.toFloat(), baseline - lift + sin(x.toFloat() / canvas.width * 2 * PI.toFloat() * 1.2f + phase) * 3f * scale)
            x += 4
        }
        lineTo(canvas.width.toFloat(), canvas.height.toFloat())
        close()
    }
    paint.color = Water.back.toArgb()
    canvas.drawPath(wave(2.7f, 2f * scale), paint)
    // A paint's alpha also applies to its shader, so make it opaque again for the water.
    paint.color = android.graphics.Color.BLACK
    paint.shader = waterShader(baseline, canvas.height.toFloat(), percent)
    canvas.drawPath(wave(0.6f, 0f), paint)
    paint.shader = null
    return bitmap
}

private fun yearBitmap(context: Context, widthDp: Float, heightDp: Float, surface: YearSurface, percent: Double, floorDp: Float): Bitmap {
    val (bitmap, scale) = bitmapOf(widthDp, heightDp)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    canvas.sky(context, paint)
    val top = 44f * scale
    val usable = canvas.height - top - (floorDp + 14f) * scale
    fun x(index: Int, count: Int) = canvas.width.toFloat() * index / (count - 1).coerceAtLeast(1)
    fun y(fraction: Double) = top + usable * (1 - fraction.coerceIn(0.0, 1.02)).toFloat()

    surface.band?.takeIf { it.size > 1 }?.let { ranges ->
        val path = Path()
        ranges.forEachIndexed { index, range -> if (index == 0) path.moveTo(0f, y(range.endInclusive)) else path.lineTo(x(index, ranges.size), y(range.endInclusive)) }
        ranges.indices.reversed().forEach { path.lineTo(x(it, ranges.size), y(ranges[it].start)) }
        path.close()
        paint.color = if (isNight(context)) Color(0x2E7CC2F5).toArgb() else Color(0x1F0A4A7A).toArgb()
        canvas.drawPath(path, paint)
    }
    val line = Path()
    surface.levels.forEachIndexed { index, level -> if (index == 0) line.moveTo(0f, y(level)) else line.lineTo(x(index, surface.levels.size), y(level)) }
    val area = Path(line).apply {
        lineTo(canvas.width.toFloat(), canvas.height.toFloat())
        lineTo(0f, canvas.height.toFloat())
        close()
    }
    paint.color = android.graphics.Color.BLACK
    paint.shader = waterShader(top, canvas.height.toFloat(), percent)
    canvas.drawPath(area, paint)
    paint.shader = null
    paint.style = Paint.Style.STROKE
    paint.strokeWidth = 2f * scale
    paint.color = Water.crest.toArgb()
    canvas.drawPath(line, paint)
    surface.lastYear?.takeIf { it.size > 1 }?.let { values ->
        val path = Path()
        values.forEachIndexed { index, value -> if (index == 0) path.moveTo(0f, y(value)) else path.lineTo(x(index, values.size), y(value)) }
        paint.color = Water.lastYear.toArgb()
        paint.strokeWidth = 1.5f * scale
        paint.pathEffect = DashPathEffect(floatArrayOf(5f * scale, 4f * scale), 0f)
        canvas.drawPath(path, paint)
        paint.pathEffect = null
    }
    paint.style = Paint.Style.FILL
    val today = x(surface.levels.lastIndex, surface.levels.size) - 6f * scale to y(surface.levels.last())
    paint.color = android.graphics.Color.WHITE
    canvas.drawCircle(today.first, today.second, 4.5f * scale, paint)
    return bitmap
}

// MARK: Receivers and refresh

/** Both widgets share one hourly refresh, which stops when the last widget of either kind is removed. */
abstract class RefreshingReceiver : GlanceAppWidgetReceiver() {
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetRefreshWorker.schedule(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        val manager = android.appwidget.AppWidgetManager.getInstance(context)
        val placed = listOf(ReservoirWidgetReceiver::class.java, YearWidgetReceiver::class.java).sumOf {
            manager.getAppWidgetIds(android.content.ComponentName(context, it)).size
        }
        if (placed == 0) WorkManager.getInstance(context).cancelUniqueWork(WidgetRefreshWorker.NAME)
    }
}

class ReservoirWidgetReceiver : RefreshingReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ReservoirWidget()
}

class YearWidgetReceiver : RefreshingReceiver() {
    override val glanceAppWidget: GlanceAppWidget = YearWidget()
}

/** New data arrives hourly, and this keeps widgets current even if the app is never opened. */
class WidgetRefreshWorker(context: Context, parameters: WorkerParameters) : CoroutineWorker(context, parameters) {
    override suspend fun doWork(): Result = try {
        val app = applicationContext as EmbalseApplication
        app.repository.load()
        runCatching { app.histories.load(ReservoirId.SanJuan) }
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
