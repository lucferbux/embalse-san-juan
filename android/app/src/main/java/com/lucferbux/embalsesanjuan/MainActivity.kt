package com.lucferbux.embalsesanjuan

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.Route
import androidx.compose.material.icons.outlined.ShowChart
import androidx.compose.material.icons.outlined.WaterDrop
import androidx.compose.material.icons.filled.Route
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.lucferbux.embalsesanjuan.data.Format
import com.lucferbux.embalsesanjuan.data.ReservoirId
import com.lucferbux.embalsesanjuan.data.Snapshot
import com.lucferbux.embalsesanjuan.ui.AboutScreen
import com.lucferbux.embalsesanjuan.ui.CardMode
import com.lucferbux.embalsesanjuan.ui.EmbalseTheme
import com.lucferbux.embalsesanjuan.ui.HistoryScreen
import com.lucferbux.embalsesanjuan.ui.NowDetail
import com.lucferbux.embalsesanjuan.ui.NowDetailScreen
import com.lucferbux.embalsesanjuan.ui.NowScreen
import com.lucferbux.embalsesanjuan.ui.ReservoirPage
import com.lucferbux.embalsesanjuan.ui.ReservoirViewModel
import com.lucferbux.embalsesanjuan.ui.RiverScreen
import com.lucferbux.embalsesanjuan.ui.SuggestionScreen
import com.lucferbux.embalsesanjuan.ui.UiState
import java.time.Instant

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        Format.locale = Format.resolve(resources.configuration.locales[0])
        setContent {
            EmbalseTheme {
                val requested = if (BuildConfig.DEBUG) intent.getStringExtra(EXTRA_SCREEN) else null
                val year = BuildConfig.DEBUG && intent.getStringExtra(EXTRA_CARD) == "year"
                App(start = requested ?: Routes.NOW, initialMode = if (year) CardMode.Year else CardMode.Today)
            }
        }
    }

    companion object {
        /** Debug builds only: lets `adb shell am start` open a screen directly, for screenshots and checks. */
        const val EXTRA_SCREEN = "screen"
        /** Debug builds only: `--es card year` opens the water card on the year view. */
        const val EXTRA_CARD = "card"
    }
}

private object Routes {
    const val NOW = "now"
    const val HISTORY = "history"
    const val RIVER = "river"
    const val ABOUT = "about"
    const val SUGGESTIONS = "suggestions"
    const val RESERVOIR = "reservoir"
    const val DETAIL = "detail"
}

private enum class Section(val route: String, val title: Int, val icon: androidx.compose.ui.graphics.vector.ImageVector, val selectedIcon: androidx.compose.ui.graphics.vector.ImageVector) {
    Now(Routes.NOW, R.string.tab_now, Icons.Outlined.WaterDrop, Icons.Filled.WaterDrop),
    History(Routes.HISTORY, R.string.tab_history, Icons.Outlined.ShowChart, Icons.Filled.ShowChart),
    River(Routes.RIVER, R.string.tab_river, Icons.Outlined.Route, Icons.Filled.Route),
}

/** Three sections everywhere: a bottom bar on phones, a rail on foldables and tablets, chosen by window size. */
@Composable
private fun App(start: String, initialMode: CardMode, model: ReservoirViewModel = viewModel()) {
    val navController = rememberNavController()
    val state by model.state.collectAsStateWithLifecycle()
    val refreshing by model.refreshing.collectAsStateWithLifecycle()
    val histories by model.histories.collectAsStateWithLifecycle()
    val entry by navController.currentBackStackEntryAsState()
    val route = entry?.destination?.route

    LifecycleResumeEffect(Unit) {
        model.refresh()
        onPauseOrDispose {}
    }
    LaunchedEffect(Unit) { model.loadHistory(ReservoirId.SanJuan) }

    NavigationSuiteScaffold(
        navigationSuiteItems = {
            Section.entries.forEach { section ->
                val selected = route == section.route
                item(
                    selected = selected,
                    onClick = {
                        navController.navigate(section.route) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                    icon = { Icon(if (selected) section.selectedIcon else section.icon, contentDescription = null) },
                    label = { Text(stringResource(section.title)) },
                )
            }
        },
    ) {
        val snapshot = (state as? UiState.Loaded)?.snapshot
        if (snapshot == null) {
            Box(Modifier.fillMaxSize(), Alignment.Center) {
                if (state is UiState.Failed) {
                    Button(onClick = { model.refresh(force = true) }) { Text(stringResource(R.string.retry)) }
                } else CircularProgressIndicator()
            }
            return@NavigationSuiteScaffold
        }
        val loaded = state as UiState.Loaded
        val openReservoir = { id: ReservoirId -> navController.navigate("${Routes.RESERVOIR}/${id.name}") }
        NavHost(navController = navController, startDestination = start) {
            composable(Routes.NOW) {
                TopLevel(stringResource(R.string.reservoir_name), snapshot, navController::navigate) { modifier ->
                    Box(modifier) {
                        NowScreen(
                            snapshot, loaded.origin, histories[ReservoirId.SanJuan].loadedHistory(), refreshing,
                            onRefresh = { model.refresh(force = true) },
                            onOpenDetail = { navController.navigate("${Routes.DETAIL}/${it.name}") },
                            onOpenReservoir = openReservoir,
                            initialMode = initialMode,
                        )
                    }
                }
            }
            composable(Routes.HISTORY) {
                TopLevel(stringResource(R.string.tab_history), snapshot, navController::navigate) { modifier ->
                    Box(modifier) { HistoryScreen(snapshot, histories[ReservoirId.SanJuan]) { model.retryHistory(ReservoirId.SanJuan) } }
                }
            }
            composable(Routes.RIVER) {
                TopLevel(stringResource(R.string.tab_river), snapshot, navController::navigate) { modifier ->
                    Box(modifier) { RiverScreen(snapshot, openReservoir) }
                }
            }
            composable("${Routes.RESERVOIR}/{id}") { backStack ->
                val id = ReservoirId.valueOf(backStack.arguments?.getString("id") ?: ReservoirId.SanJuan.name)
                LaunchedEffect(id) { model.loadHistory(id) }
                Secondary(id.displayName, navController::popBackStack) { modifier ->
                    Box(modifier) { ReservoirPage(id, snapshot, histories[id]) { model.retryHistory(id) } }
                }
            }
            composable("${Routes.DETAIL}/{detail}") { backStack ->
                val detail = NowDetail.valueOf(backStack.arguments?.getString("detail") ?: NowDetail.Recent.name)
                Secondary(stringResource(R.string.reservoir_name), navController::popBackStack) { modifier ->
                    Box(modifier) { NowDetailScreen(detail, snapshot) }
                }
            }
            composable(Routes.ABOUT) { AboutScreen(snapshot, onBack = navController::popBackStack) }
            composable(Routes.SUGGESTIONS) { SuggestionScreen(onBack = navController::popBackStack) }
        }
    }
}

private fun com.lucferbux.embalsesanjuan.ui.HistoryState?.loadedHistory() =
    (this as? com.lucferbux.embalsesanjuan.ui.HistoryState.Loaded)?.history

/** A section's top bar: its title, share, and the overflow menu with the ficha and suggestions. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TopLevel(title: String, snapshot: Snapshot, navigate: (String) -> Unit, content: @Composable (Modifier) -> Unit) {
    val context = LocalContext.current
    var menu by remember { mutableStateOf(false) }
    val shareText = stringResource(
        R.string.share_text, Format.percent(snapshot.live.percent), Format.hm3(snapshot.live.volumeHm3),
        Format.saihSource(Instant.parse(snapshot.live.observedAt)),
    )
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold) },
                actions = {
                    IconButton(onClick = {
                        val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, shareText)
                        context.startActivity(Intent.createChooser(send, null))
                    }) { Icon(Icons.Filled.Share, contentDescription = stringResource(R.string.share)) }
                    Box {
                        IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, contentDescription = stringResource(R.string.more)) }
                        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                            DropdownMenuItem(text = { Text(stringResource(R.string.about_title)) }, onClick = { menu = false; navigate(Routes.ABOUT) })
                            DropdownMenuItem(text = { Text(stringResource(R.string.suggestions_title)) }, onClick = { menu = false; navigate(Routes.SUGGESTIONS) })
                        }
                    }
                },
            )
        },
    ) { padding -> content(Modifier.fillMaxSize().padding(padding)) }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Secondary(title: String, onBack: () -> Unit, content: @Composable (Modifier) -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back)) }
                },
            )
        },
    ) { padding -> content(Modifier.fillMaxSize().padding(padding)) }
}
