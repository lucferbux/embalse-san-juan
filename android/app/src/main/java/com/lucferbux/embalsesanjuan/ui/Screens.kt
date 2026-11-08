package com.lucferbux.embalsesanjuan.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.drawText
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lucferbux.embalsesanjuan.R
import com.lucferbux.embalsesanjuan.data.Format
import com.lucferbux.embalsesanjuan.data.History
import com.lucferbux.embalsesanjuan.data.HistoryPoint
import com.lucferbux.embalsesanjuan.data.ReservoirId
import com.lucferbux.embalsesanjuan.data.Snapshot
import com.lucferbux.embalsesanjuan.data.SnapshotRepository
import com.lucferbux.embalsesanjuan.data.YearComparison
import com.lucferbux.embalsesanjuan.data.YearSurface
import java.time.Instant

/** A wide window, not taller than wide (an unfolded foldable, a tablet in landscape): the card becomes a pane beside the modules. */
private fun isWide(width: androidx.compose.ui.unit.Dp, height: androidx.compose.ui.unit.Dp) = width >= 700.dp && width >= height * 0.9f

// MARK: Ahora

/**
 * "Ahora" (docs/design/review-2.0/SYNTHESIS.md): the water card, then the modules. On a phone the card is about two
 * thirds of the screen and collapses into a strip as it scrolls away. In a tall wide window it is a band over two
 * columns; in a wide one, a pane beside the modules, with a foldable's hinge between the two.
 */
@Composable
fun NowScreen(
    snapshot: Snapshot,
    origin: SnapshotRepository.Origin,
    history: History?,
    refreshing: Boolean,
    onRefresh: () -> Unit,
    onOpenDetail: (NowDetail) -> Unit,
    onOpenReservoir: (ReservoirId) -> Unit,
    initialMode: CardMode = CardMode.Today,
) {
    val reading = snapshot.reading(ReservoirId.SanJuan)!!
    val surface = remember(history, reading) { history?.let { YearSurface.of(it, reading, snapshot.weekly.capacityHm3) } }
    var mode by rememberSaveable { mutableStateOf(initialMode) }
    val large = LocalDensity.current.fontScale >= 1.6f
    val card = @Composable { modifier: Modifier, figure: Int ->
        WaterCard(reading, snapshot.weekly.capacityHm3, snapshot.live.trend24hHm3, surface, mode, { mode = it }, modifier, figure.sp)
    }

    PullToRefreshBox(isRefreshing = refreshing, onRefresh = onRefresh, modifier = Modifier.fillMaxSize()) {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            if (isWide(maxWidth, maxHeight)) {
                val paneWidth = (maxWidth * 0.42f).coerceIn(320.dp, 560.dp)
                Row(Modifier.fillMaxSize().padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                    Column(Modifier.width(paneWidth).padding(bottom = 20.dp)) {
                        Place(snapshot, origin)
                        card(Modifier.fillMaxWidth().weight(1f), 88)
                    }
                    Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(bottom = 20.dp)) {
                        Modules(snapshot, if (large) 1 else 2, onOpenDetail, onOpenReservoir)
                    }
                }
            } else {
                val regular = maxWidth >= 600.dp
                val height = if (regular) (maxHeight * 0.46f).coerceAtLeast(420.dp) else (maxHeight * 0.68f).coerceAtLeast(420.dp)
                val list = rememberLazyListState()
                val collapsed by remember { derivedStateOf { list.firstVisibleItemIndex >= 2 } }
                LazyColumn(
                    state = list,
                    contentPadding = PaddingValues(horizontal = if (regular) 24.dp else 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxSize().widthIn(max = 1100.dp).align(Alignment.TopCenter),
                ) {
                    item { Place(snapshot, origin) }
                    item { card(if (large) Modifier.fillMaxWidth() else Modifier.fillMaxWidth().height(height), if (regular) 88 else 60) }
                    item { Modules(snapshot, if (large) 1 else 2, onOpenDetail, onOpenReservoir, Modifier.padding(bottom = 24.dp)) }
                }
                AnimatedVisibility(
                    collapsed,
                    enter = slideInVertically { -it } + fadeIn(),
                    exit = slideOutVertically { -it } + fadeOut(),
                    modifier = Modifier.align(Alignment.TopCenter).padding(horizontal = 16.dp, vertical = 4.dp),
                ) {
                    WaterStrip(reading, snapshot.live.trend24hHm3, Modifier.fillMaxWidth())
                }
            }
        }
    }
}

/** The place, and the stale or offline notice. */
@Composable
private fun Place(snapshot: Snapshot, origin: SnapshotRepository.Origin) {
    Column(Modifier.padding(horizontal = 4.dp, vertical = 6.dp)) {
        Text(stringResource(R.string.place), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        when {
            snapshot.isStale() -> Text(
                stringResource(R.string.notice_stale, Format.dayMonthHour(Instant.parse(snapshot.live.observedAt))),
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold,
            )
            origin == SnapshotRepository.Origin.Cache -> Text(
                stringResource(R.string.notice_offline), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

// MARK: Histórico

/** "Histórico": this year against last year, the average and the range since 1988 (MITECO), the week, the records and the history. */
@Composable
fun HistoryScreen(snapshot: Snapshot, state: HistoryState?, onRetry: () -> Unit) {
    val history = (state as? HistoryState.Loaded)?.history
    val comparison = remember(history) { history?.let(YearComparison::of) }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val wide = maxWidth >= 600.dp
        val column = @Composable { content: @Composable () -> Unit ->
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) { content() }
        }
        val first: @Composable () -> Unit = {
            Panel(stringResource(R.string.history_comparison), Format.mitecoWeek(snapshot.weekly.day)) {
                if (comparison != null) {
                    ComparisonChart(comparison, Modifier.fillMaxWidth().height(240.dp))
                    ComparisonLegend()
                    Note(stringResource(R.string.history_comparison_note))
                } else Loading(state, onRetry)
            }
            WeeklyPanel(snapshot)
            if (comparison != null) Records(comparison)
        }
        val second: @Composable () -> Unit = { HistoryPanel(ReservoirId.SanJuan, snapshot.weekly.capacityHm3, snapshot.reading(ReservoirId.SanJuan), state, onRetry) }
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(if (wide) 24.dp else 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (wide) {
                Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                    Box(Modifier.weight(1f)) { column(first) }
                    Box(Modifier.weight(1f)) { column(second) }
                }
            } else {
                first()
                second()
            }
        }
    }
}

@Composable
fun Panel(title: String, source: String?, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Column(
        modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceContainerLow, MaterialTheme.shapes.extraLarge)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Column {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            source?.let { Text(it, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        content()
    }
}

@Composable
fun Note(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
private fun Loading(state: HistoryState?, onRetry: () -> Unit) {
    if (state == HistoryState.Failed) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.load_failed), color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
            TextButton(onClick = onRetry) { Text(stringResource(R.string.retry)) }
        }
    } else {
        Box(Modifier.fillMaxWidth().heightIn(min = 120.dp), Alignment.Center) { CircularProgressIndicator() }
    }
}

private object ChartColors {
    val thisYear = Color(0xFF1473EB)
    val lastYear = Color(0xFFED851A)
    val average = Color(0xFF8E8E93)
}

/** This year, last year, the 10-year average and the range since 1988, MITECO weekly, on one 0-to-capacity scale. */
@Composable
fun ComparisonChart(comparison: YearComparison, modifier: Modifier, onWater: Boolean = false) {
    val band = if (onWater) Color.White.copy(alpha = 0.12f) else MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
    val grid = MaterialTheme.colorScheme.outlineVariant
    val measurer = androidx.compose.ui.text.rememberTextMeasurer()
    val labelStyle = MaterialTheme.typography.labelSmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val todayLabel = stringResource(R.string.card_today).lowercase(Format.locale)
    val description = stringResource(
        R.string.chart_comparison,
        Format.hm3(comparison.thisYear.lastOrNull()?.volumeHm3 ?: 0.0, 0),
        comparison.lastYearNow?.let { Format.hm3(it, 0) } ?: "—",
        comparison.averageNow?.let { Format.hm3(it) } ?: "—",
    )
    Canvas(modifier.semantics { contentDescription = description }) {
        val start = java.time.LocalDate.of(comparison.year, 1, 1).toEpochDay().toFloat()
        val end = java.time.LocalDate.of(comparison.year, 12, 31).toEpochDay().toFloat()
        // Room for the hm³ labels on the left and the months below.
        val left = 34.dp.toPx()
        val bottom = 18.dp.toPx()
        val plotWidth = size.width - left
        val plotHeight = size.height - bottom
        fun x(day: java.time.LocalDate) = left + (day.toEpochDay() - start) / (end - start) * plotWidth
        fun y(value: Double) = plotHeight * (1 - (value / comparison.capacityHm3).toFloat().coerceIn(0f, 1.05f))
        listOf(0.0, 0.5, 1.0).forEach { share ->
            val gy = y(comparison.capacityHm3 * share)
            drawLine(grid, Offset(left, gy), Offset(size.width, gy), 1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 6f)))
            val text = measurer.measure(Format.number(comparison.capacityHm3 * share, 0), labelStyle)
            drawText(text, topLeft = Offset(0f, (gy - text.size.height / 2f).coerceIn(0f, plotHeight - text.size.height)))
        }
        listOf(1, 4, 7, 10).forEach { month ->
            val day = java.time.LocalDate.of(comparison.year, month, 1)
            val text = measurer.measure(Format.monthShort(day), labelStyle)
            drawText(text, topLeft = Offset(x(day), plotHeight + 3.dp.toPx()))
        }
        if (comparison.range.size > 1) {
            val path = Path()
            comparison.range.forEachIndexed { index, (day, _, high) -> if (index == 0) path.moveTo(x(day), y(high)) else path.lineTo(x(day), y(high)) }
            comparison.range.reversed().forEach { (day, low, _) -> path.lineTo(x(day), y(low)) }
            path.close()
            drawPath(path, band)
        }
        fun line(points: List<HistoryPoint>, color: Color, width: Float, dashed: Boolean = false) {
            if (points.size < 2) return
            val path = Path()
            points.forEachIndexed { index, point -> if (index == 0) path.moveTo(x(point.day), y(point.volumeHm3)) else path.lineTo(x(point.day), y(point.volumeHm3)) }
            drawPath(path, color, style = Stroke(width.dp.toPx(), pathEffect = if (dashed) PathEffect.dashPathEffect(floatArrayOf(6f, 8f)) else null))
        }
        line(comparison.average, if (onWater) Color.White.copy(alpha = 0.6f) else ChartColors.average, 1.4f, dashed = true)
        line(comparison.lastYear, ChartColors.lastYear, 2f)
        line(comparison.thisYear, if (onWater) Color.White else ChartColors.thisYear, 3f)
        comparison.thisYear.lastOrNull()?.let {
            val point = Offset(x(it.day), y(it.volumeHm3))
            drawCircle(if (onWater) Color.White else ChartColors.thisYear, 5.dp.toPx(), point)
            val text = measurer.measure(todayLabel, labelStyle.copy(color = ChartColors.thisYear, fontWeight = FontWeight.Bold))
            drawText(text, topLeft = Offset(point.x - text.size.width / 2f, point.y + 8.dp.toPx()))
        }
    }
}

@Composable
fun ComparisonLegend() {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        listOf(R.string.legend_this_year to ChartColors.thisYear, R.string.legend_last_year to ChartColors.lastYear, R.string.legend_average to ChartColors.average)
            .forEach { (label, color) ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (label == R.string.legend_average) {
                        // Dashed, like its line.
                        Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) { repeat(3) { Box(Modifier.size(4.dp, 2.dp).background(color)) } }
                    } else {
                        Box(Modifier.size(14.dp, 3.dp).background(color))
                    }
                    Text(stringResource(label), style = MaterialTheme.typography.labelSmall, modifier = Modifier.padding(start = 4.dp))
                }
            }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(12.dp, 9.dp).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)))
            Text(stringResource(R.string.legend_since_1988), style = MaterialTheme.typography.labelSmall, modifier = Modifier.padding(start = 4.dp))
        }
    }
}

@Composable
fun WeeklyPanel(snapshot: Snapshot) {
    val weekly = snapshot.weekly
    Panel(Format.mitecoWeek(weekly.day), null) {
        Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
            Stat(stringResource(R.string.weekly_this_week), Format.hm3(weekly.volumeHm3, 0))
            weekly.lastYearHm3?.let { Stat(stringResource(R.string.weekly_last_year), Format.hm3(it, 0)) }
            weekly.tenYearAvgHm3?.let { Stat(stringResource(R.string.weekly_average), Format.hm3(it)) }
        }
    }
}

@Composable
private fun Stat(label: String, value: String) {
    Column {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun Records(comparison: YearComparison) {
    Panel(stringResource(R.string.records), "MITECO · Boletín Hidrológico") {
        comparison.lowest?.let { (day, percent) -> ValueRow(stringResource(R.string.minimum), "${Format.percent(percent)}, ${Format.monthYear(day)}") }
        comparison.highest?.let { (day, percent) -> ValueRow(stringResource(R.string.maximum), "${Format.percent(percent)}, ${Format.monthYear(day)}") }
    }
}

enum class HistoryRange { OneYear, FiveYears, All }

/** A reservoir's history: 1 and 5 years from SAIH's daily values, since 1988 from MITECO's weekly ones. */
@Composable
fun HistoryPanel(
    id: ReservoirId,
    capacityHm3: Double,
    today: com.lucferbux.embalsesanjuan.data.ReservoirReading?,
    state: HistoryState?,
    onRetry: () -> Unit,
    initialRange: HistoryRange = HistoryRange.OneYear,
) {
    var range by rememberSaveable(id) { mutableStateOf(initialRange) }
    Panel(stringResource(R.string.history_title), null) {
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
            HistoryRange.entries.forEachIndexed { index, option ->
                SegmentedButton(
                    selected = range == option,
                    onClick = { range = option },
                    shape = SegmentedButtonDefaults.itemShape(index, HistoryRange.entries.size),
                    icon = {},
                    label = {
                        Text(stringResource(when (option) {
                            HistoryRange.OneYear -> R.string.range_one_year
                            HistoryRange.FiveYears -> R.string.range_five_years
                            HistoryRange.All -> R.string.range_all
                        }), maxLines = 1)
                    },
                )
            }
        }
        val history = (state as? HistoryState.Loaded)?.history
        if (history == null) {
            Loading(state, onRetry)
            return@Panel
        }
        var points = when (range) {
            HistoryRange.All -> history.weekly
            HistoryRange.FiveYears -> history.daily
            HistoryRange.OneYear -> history.daily.takeLast(365)
        }
        if (range != HistoryRange.All && today != null) {
            val day = today.observedAt.atZone(java.time.ZoneId.systemDefault()).toLocalDate()
            if (points.isEmpty() || points.last().day.isBefore(day)) points = points + HistoryPoint(day, today.volumeHm3)
        }
        if (points.size < 2) return@Panel
        val first = points.first().day
        val last = points.last().day
        LineChart(
            points = points.map { ChartPoint(it.day.toEpochDay().toFloat(), it.volumeHm3.toFloat()) },
            description = stringResource(R.string.chart_history),
            yLabel = { Format.number(it.toDouble(), 0) },
            xLabels = listOf(first.toEpochDay().toFloat() to Format.monthYear(first), last.toEpochDay().toFloat() to Format.monthYear(last)),
            yMin = 0f,
            yMax = (maxOf(capacityHm3, points.maxOf { it.volumeHm3 }, points.mapNotNull { it.capacityHm3 }.maxOrNull() ?: 0.0) * 1.1).toFloat(),
            reference = capacityHm3.toFloat() to stringResource(R.string.capacity, Format.hm3(capacityHm3, 0)),
            stepped = range == HistoryRange.All,
            modifier = Modifier.fillMaxWidth().height(260.dp),
        )
        Note(stringResource(if (range == HistoryRange.All) R.string.history_source_miteco else R.string.history_source_saih))
        val low = points.minBy { it.volumeHm3 }
        val high = points.maxBy { it.volumeHm3 }
        ValueRow(stringResource(R.string.minimum), "${Format.hm3(low.volumeHm3)}, ${Format.monthYear(low.day)}")
        ValueRow(stringResource(R.string.maximum), "${Format.hm3(high.volumeHm3)}, ${Format.monthYear(high.day)}")
        ValueRow(stringResource(R.string.mean), Format.hm3(points.map { it.volumeHm3 }.average()))
        val capacities = points.mapNotNull { it.capacityHm3 }
        if (capacities.size > 1 && capacities.first() != capacities.last()) {
            Note(stringResource(R.string.capacity_changed, Format.hm3(capacities.first(), 0), Format.hm3(capacities.last(), 0)))
        }
    }
}

// MARK: El río

/** "El río": the three reservoirs in river order, each at its own level, then the basin's rain gauges. */
@Composable
fun RiverScreen(snapshot: Snapshot, onOpenReservoir: (ReservoirId) -> Unit) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val wide = maxWidth >= 600.dp
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(if (wide) 24.dp else 16.dp).widthIn(max = 1100.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Panel(stringResource(R.string.river_chain), Format.saihSource(snapshot.chain.maxOf { it.observedAt })) {
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    snapshot.chain.forEach { reading ->
                        Tank(reading, reading.id == ReservoirId.SanJuan, if (wide) 200.dp else 140.dp,
                            Modifier.weight(1f).clickable { onOpenReservoir(reading.id) })
                    }
                }
            }
            if (snapshot.rainGauges.isNotEmpty()) {
                Panel(stringResource(R.string.river_rain), snapshot.rainGauges.maxOf { it.observedAt }.let { Format.saihSource(Instant.parse(it)) }) {
                    snapshot.rainGauges.forEach { ValueRow(it.name, Format.optional(it.rain24hMm, "mm")) }
                    Note(stringResource(R.string.river_rain_note))
                }
            }
        }
    }
}

/** One reservoir's page: its water card and its history. */
@Composable
fun ReservoirPage(id: ReservoirId, snapshot: Snapshot, state: HistoryState?, onRetry: () -> Unit) {
    val reading = snapshot.reading(id)
    val history = (state as? HistoryState.Loaded)?.history
    val capacity = history?.weekly?.lastOrNull()?.capacityHm3
        ?: if (id == ReservoirId.SanJuan) snapshot.weekly.capacityHm3 else reading?.capacityHm3 ?: 0.0
    val surface = remember(history, reading) { if (history != null && reading != null) YearSurface.of(history, reading, capacity) else null }
    var mode by rememberSaveable(id) { mutableStateOf(CardMode.Today) }
    val large = LocalDensity.current.fontScale >= 1.6f
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp).widthIn(max = 900.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        if (reading != null) {
            WaterCard(reading, capacity, if (id == ReservoirId.SanJuan) snapshot.live.trend24hHm3 else null, surface, mode, { mode = it },
                if (large) Modifier.fillMaxWidth() else Modifier.fillMaxWidth().height(420.dp), 56.sp)
        } else {
            Panel(stringResource(R.string.no_reading), null) { Note(stringResource(R.string.no_reading_detail, id.displayName)) }
        }
        // The card already shows the last year, so the history starts at 5 years.
        HistoryPanel(id, capacity, reading, state, onRetry, HistoryRange.FiveYears)
    }
}

/** The full panel behind a module. */
@Composable
fun NowDetailScreen(detail: NowDetail, snapshot: Snapshot) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp).widthIn(max = 700.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        when (detail) {
            NowDetail.Recent -> Panel(stringResource(R.string.module_recent), Format.saihSource(Instant.parse(snapshot.live.observedAt))) {
                RecentChart(snapshot, Modifier.fillMaxWidth().height(180.dp))
                ValueRow(stringResource(R.string.module_elevation), Format.optional(snapshot.live.elevationM, "m", 2))
                ValueRow(stringResource(R.string.level), Format.optional(snapshot.live.levelM, "m", 2))
            }
            NowDetail.Outflow -> Panel(stringResource(R.string.module_outflow), Format.saihSource(Instant.parse(snapshot.live.observedAt))) {
                ValueRow(stringResource(R.string.outflow_river), Format.optional(snapshot.live.outflowM3s, "m³/s", 2))
                ValueRow(stringResource(R.string.outflow_transfer), Format.optional(snapshot.live.transferM3s, "m³/s", 2))
                val values = snapshot.recent.mapNotNull { it.outflowM3s }
                if (values.size > 1) StepChart(values, Modifier.fillMaxWidth().height(120.dp))
            }
            NowDetail.Weather -> {
                val weather = snapshot.weather
                Panel(stringResource(R.string.module_weather), Format.saihSource(Instant.parse(weather.observedAt))) {
                    ValueRow(stringResource(R.string.weather_temperature), Format.optional(weather.temperatureC, "°C"))
                    ValueRow(stringResource(R.string.weather_wind), weather.windMs?.let { speed ->
                        Format.value(speed, "m/s") + (weather.windDirectionDeg?.let { " " + Format.compass(it) } ?: "")
                    } ?: Format.optional(null, ""))
                    ValueRow(stringResource(R.string.weather_humidity), Format.optional(weather.humidityPct, "%", 0))
                    ValueRow(stringResource(R.string.weather_pressure), Format.optional(weather.pressureHpa, "hPa", 0))
                    ValueRow(stringResource(R.string.weather_solar), Format.optional(weather.solarWm2, "W/m²", 0))
                    ValueRow(stringResource(R.string.weather_rain_1h), Format.optional(weather.rain1hMm, "mm"))
                    ValueRow(stringResource(R.string.weather_rain_24h), Format.optional(weather.rain24hMm, "mm"))
                }
            }
            NowDetail.Miteco -> WeeklyPanel(snapshot)
        }
    }
}

