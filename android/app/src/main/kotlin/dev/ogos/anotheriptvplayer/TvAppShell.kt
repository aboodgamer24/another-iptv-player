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


@Composable
fun TvAppShell() {
    val context = LocalContext.current
    val shellVm: TvShellViewModel = viewModel()
    val contentVm: TvContentViewModel = viewModel()
    
    val selectedIndex by shellVm.selectedIndex.collectAsState()
    val railExpanded by shellVm.railExpanded.collectAsState()

    // Load initial data
    LaunchedEffect(Unit) {
        TvRepository.loadPlaylist(context)
        contentVm.loadContent()
    }

    val items = listOf(
        TvNavItem(Icons.Default.Home, "Home"),
        TvNavItem(Icons.Default.LiveTv, "Live TV"),
        TvNavItem(Icons.Default.Movie, "Movies"),
        TvNavItem(Icons.Default.Tv, "Series"),
        TvNavItem(Icons.Default.GridView, "Browse"),
        TvNavItem(Icons.Default.Favorite, "Favorites"),
        TvNavItem(Icons.Default.WatchLater, "Watch Later"),
        TvNavItem(Icons.Default.Settings, "Settings"),
    )

    NavigationDrawer(
        drawerContent = {
            Column(
                Modifier
                    .fillMaxHeight()
                    .padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items.forEachIndexed { index, item ->
                    val interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
                    val isFocused by interactionSource.collectIsFocusedAsState()

                    NavigationDrawerItem(
                        selected = selectedIndex == index,
                        onClick = { shellVm.setSelectedIndex(index) },
                        leadingContent = { Icon(item.icon, contentDescription = null) },
                        content = { Text(item.label) },
                        interactionSource = interactionSource,
                        colors = NavigationDrawerItemDefaults.colors(
                            selectedContainerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                            focusedContainerColor = Color.White.copy(alpha = 0.12f),
                            selectedContentColor = MaterialTheme.colorScheme.primary,
                            focusedContentColor = Color.White
                        ),
                        modifier = Modifier.border(
                            width = if (isFocused) 2.dp else 0.dp,
                            color = if (isFocused) MaterialTheme.colorScheme.primary else Color.Transparent,
                            shape = MaterialTheme.shapes.medium
                        )
                    )
                }
            }
        }
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
        ) {
            key(selectedIndex) {
                when (selectedIndex) {
                    0 -> TvHomeScreen()
                    1 -> TvLiveTvScreen()
                    2 -> TvMoviesScreen()
                    3 -> TvSeriesScreen()
                    4 -> TvBrowseScreen()
                    5 -> TvFavoritesScreen()
                    6 -> TvWatchLaterScreen()
                    7 -> TvSettingsScreen()
                    else -> TvHomeScreen()
                }
            }
        }
    }
}
