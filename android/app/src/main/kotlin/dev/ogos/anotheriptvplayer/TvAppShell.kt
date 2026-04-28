package dev.ogos.anotheriptvplayer

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.tv.material3.*

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvAppShell(initialTab: Int = 0) {
    val context = LocalContext.current
    val shellVm: TvShellViewModel = viewModel()
    val contentVm: TvContentViewModel = viewModel()
    
    val selectedIndex by shellVm.selectedIndex.collectAsState()
    val railExpanded by shellVm.railExpanded.collectAsState()

    LaunchedEffect(Unit) {
        shellVm.setSelectedIndex(initialTab)
        contentVm.loadContent(context)
    }

    val items = listOf(
        TvNavItem(Icons.Default.Home, "Home"),
        TvNavItem(Icons.Default.LiveTv, "Live TV"),
        TvNavItem(Icons.Default.Movie, "Movies"),
        TvNavItem(Icons.Default.Tv, "Series"),
        TvNavItem(Icons.Default.Favorite, "Favorites"),
        TvNavItem(Icons.Default.WatchLater, "Watch Later"),
        TvNavItem(Icons.Default.Search, "Search"),
        TvNavItem(Icons.Default.Settings, "Settings"),
    )

    TvTheme {
        Row(modifier = Modifier.fillMaxSize().background(TvColors.Background)) {
            // Sidebar Navigation
            Column(
                modifier = Modifier
                    .fillMaxHeight()
                    .width(if (railExpanded) 240.dp else 80.dp)
                    .background(TvColors.Surface)
                    .padding(vertical = 24.dp, horizontal = 12.dp)
                    .animateContentSize(),
                horizontalAlignment = Alignment.Start
            ) {
                // App Logo / Profile
                Box(
                    modifier = Modifier
                        .padding(horizontal = 12.dp)
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(TvColors.Primary),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.PlayArrow, contentDescription = null, tint = Color.White)
                }

                Spacer(modifier = Modifier.height(48.dp))

                items.forEachIndexed { index, item ->
                    if (index == items.size - 1) Spacer(modifier = Modifier.weight(1f))

                    TvSideNavItem(
                        item = item,
                        isSelected = selectedIndex == index,
                        isExpanded = railExpanded,
                        onFocus = { shellVm.setRailExpanded(true) },
                        onClick = { shellVm.setSelectedIndex(index) }
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                }
            }

            // Main Content Area
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .onFocusChanged { if (it.isFocused) shellVm.setRailExpanded(false) }
            ) {
                AnimatedContent(
                    targetState = selectedIndex,
                    transitionSpec = {
                        (fadeIn() + slideInHorizontally { 20 }).togetherWith(fadeOut() + slideOutHorizontally { -20 })
                    },
                    label = "page"
                ) { targetIndex ->
                    when (targetIndex) {
                        0 -> TvHomeScreen()
                        1 -> TvLiveTvScreen()
                        2 -> TvMoviesScreen()
                        3 -> TvSeriesScreen()
                        4 -> TvFavoritesScreen()
                        5 -> TvWatchLaterScreen()
                        6 -> TvSearchScreen()
                        7 -> TvSettingsScreen(
                            onSwitchPlaylist = {
                                TvRepository.clearPlaylist(context)
                                (context as? android.app.Activity)?.finish()
                            }
                        )
                        else -> TvHomeScreen()
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvSideNavItem(
    item: TvNavItem,
    isSelected: Boolean,
    isExpanded: Boolean,
    onFocus: () -> Unit,
    onClick: () -> Unit
) {
    var isFocused by remember { mutableStateOf(false) }
    
    Surface(
        selected = isSelected,
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .onFocusChanged { 
                isFocused = it.isFocused
                if (it.isFocused) onFocus()
            },
        colors = SelectableSurfaceDefaults.colors(
            containerColor = Color.Transparent,
            focusedContainerColor = Color.White.copy(alpha = 0.15f),
            selectedContainerColor = TvColors.Primary.copy(alpha = 0.1f),
            focusedSelectedContainerColor = TvColors.Primary
        ),
        shape = SelectableSurfaceDefaults.shape(RoundedCornerShape(8.dp))
    ) {
        Row(
            modifier = Modifier.fillMaxSize().padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                item.icon,
                contentDescription = null,
                modifier = Modifier.size(24.dp),
                tint = if (isFocused || isSelected) Color.White else TvColors.TextSecondary
            )
            
            if (isExpanded) {
                Spacer(modifier = Modifier.width(16.dp))
                Text(
                    text = item.label,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (isFocused || isSelected) Color.White else TvColors.TextSecondary,
                    fontWeight = if (isFocused || isSelected) FontWeight.Bold else FontWeight.Normal
                )
            }
        }
    }
}
