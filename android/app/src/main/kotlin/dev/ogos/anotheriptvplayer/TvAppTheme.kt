package dev.ogos.anotheriptvplayer

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.darkColorScheme

@Composable
fun TvAppTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Color(0xFF4F98A3),
            background = Color(0xFF0D0D1A),
            surface = Color(0xFF1C1B19),
            onBackground = Color(0xFFCDCCCA),
            onSurface = Color(0xFFCDCCCA),
        ),
        content = content
    )
}
