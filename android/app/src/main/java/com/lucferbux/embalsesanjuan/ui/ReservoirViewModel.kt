package com.lucferbux.embalsesanjuan.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.lucferbux.embalsesanjuan.EmbalseApplication
import com.lucferbux.embalsesanjuan.data.History
import com.lucferbux.embalsesanjuan.data.ReservoirId
import com.lucferbux.embalsesanjuan.data.Snapshot
import com.lucferbux.embalsesanjuan.data.SnapshotRepository
import com.lucferbux.embalsesanjuan.widget.ReservoirWidget
import java.io.IOException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

sealed interface HistoryState {
    data object Loading : HistoryState
    data object Failed : HistoryState
    data class Loaded(val history: History) : HistoryState
}

sealed interface UiState {
    data object Loading : UiState
    data object Failed : UiState
    data class Loaded(val snapshot: Snapshot, val origin: SnapshotRepository.Origin) : UiState
}

class ReservoirViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = (application as EmbalseApplication).repository
    private val _state = MutableStateFlow<UiState>(UiState.Loading)
    private val _refreshing = MutableStateFlow(false)
    private var lastAttempt = 0L

    val state: StateFlow<UiState> = _state
    val refreshing: StateFlow<Boolean> = _refreshing

    private val historyRepository = (application as EmbalseApplication).histories
    private val _histories = MutableStateFlow<Map<ReservoirId, HistoryState>>(emptyMap())
    val histories: StateFlow<Map<ReservoirId, HistoryState>> = _histories

    /** Loads a reservoir's history once, showing the saved copy first. */
    fun loadHistory(id: ReservoirId) {
        if (_histories.value[id] is HistoryState.Loaded) return
        historyRepository.cached(id)?.let { cached -> _histories.update { it + (id to HistoryState.Loaded(cached)) } }
            ?: _histories.update { it + (id to HistoryState.Loading) }
        viewModelScope.launch {
            try {
                val history = historyRepository.load(id)
                _histories.update { it + (id to HistoryState.Loaded(history)) }
            } catch (_: IOException) {
                if (_histories.value[id] !is HistoryState.Loaded) _histories.update { it + (id to HistoryState.Failed) }
            }
        }
    }

    fun retryHistory(id: ReservoirId) {
        _histories.update { it - id }
        loadHistory(id)
    }

    init {
        repository.cached()?.let { _state.value = UiState.Loaded(it, SnapshotRepository.Origin.Cache) }
    }

    fun refresh(force: Boolean = false) {
        val now = System.currentTimeMillis()
        // New data arrives hourly, so reopening the app more often than this needs no request.
        if (!force && now - lastAttempt < MINIMUM_REFRESH_INTERVAL_MS) return
        lastAttempt = now
        viewModelScope.launch {
            _refreshing.value = true
            val previous = repository.cached()?.generatedAt
            try {
                val (snapshot, origin) = repository.load()
                _state.value = UiState.Loaded(snapshot, origin)
                if (snapshot.generatedAt != previous) ReservoirWidget.refreshAll(getApplication())
            } catch (_: IOException) {
                if (_state.value !is UiState.Loaded) _state.value = UiState.Failed
            } finally {
                _refreshing.value = false
            }
        }
    }

    private companion object {
        const val MINIMUM_REFRESH_INTERVAL_MS = 15 * 60 * 1000L
    }
}
