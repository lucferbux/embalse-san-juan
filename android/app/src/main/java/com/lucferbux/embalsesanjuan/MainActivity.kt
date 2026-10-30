package com.lucferbux.embalsesanjuan

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.lucferbux.embalsesanjuan.ui.AboutScreen
import com.lucferbux.embalsesanjuan.ui.EmbalseTheme
import com.lucferbux.embalsesanjuan.ui.HistoryScreen
import com.lucferbux.embalsesanjuan.ui.ReservoirScreen
import com.lucferbux.embalsesanjuan.ui.ReservoirViewModel
import com.lucferbux.embalsesanjuan.ui.SuggestionScreen
import com.lucferbux.embalsesanjuan.ui.UiState

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent {
            EmbalseTheme {
                val requested = if (BuildConfig.DEBUG) intent.getStringExtra(EXTRA_SCREEN) else null
                App(start = requested ?: Routes.HOME)
            }
        }
    }

    companion object {
        /** Debug builds only: lets `adb shell am start` open a screen directly, for screenshots and checks. */
        const val EXTRA_SCREEN = "screen"
    }
}

private object Routes {
    const val HOME = "home"
    const val HISTORY = "history"
    const val ABOUT = "about"
    const val SUGGESTIONS = "suggestions"
}

@Composable
private fun App(start: String, model: ReservoirViewModel = viewModel()) {
    val navController = rememberNavController()
    val state by model.state.collectAsStateWithLifecycle()
    val refreshing by model.refreshing.collectAsStateWithLifecycle()

    LifecycleResumeEffect(Unit) {
        model.refresh()
        onPauseOrDispose {}
    }

    NavHost(navController = navController, startDestination = start) {
        composable(Routes.HOME) {
            ReservoirScreen(
                state = state,
                refreshing = refreshing,
                onRefresh = { model.refresh(force = true) },
                onOpenHistory = { navController.navigate(Routes.HISTORY) },
                onOpenAbout = { navController.navigate(Routes.ABOUT) },
                onOpenSuggestions = { navController.navigate(Routes.SUGGESTIONS) },
            )
        }
        composable(Routes.HISTORY) {
            val capacity = (state as? UiState.Loaded)?.snapshot?.weekly?.capacityHm3 ?: 138.0
            HistoryScreen(capacityHm3 = capacity, onBack = navController::popBackStack)
        }
        composable(Routes.ABOUT) {
            when (val current = state) {
                is UiState.Loaded -> AboutScreen(current.snapshot, onBack = navController::popBackStack)
                else -> Text("Cargando")
            }
        }
        composable(Routes.SUGGESTIONS) {
            SuggestionScreen(onBack = navController::popBackStack)
        }
    }
}
