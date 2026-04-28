package dev.ogos.anotheriptvplayer

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.tv.material3.*

/**
 * Custom Color Palette for a premium TV experience.
 */
object TvColors {
    val Background = Color(0xFF0D0D0F)
    val Surface = Color(0xFF16161A)
    val SurfaceVariant = Color(0xFF1E1E24)
    val Primary = Color(0xFF00C8B4)
    val OnPrimary = Color(0xFFFFFFFF)
    val Secondary = Color(0xFF7B61FF)
    val Error = Color(0xFFFF4F6A)
    val TextPrimary = Color(0xFFFFFFFF)
    val TextSecondary = Color(0xFF9A9AA8)
    val TextMuted = Color(0xFF555568)
    val FocusGlow = Color(0xFF00C8B4).copy(alpha = 0.4f)
}

/**
 * Premium Typography for TV.
 */
object TvTypography {
    val DisplayLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.ExtraBold,
        fontSize = 72.sp,
        letterSpacing = (-2).sp,
        color = TvColors.TextPrimary
    )
    val HeadlineMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Bold,
        fontSize = 28.sp,
        color = TvColors.TextPrimary
    )
    val TitleLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 22.sp,
        color = TvColors.TextPrimary
    )
    val BodyMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        color = TvColors.TextSecondary
    )
    val LabelSmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Medium,
        fontSize = 12.sp,
        letterSpacing = 1.5.sp,
        color = TvColors.TextMuted
    )
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvTheme(
    content: @Composable () -> Unit
) {
    val colorScheme = darkColorScheme(
        primary = TvColors.Primary,
        onPrimary = TvColors.OnPrimary,
        secondary = TvColors.Secondary,
        background = TvColors.Background,
        onBackground = TvColors.TextPrimary,
        surface = TvColors.Surface,
        onSurface = TvColors.TextPrimary,
        surfaceVariant = TvColors.SurfaceVariant,
        onSurfaceVariant = TvColors.TextSecondary,
        error = TvColors.Error
    )

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography(
            displayLarge = TvTypography.DisplayLarge,
            headlineMedium = TvTypography.HeadlineMedium,
            titleLarge = TvTypography.TitleLarge,
            bodyMedium = TvTypography.BodyMedium,
            labelSmall = TvTypography.LabelSmall
        ),
        content = content
    )
}
