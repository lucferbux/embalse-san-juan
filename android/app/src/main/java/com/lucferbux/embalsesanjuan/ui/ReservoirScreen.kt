package com.lucferbux.embalsesanjuan.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.staggeredgrid.LazyVerticalStaggeredGrid
import androidx.compose.foundation.lazy.staggeredgrid.StaggeredGridCells
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.automirrored.filled.TrendingFlat
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.Air
import androidx.compose.material.icons.filled.Compress
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Feedback
import androidx.compose.material.icons.filled.Grain
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Thermostat
import androidx.compose.material.icons.filled.Thunderstorm
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lucferbux.embalsesanjuan.data.Format
import com.lucferbux.embalsesanjuan.data.Live
import com.lucferbux.embalsesanjuan.data.Snapshot
import com.lucferbux.embalsesanjuan.data.SnapshotRepository
import com.lucferbux.embalsesanjuan.data.Trend
import java.time.Instant

private const val TWO_COLUMN_WIDTH_DP = 720

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReservoirScreen(
    state: UiState,
    refreshing: Boolean,
    onRefresh: () -> Unit,
    onOpenHistory: () -> Unit,
    onOpenAbout: () -> Unit,
    onOpenSuggestions: () -> Unit,
) {
    val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior(rememberTopAppBarState())
    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        topBar = {
            LargeTopAppBar(
                title = { Text("San Juan", maxLines = 1, overflow = TextOverflow.Ellipsis) },
                scrollBehavior = scrollBehavior,
            )
        },
    ) { padding ->
        when (state) {
            UiState.Loading -> Box(Modifier.fillMaxSize().padding(padding), Alignment.Center) {
                CircularProgressIndicator()
            }
            UiState.Failed -> Column(
                Modifier.fillMaxSize().padding(padding).padding(32.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(Icons.Filled.WifiOff, contentDescription = null, modifier = Modifier.size(48.dp))
                Spacer(Modifier.height(16.dp))
                Text("No hay datos", style = MaterialTheme.typography.titleLarge)
                Text("Revisa la conexión e inténtalo de nuevo.", style = MaterialTheme.typography.bodyMedium)
                Spacer(Modifier.height(16.dp))
                Button(onClick = onRefresh) { Text("Reintentar") }
            }
            is UiState.Loaded -> PullToRefreshBox(
                isRefreshing = refreshing,
                onRefresh = onRefresh,
                modifier = Modifier.fillMaxSize().padding(top = padding.calculateTopPadding()),
            ) {
                Dashboard(state.snapshot, state.origin, padding, onOpenHistory, onOpenAbout, onOpenSuggestions)
            }
        }
    }
}

@Composable
private fun Dashboard(
    snapshot: Snapshot,
    origin: SnapshotRepository.Origin,
    padding: PaddingValues,
    onOpenHistory: () -> Unit,
    onOpenAbout: () -> Unit,
    onOpenSuggestions: () -> Unit,
) {
    // A width rule, never the device type: it covers tablets, foldables and split screens alike.
    val columns = if (LocalConfiguration.current.screenWidthDp >= TWO_COLUMN_WIDTH_DP) 2 else 1
    LazyVerticalStaggeredGrid(
        columns = StaggeredGridCells.Fixed(columns),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 24.dp + padding.calculateBottomPadding()),
        verticalItemSpacing = 22.dp,
        horizontalArrangement = Arrangement.spacedBy(24.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        item { HeroSection(snapshot, origin) }
        item { RealtimeSection(snapshot) }
        item { OutflowSection(snapshot) }
        item { WeeklySection(snapshot) }
        item { WeatherSection(snapshot) }
        item { AlbercheSection(snapshot) }
        if (snapshot.rainGauges.isNotEmpty()) item { RainSection(snapshot) }
        item {
            SectionCard(null) {
                LinkRow("Histórico desde 1988", Icons.AutoMirrored.Filled.ShowChart, onOpenHistory)
                LinkRow("Ficha y fuentes", Icons.Filled.Info, onOpenAbout)
            }
        }
        item {
            SectionCard("Ayuda a mejorarla") {
                LinkRow("Enviar una sugerencia", Icons.Filled.Feedback, onOpenSuggestions)
            }
        }
    }
}

private val Trend.icon: ImageVector
    get() = when (this) {
        Trend.Rising -> Icons.AutoMirrored.Filled.TrendingUp
        Trend.Falling -> Icons.AutoMirrored.Filled.TrendingDown
        Trend.Steady -> Icons.AutoMirrored.Filled.TrendingFlat
    }

@Composable
private fun HeroSection(snapshot: Snapshot, origin: SnapshotRepository.Origin) {
    val live: Live = snapshot.live
    val trend = Trend.of(live.trend24hHm3)
    val observedAt = Instant.parse(live.observedAt)
    val summary = "${Format.percent(live.percent)}, ${Format.hm3(live.volumeHm3, 2)} de ${Format.hm3(snapshot.weekly.capacityHm3, 0)}. ${trend.label}."
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        WaterHero(
            percent = live.percent,
            modifier = Modifier
                .fillMaxWidth()
                .height(280.dp)
                .clearAndSetSemantics { contentDescription = summary },
        ) {
            Column(
                Modifier.fillMaxSize().padding(20.dp),
                verticalArrangement = Arrangement.Bottom,
            ) {
                Text(
                    Format.percent(live.percent),
                    fontSize = 64.sp,
                    lineHeight = 68.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                )
                Text(
                    "${Format.hm3(live.volumeHm3, 2)} de ${Format.hm3(snapshot.weekly.capacityHm3, 0)}",
                    style = MaterialTheme.typography.titleLarge,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(trend.icon, contentDescription = null, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(
                        "${trend.label} · ${Format.signed(live.trend24hHm3)} hm³ en 24 h",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }
        }
        Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            if (snapshot.isStale()) {
                Notice("Este dato tiene más de 6 horas. La recogida puede estar fallando.", Icons.Filled.Warning, MaterialTheme.colorScheme.error)
            } else if (origin == SnapshotRepository.Origin.Cache) {
                Notice("Sin conexión. Mostrando el último dato guardado.", Icons.Filled.WifiOff, MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text(
                "SAIH Tajo, ${Format.dayMonthHour(observedAt)}. Dato provisional.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun Notice(text: String, icon: ImageVector, color: androidx.compose.ui.graphics.Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(6.dp))
        Text(text, style = MaterialTheme.typography.bodySmall, color = color)
    }
}

private fun hourLabels(instants: List<Instant>): List<Pair<Float, String>> {
    if (instants.size < 2) return emptyList()
    return listOf(0, instants.size / 3, 2 * instants.size / 3, instants.lastIndex).map { index ->
        instants[index].epochSecond.toFloat() to Format.hour(instants[index])
    }
}

@Composable
private fun RealtimeSection(snapshot: Snapshot) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    val live = snapshot.live
    val recent = snapshot.recent
    SectionCard("Tiempo real") {
        LineChart(
            points = recent.map { ChartPoint(it.instant.epochSecond.toFloat(), it.volumeHm3.toFloat()) },
            description = "Volumen en las últimas 24 horas",
            yLabel = { Format.number(it.toDouble(), 2) },
            xLabels = hourLabels(recent.map { it.instant }),
            modifier = Modifier.fillMaxWidth().height(170.dp).padding(horizontal = 16.dp, vertical = 8.dp),
        )
        ValueRow("Cota", Format.optional(live.elevationM, "m", 2))
        ValueRow("Nivel", Format.optional(live.levelM, "m", 2))
        Row(
            Modifier
                .fillMaxWidth()
                .clickable { expanded = !expanded }
                .heightIn(min = 48.dp)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Últimas lecturas", style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
            Icon(if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore, contentDescription = null)
        }
        if (expanded) {
            recent.indices.reversed().take(8).forEach { index ->
                val reading = recent[index]
                val change = if (index > 0) Format.signed(reading.volumeHm3 - recent[index - 1].volumeHm3) else ""
                Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp)) {
                    Text(Format.dayMonthHour(reading.instant), style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                    Text(Format.number(reading.volumeHm3, 2), style = MaterialTheme.typography.bodyMedium, fontFamily = FontFamily.Monospace)
                    Text(
                        change,
                        style = MaterialTheme.typography.bodyMedium,
                        fontFamily = FontFamily.Monospace,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.width(64.dp),
                        textAlign = androidx.compose.ui.text.style.TextAlign.End,
                    )
                }
            }
        }
    }
}

@Composable
private fun OutflowSection(snapshot: Snapshot) {
    val readings = snapshot.recent.filter { it.outflowM3s != null }
    SectionCard("Caudal desembalsado") {
        ValueRow("Salida al río", Format.optional(snapshot.live.outflowM3s, "m³/s", 2))
        ValueRow("Trasvase a Valmayor", Format.optional(snapshot.live.transferM3s, "m³/s", 2))
        LineChart(
            points = readings.map { ChartPoint(it.instant.epochSecond.toFloat(), it.outflowM3s!!.toFloat()) },
            description = "Caudal de salida en las últimas 24 horas",
            yLabel = { Format.number(it.toDouble(), 0) },
            xLabels = hourLabels(readings.map { it.instant }),
            yMin = 0f,
            stepped = true,
            modifier = Modifier.fillMaxWidth().height(130.dp).padding(horizontal = 16.dp, vertical = 8.dp),
        )
    }
}

@Composable
private fun WeeklySection(snapshot: Snapshot) {
    val weekly = snapshot.weekly
    SectionCard(
        "Boletín semanal",
        footer = "MITECO, ${Format.dayMonth(weekly.day)}. Es otra medición y no coincide con el dato en tiempo real.",
    ) {
        ValueRow("Agua embalsada", "${Format.hm3(weekly.volumeHm3, 0)} (${Format.percent(weekly.percent)})")
        ValueRow("Variación semanal", "${Format.signed(weekly.changeHm3, 0)} hm³")
        ValueRow("Capacidad", Format.hm3(weekly.capacityHm3, 0))
        ValueRow("Misma semana del año pasado", weekly.lastYearHm3?.let { Format.hm3(it, 0) } ?: "Sin dato")
        ValueRow("Media de 10 años", weekly.tenYearAvgHm3?.let { Format.hm3(it) } ?: "Sin dato")
    }
}

@Composable
private fun WeatherSection(snapshot: Snapshot) {
    val weather = snapshot.weather
    val wind = Format.optional(weather.windMs, "m/s").let { speed ->
        val direction = weather.windDirectionDeg
        if (weather.windMs != null && direction != null) "$speed ${Format.compass(direction)}" else speed
    }
    SectionCard("Tiempo en la presa", footer = "SAIH Tajo, ${Format.dayMonthHour(Instant.parse(weather.observedAt))}.") {
        ValueRow("Temperatura", Format.optional(weather.temperatureC, "°C"), Icons.Filled.Thermostat)
        ValueRow("Viento", wind, Icons.Filled.Air)
        ValueRow("Humedad", Format.optional(weather.humidityPct, "%", 0), Icons.Filled.WaterDrop)
        ValueRow("Presión", Format.optional(weather.pressureHpa, "hPa", 0), Icons.Filled.Compress)
        ValueRow("Radiación solar", Format.optional(weather.solarWm2, "W/m²", 0), Icons.Filled.WbSunny)
        ValueRow("Lluvia en 1 h", Format.optional(weather.rain1hMm, "mm"), Icons.Filled.Grain)
        ValueRow("Lluvia en 24 h", Format.optional(weather.rain24hMm, "mm"), Icons.Filled.Thunderstorm)
    }
}

@Composable
private fun AlbercheSection(snapshot: Snapshot) {
    SectionCard("Río Alberche", footer = "De aguas arriba a aguas abajo.") {
        snapshot.neighbours.filter { it.position == "upstream" }.forEach { ChainRow(it.name, it.percent, it.volumeHm3, false) }
        ChainRow(snapshot.reservoir.name, snapshot.live.percent, snapshot.live.volumeHm3, true)
        snapshot.neighbours.filter { it.position == "downstream" }.forEach { ChainRow(it.name, it.percent, it.volumeHm3, false) }
    }
}

@Composable
private fun ChainRow(name: String, percent: Double, volume: Double, isCurrent: Boolean) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row {
            Text(
                name,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = if (isCurrent) FontWeight.SemiBold else FontWeight.Normal,
                modifier = Modifier.weight(1f),
            )
            Text(
                "${Format.percent(percent)} · ${Format.hm3(volume)}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        LinearProgressIndicator(progress = { (percent / 100).toFloat() }, modifier = Modifier.fillMaxWidth())
    }
}

@Composable
private fun RainSection(snapshot: Snapshot) {
    SectionCard("Lluvia en la cuenca, 24 h", footer = "Pluviómetros del SAIH Tajo en la cuenca del Alberche.") {
        snapshot.rainGauges.forEach { ValueRow(it.name, Format.optional(it.rain24hMm, "mm")) }
    }
}

@Composable
private fun LinkRow(label: String, icon: ImageVector, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .heightIn(min = 56.dp)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
        Spacer(Modifier.width(14.dp))
        Text(label, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
