package dev.ogos.anotheriptvplayer

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.darkColorScheme

@Composable
fun TvAppTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Color(0xFF00C8B4),
            background = Color(0xFF0D0D0F),
            surface = Color(0xFF16161A),
            onBackground = Color(0xFFFFFFFF),
            onSurface = Color(0xFFFFFFFF),
            secondary = Color(0xFF1E1E24)
        ),
        content = content
    )
}
