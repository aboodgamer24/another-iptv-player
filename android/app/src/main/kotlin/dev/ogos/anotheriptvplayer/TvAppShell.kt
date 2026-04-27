package dev.ogos.anotheriptvplayer

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.tv.material3.*
import androidx.compose.material3.Text
import androidx.compose.material3.Icon
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.border
import androidx.compose.ui.focus.onFocusChanged
import androidx.tv.material3.Surface
import androidx.tv.material3.ClickableSurfaceDefaults
import androidx.tv.material3.SelectableSurfaceDefaults
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer


@Composable
fun TvAppShell(initialTab: Int = 0) {
    val context = LocalContext.current
    val shellVm: TvShellViewModel = viewModel()
    val contentVm: TvContentViewModel = viewModel()
    
    val selectedIndex by shellVm.selectedIndex.collectAsState()
    val railExpanded by shellVm.railExpanded.collectAsState()

    LaunchedEffect(Unit) {
        shellVm.setSelectedIndex(initialTab)
        TvRepository.loadPlaylist(context)
        contentVm.loadContent()
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

    Row(modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        // Persistent Sidebar
        Column(
            modifier = Modifier
                .width(if (railExpanded) 200.dp else 72.dp)
                .fillMaxHeight()
                .background(MaterialTheme.colorScheme.surface)
                .padding(vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // App Logo Placeholder
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .background(MaterialTheme.colorScheme.primary, shape = MaterialTheme.shapes.small),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.LiveTv, contentDescription = null, tint = Color.White)
            }

            Spacer(modifier = Modifier.height(32.dp))

            items.forEachIndexed { index, item ->
                if (index == items.size - 1) Spacer(modifier = Modifier.weight(1f)) // Push settings to bottom

                val interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
                val isFocused by interactionSource.collectIsFocusedAsState()

                Surface(
                    selected = selectedIndex == index,
                    onClick = { shellVm.setSelectedIndex(index) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp)
                        .onFocusChanged { if (it.isFocused) shellVm.setRailExpanded(true) },
                    interactionSource = interactionSource,
                    colors = SelectableSurfaceDefaults.colors(
                        containerColor = Color.Transparent,
                        focusedContainerColor = MaterialTheme.colorScheme.primary,
                        pressedContainerColor = MaterialTheme.colorScheme.primary,
                        selectedContainerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f),
                        focusedSelectedContainerColor = MaterialTheme.colorScheme.primary
                    ),
                    shape = SelectableSurfaceDefaults.shape(shape = MaterialTheme.shapes.extraSmall)
                ) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.CenterStart) {
                        Row(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(horizontal = 16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            // Left border for focused/selected
                            if (isFocused || selectedIndex == index) {
                                Box(
                                    modifier = Modifier
                                        .width(2.dp)
                                        .height(24.dp)
                                        .background(Color.White)
                                )
                                Spacer(modifier = Modifier.width(14.dp))
                            }

                            Icon(
                                item.icon,
                                contentDescription = null,
                                tint = if (isFocused || selectedIndex == index) Color.White else Color(0xFF9A9AA8),
                                modifier = Modifier.size(24.dp)
                            )
                            
                            if (railExpanded) {
                                Spacer(modifier = Modifier.width(12.dp))
                                Text(
                                    text = item.label,
                                    color = if (isFocused || selectedIndex == index) Color.White else Color(0xFF9A9AA8),
                                    style = MaterialTheme.typography.labelLarge
                                )
                            }
                        }
                    }
                }
            }
        }

        // Page Content
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .onFocusChanged { if (it.isFocused) shellVm.setRailExpanded(false) }
        ) {
            key(selectedIndex) {
                when (selectedIndex) {
                    0 -> TvHomeScreen()
                    1 -> TvLiveTvScreen()
                    2 -> TvMoviesScreen()
                    3 -> TvSeriesScreen()
                    4 -> TvFavoritesScreen()
                    5 -> TvWatchLaterScreen()
                    6 -> TvSearchScreen()
                    7 -> TvSettingsScreen()
                    else -> TvHomeScreen()
                }
            }
        }
    }
}
