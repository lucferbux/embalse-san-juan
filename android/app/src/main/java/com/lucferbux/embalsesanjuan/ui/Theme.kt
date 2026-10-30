package com.lucferbux.embalsesanjuan.ui

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val LightWater = lightColorScheme(
    primary = Color(0xFF0A5FC4),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD6E5FF),
    onPrimaryContainer = Color(0xFF001B3F),
)

private val DarkWater = darkColorScheme(
    primary = Color(0xFFA9C7FF),
    onPrimary = Color(0xFF002F65),
    primaryContainer = Color(0xFF00468E),
    onPrimaryContainer = Color(0xFFD6E5FF),
)

/** Material You: the colours come from the wallpaper, with a water blue on Android 11 and earlier. */
@Composable
fun EmbalseTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val colors = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        dark -> DarkWater
        else -> LightWater
    }
    MaterialTheme(colorScheme = colors, content = content)
}
