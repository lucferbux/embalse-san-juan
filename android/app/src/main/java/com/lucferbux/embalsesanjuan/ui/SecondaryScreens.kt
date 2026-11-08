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
import androidx.compose.ui.res.stringResource
import com.lucferbux.embalsesanjuan.R
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
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
                actions = { actions() },
            )
        },
    ) { padding ->
        content(Modifier.fillMaxSize().padding(padding))
    }
}

@Composable
fun AboutScreen(snapshot: Snapshot, onBack: () -> Unit) {
    val reservoir = snapshot.reservoir
    val context = LocalContext.current
    fun open(url: String) = context.startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))

    SecondaryScaffold(stringResource(R.string.about_title), onBack) { modifier ->
        Column(
            modifier.verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            SectionCard(stringResource(R.string.about_card)) {
                ValueRow(stringResource(R.string.about_river), reservoir.river)
                ValueRow(stringResource(R.string.about_basin), reservoir.basin)
                ValueRow(stringResource(R.string.about_province), reservoir.province)
                ValueRow(stringResource(R.string.about_municipality), reservoir.municipality)
                ValueRow(stringResource(R.string.about_dam_type), reservoir.damType)
                ValueRow(stringResource(R.string.about_year_built), reservoir.yearBuilt.toString())
                ValueRow(stringResource(R.string.about_surface), Format.value(reservoir.surfaceHa, "ha", 0))
            }
            SectionCard(stringResource(R.string.about_uses)) {
                Text(
                    reservoir.uses.joinToString(" · "),
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }
            SectionCard(
                stringResource(R.string.about_sources),
                footer = stringResource(R.string.about_disclaimer),
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
                    Text(stringResource(R.string.about_privacy))
                }
                TextButton(onClick = { open("https://embalse-san-juan.web.app/support.html") }, modifier = Modifier.padding(horizontal = 4.dp)) {
                    Text(stringResource(R.string.about_support))
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
        stringResource(R.string.suggestions_title),
        onBack,
        actions = {
            if (status != SendStatus.Sent) {
                IconButton(onClick = ::send, enabled = suggestion.isValid && status != SendStatus.Sending) {
                    Icon(Icons.AutoMirrored.Filled.Send, contentDescription = stringResource(R.string.suggestions_send))
                }
            }
        },
    ) { modifier ->
        if (status == SendStatus.Sent) {
            Column(modifier.padding(32.dp), Arrangement.Center, Alignment.CenterHorizontally) {
                Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.height(48.dp))
                Text(stringResource(R.string.suggestions_thanks), style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 16.dp))
                Text(
                    stringResource(R.string.suggestions_thanks_detail),
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(top = 8.dp),
                )
                Button(
                    onClick = {
                        text = ""
                        status = SendStatus.Editing
                    },
                    modifier = Modifier.padding(top = 24.dp),
                ) { Text(stringResource(R.string.suggestions_another)) }
            }
        } else {
            Column(
                modifier.verticalScroll(rememberScrollState()).imePadding().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                androidx.compose.foundation.layout.Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Suggestion.Kind.entries.forEach { option ->
                        FilterChip(selected = kind == option, onClick = { kind = option }, label = { Text(stringResource(when (option) { Suggestion.Kind.Suggestion -> R.string.suggestion_kind_suggestion; Suggestion.Kind.Bug -> R.string.suggestion_kind_bug; Suggestion.Kind.Other -> R.string.suggestion_kind_other })) })
                    }
                }
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it },
                    label = { Text(stringResource(R.string.suggestions_message)) },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 180.dp),
                    isError = suggestion.trimmedText.length > Suggestion.MAXIMUM_LENGTH,
                    supportingText = {
                        Text(stringResource(R.string.suggestions_count, suggestion.trimmedText.length, Suggestion.MAXIMUM_LENGTH))
                    },
                )
                Text(
                    stringResource(R.string.suggestions_anonymous),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (status == SendStatus.Failed) {
                    Text(
                        stringResource(R.string.suggestions_failed),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
        }
    }
}
