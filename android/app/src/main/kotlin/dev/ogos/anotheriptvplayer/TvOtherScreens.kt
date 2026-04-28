package dev.ogos.anotheriptvplayer

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.tv.material3.*
import kotlinx.coroutines.delay

@Composable
fun TvFavoritesScreen() {
    TvSavedContentScreen(title = "My Favorites", mode = SavedMode.FAVORITES)
}

@Composable
fun TvWatchLaterScreen() {
    TvSavedContentScreen(title = "Continue Watching", mode = SavedMode.WATCH_HISTORY)
}

enum class SavedMode { FAVORITES, WATCH_HISTORY }

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvSavedContentScreen(title: String, mode: SavedMode) {
    val contentVm: TvContentViewModel = viewModel()
    val state by contentVm.state.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        if (mode == SavedMode.FAVORITES) contentVm.loadFavorites(context)
        else contentVm.loadWatchHistory(context)
    }

    val items = if (mode == SavedMode.FAVORITES) state.favorites else state.watchHistory
    
    Column(modifier = Modifier.fillMaxSize().padding(48.dp)) {
        Text(title, style = MaterialTheme.typography.displayLarge.copy(fontSize = 48.sp))
        Spacer(modifier = Modifier.height(32.dp))

        if (items.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("No items found here.", color = TvColors.TextSecondary)
            }
        } else {
            LazyVerticalGrid(
                columns = GridCells.Adaptive(160.dp),
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(24.dp),
                horizontalArrangement = Arrangement.spacedBy(24.dp)
            ) {
                items(items) { item ->
                    TvCard(
                        item = item,
                        onClick = {
                            if (item.contentType == "series") contentVm.loadSeriesDetail(item)
                            else TvPlayerLauncher.play(context, item)
                        }
                    )
                }
            }
        }
    }

    state.seriesDetail?.let { detail ->
        TvSeriesDetailSheet(detail, context, { contentVm.clearSeriesDetail() })
    }
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvSearchScreen() {
    val contentVm: TvContentViewModel = viewModel()
    val state by contentVm.state.collectAsState()
    val context = LocalContext.current
    var query by remember { mutableStateOf("") }

    LaunchedEffect(query) {
        delay(500)
        contentVm.search(query)
    }

    Column(modifier = Modifier.fillMaxSize().padding(48.dp)) {
        Text("Search", style = MaterialTheme.typography.displayLarge.copy(fontSize = 48.sp))
        Spacer(modifier = Modifier.height(24.dp))

        TvTextField(
            value = query,
            onValueChange = { query = it },
            label = "Search channels, movies, series..."
        )

        Spacer(modifier = Modifier.height(32.dp))

        if (state.isSearching) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                androidx.compose.material3.CircularProgressIndicator(color = TvColors.Primary)
            }
        } else if (state.searchResults.isNotEmpty()) {
            LazyVerticalGrid(
                columns = GridCells.Adaptive(160.dp),
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(24.dp),
                horizontalArrangement = Arrangement.spacedBy(24.dp)
            ) {
                items(state.searchResults) { item ->
                    TvCard(
                        item = item,
                        onClick = {
                            if (item.contentType == "series") contentVm.loadSeriesDetail(item)
                            else TvPlayerLauncher.play(context, item)
                        }
                    )
                }
            }
        } else if (query.isNotEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("No results found for \"$query\"", color = TvColors.TextSecondary)
            }
        }
    }

    state.seriesDetail?.let { detail ->
        TvSeriesDetailSheet(detail, context, { contentVm.clearSeriesDetail() })
    }
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvSettingsScreen(onSwitchPlaylist: () -> Unit = {}) {
    val context = LocalContext.current
    val (username, _, serverUrl) = remember { TvRepository.getPlaylistCredentials() }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(48.dp)) {
        item {
            Text("Settings", style = MaterialTheme.typography.displayLarge.copy(fontSize = 48.sp))
            Spacer(modifier = Modifier.height(48.dp))
        }

        item {
            SectionTitle("Account")
            SettingsItem("Server URL", serverUrl)
            SettingsItem("Username", username)
            Spacer(modifier = Modifier.height(16.dp))
            TvSecondaryButton("Switch Playlist / Logout", onSwitchPlaylist, modifier = Modifier.width(300.dp))
        }

        item {
            Spacer(modifier = Modifier.height(48.dp))
            SectionTitle("Sync Status")
            SettingsItem("Logged In", if (TvSyncService.isLoggedIn) "Yes" else "No")
            if (TvSyncService.isLoggedIn) {
                TvPrimaryButton("Sync Now", { 
                    kotlinx.coroutines.GlobalScope.launch {
                        TvSyncApplier.pullAndApply(context)
                    }
                }, modifier = Modifier.width(300.dp))
            }
        }

        item {
            Spacer(modifier = Modifier.height(48.dp))
            SectionTitle("About")
            SettingsItem("App Version", "2.0.0 (Senior Refactor)")
            SettingsItem("Platform", "Native Android (Media3)")
        }
    }
}

@Composable
fun SectionTitle(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleLarge,
        color = TvColors.Primary,
        modifier = Modifier.padding(vertical = 12.dp)
    )
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun SettingsItem(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(label, color = TvColors.TextSecondary, style = MaterialTheme.typography.bodyMedium)
        Text(value, color = Color.White, style = MaterialTheme.typography.bodyMedium)
    }
}
