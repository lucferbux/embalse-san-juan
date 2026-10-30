package com.lucferbux.embalsesanjuan.ui

import android.content.Intent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import com.lucferbux.embalsesanjuan.BuildConfig
import com.lucferbux.embalsesanjuan.data.FirestoreClient
import com.lucferbux.embalsesanjuan.data.Format
import com.lucferbux.embalsesanjuan.data.History
import com.lucferbux.embalsesanjuan.data.HistoryPoint
import com.lucferbux.embalsesanjuan.data.Snapshot
import com.lucferbux.embalsesanjuan.data.Suggestion
import com.lucferbux.embalsesanjuan.data.SuggestionClient
import java.io.IOException
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SecondaryScaffold(
    title: String,
    onBack: () -> Unit,
    actions: @Composable () -> Unit = {},
    content: @Composable (Modifier) -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Atrás")
                    }
                },
                actions = { actions() },
            )
        },
    ) { padding ->
        content(Modifier.fillMaxSize().padding(padding))
    }
}

private enum class HistoryRange(val label: String) {
    OneYear("1 año"),
    FiveYears("5 años"),
    All("Desde 1988"),
}

@Composable
fun HistoryScreen(capacityHm3: Double, onBack: () -> Unit) {
    var history by remember { mutableStateOf<History?>(null) }
    var failed by remember { mutableStateOf(false) }
    var attempt by remember { mutableStateOf(0) }
    var range by rememberSaveable { mutableStateOf(HistoryRange.OneYear) }

    LaunchedEffect(attempt) {
        failed = false
        try {
            history = FirestoreClient.fetchHistory()
        } catch (_: IOException) {
            failed = true
        }
    }

    SecondaryScaffold("Histórico", onBack) { modifier ->
        val loaded = history
        when {
            loaded != null -> {
                val points: List<HistoryPoint> = when (range) {
                    HistoryRange.All -> loaded.weekly
                    HistoryRange.FiveYears -> loaded.daily
                    HistoryRange.OneYear -> loaded.daily.takeLast(365)
                }
                Column(
                    modifier.verticalScroll(rememberScrollState()).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp),
                ) {
                    // Half width on wide screens, so a centred control doesn't sit on a foldable's hinge.
                    val pickerModifier = if (LocalConfiguration.current.screenWidthDp >= 600) Modifier.fillMaxWidth(0.45f) else Modifier.fillMaxWidth()
                    SingleChoiceSegmentedButtonRow(pickerModifier) {
                        HistoryRange.entries.forEachIndexed { index, option ->
                            SegmentedButton(
                                selected = range == option,
                                onClick = { range = option },
                                shape = SegmentedButtonDefaults.itemShape(index, HistoryRange.entries.size),
                                label = { Text(option.label, maxLines = 1) },
                            )
                        }
                    }
                    SectionCard(
                        null,
                        footer = if (range == HistoryRange.All) "Boletín Hidrológico de MITECO, dato semanal." else "SAIH Tajo, último valor de cada día.",
                    ) {
                        val first = points.first().day
                        val last = points.last().day
                        LineChart(
                            points = points.map { ChartPoint(it.day.toEpochDay().toFloat(), it.volumeHm3.toFloat()) },
                            description = "Evolución del volumen del embalse",
                            yLabel = { Format.number(it.toDouble(), 0) },
                            xLabels = listOf(
                                first.toEpochDay().toFloat() to Format.monthYear(first),
                                last.toEpochDay().toFloat() to Format.monthYear(last),
                            ),
                            yMin = 0f,
                            yMax = (maxOf(capacityHm3, points.maxOf { it.volumeHm3 }) * 1.1).toFloat(),
                            reference = capacityHm3.toFloat() to "Capacidad",
                            modifier = Modifier.fillMaxWidth().height(300.dp).padding(horizontal = 16.dp, vertical = 8.dp),
                        )
                    }
                    val low = points.minBy { it.volumeHm3 }
                    val high = points.maxBy { it.volumeHm3 }
                    SectionCard("En este periodo") {
                        ValueRow("Mínimo", "${Format.hm3(low.volumeHm3)}, ${Format.monthYear(low.day)}")
                        ValueRow("Máximo", "${Format.hm3(high.volumeHm3)}, ${Format.monthYear(high.day)}")
                        ValueRow("Media", Format.hm3(points.map { it.volumeHm3 }.average()))
                    }
                }
            }
            failed -> Column(modifier, Arrangement.Center, Alignment.CenterHorizontally) {
                Text("No se ha podido cargar", style = MaterialTheme.typography.titleMedium)
                TextButton(onClick = { attempt++ }) { Text("Reintentar") }
            }
            else -> Box(modifier, Alignment.Center) { CircularProgressIndicator() }
        }
    }
}

@Composable
fun AboutScreen(snapshot: Snapshot, onBack: () -> Unit) {
    val reservoir = snapshot.reservoir
    val context = LocalContext.current
    fun open(url: String) = context.startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))

    SecondaryScaffold("Ficha y fuentes", onBack) { modifier ->
        Column(
            modifier.verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            SectionCard("Ficha") {
                ValueRow("Río", reservoir.river)
                ValueRow("Cuenca", reservoir.basin)
                ValueRow("Provincia", reservoir.province)
                ValueRow("Municipio", reservoir.municipality)
                ValueRow("Tipo de presa", reservoir.damType)
                ValueRow("Año de construcción", reservoir.yearBuilt.toString())
                ValueRow("Superficie", "${Format.number(reservoir.surfaceHa, 0)} ha")
            }
            SectionCard("Usos") {
                Text(
                    reservoir.uses.joinToString(" · "),
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }
            SectionCard(
                "Fuentes",
                footer = "App personal, sin relación con estos organismos ni respaldada por ellos. Todos los datos son provisionales.",
            ) {
                snapshot.sources.forEach { source ->
                    Column(
                        Modifier
                            .fillMaxWidth()
                            .clickable { open(source.url) }
                            .padding(horizontal = 16.dp, vertical = 10.dp),
                    ) {
                        Text(source.name, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.primary)
                        Text(source.publisher, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(source.note, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            SectionCard(null) {
                TextButton(onClick = { open("https://embalse-san-juan.web.app/privacy.html") }, modifier = Modifier.padding(horizontal = 4.dp)) {
                    Text("Política de privacidad")
                }
                TextButton(onClick = { open("https://embalse-san-juan.web.app/support.html") }, modifier = Modifier.padding(horizontal = 4.dp)) {
                    Text("Soporte")
                }
            }
        }
    }
}

private enum class SendStatus { Editing, Sending, Sent, Failed }

@Composable
fun SuggestionScreen(onBack: () -> Unit) {
    var kind by rememberSaveable { mutableStateOf(Suggestion.Kind.Suggestion) }
    var text by rememberSaveable { mutableStateOf("") }
    var status by remember { mutableStateOf(SendStatus.Editing) }
    val scope = rememberCoroutineScope()
    val suggestion = Suggestion(kind, text)

    fun send() {
        status = SendStatus.Sending
        scope.launch {
            status = try {
                SuggestionClient.send(suggestion, BuildConfig.VERSION_NAME)
                SendStatus.Sent
            } catch (_: IOException) {
                SendStatus.Failed
            }
        }
    }

    SecondaryScaffold(
        "Sugerencias",
        onBack,
        actions = {
            if (status != SendStatus.Sent) {
                IconButton(onClick = ::send, enabled = suggestion.isValid && status != SendStatus.Sending) {
                    Icon(Icons.AutoMirrored.Filled.Send, contentDescription = "Enviar")
                }
            }
        },
    ) { modifier ->
        if (status == SendStatus.Sent) {
            Column(modifier.padding(32.dp), Arrangement.Center, Alignment.CenterHorizontally) {
                Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.height(48.dp))
                Text("Gracias por escribir", style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 16.dp))
                Text(
                    "Tu mensaje ha llegado. Lo leeré, aunque no pueda responderte porque es anónimo.",
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(top = 8.dp),
                )
                Button(
                    onClick = {
                        text = ""
                        status = SendStatus.Editing
                    },
                    modifier = Modifier.padding(top = 24.dp),
                ) { Text("Enviar otro") }
            }
        } else {
            Column(
                modifier.verticalScroll(rememberScrollState()).imePadding().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                androidx.compose.foundation.layout.Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Suggestion.Kind.entries.forEach { option ->
                        FilterChip(selected = kind == option, onClick = { kind = option }, label = { Text(option.label) })
                    }
                }
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it },
                    label = { Text("Tu mensaje") },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 180.dp),
                    isError = suggestion.trimmedText.length > Suggestion.MAXIMUM_LENGTH,
                    supportingText = {
                        Text("${suggestion.trimmedText.length} de ${Suggestion.MAXIMUM_LENGTH} caracteres.")
                    },
                )
                Text(
                    "Es anónimo: no incluyas datos personales. Si quieres respuesta, escribe desde la página de soporte.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (status == SendStatus.Failed) {
                    Text(
                        "No se ha podido enviar. Revisa la conexión e inténtalo de nuevo.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
        }
    }
}
