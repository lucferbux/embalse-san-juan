package com.lucferbux.embalsesanjuan

import android.app.Application
import com.lucferbux.embalsesanjuan.data.SnapshotRepository

class EmbalseApplication : Application() {
    val repository: SnapshotRepository by lazy { SnapshotRepository(filesDir) }
}
