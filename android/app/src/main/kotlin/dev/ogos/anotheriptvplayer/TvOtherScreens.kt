package dev.ogos.anotheriptvplayer

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.tv.material3.*
import androidx.compose.material3.Text
import androidx.compose.material3.Icon
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search

import kotlinx.coroutines.delay
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.WatchLater
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.IconButton
import androidx.compose.material3.TextButton
import androidx.compose.material3.TabRow
import androidx.tv.material3.Tab
import androidx.tv.material3.Border
import coil.compose.AsyncImage
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun TvFavoritesScreen() {
    TvSavedContentScreen(title = "Favorites", mode = SavedMode.FAVORITES)
}

@Composable
fun TvWatchLaterScreen() {
    TvSavedContentScreen(title = "Watch Later", mode = SavedMode.WATCH_HISTORY)
}

enum class SavedMode { FAVORITES, WATCH_HISTORY }

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
    val isLoading = if (mode == SavedMode.FAVORITES) state.isFavoritesLoading else state.isHistoryLoading

    var selectedTab by remember { mutableStateOf(0) }
    val tabs = listOf("All", "Live", "Movies", "Series")

    val filtered = when (selectedTab) {
        1 -> items.filter { it.contentType == "live" }
        2 -> items.filter { it.contentType == "movie" }
        3 -> items.filter { it.contentType == "series" }
        else -> items
    }

    Column(modifier = Modifier.fillMaxSize().padding(32.dp)) {
        Text(title, style = MaterialTheme.typography.headlineLarge, color = Color.White)
        Spacer(modifier = Modifier.height(24.dp))

        TabRow(selectedTabIndex = selectedTab) {
            tabs.forEachIndexed { index, label ->
                Tab(
                    selected = selectedTab == index,
                    onFocus = { selectedTab = index }
                ) {
                    Text(
                        text = label,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                        style = MaterialTheme.typography.titleMedium
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        when {
            isLoading -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                }
            }

            filtered.isEmpty() -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            imageVector = if (mode == SavedMode.FAVORITES)
                                Icons.Default.FavoriteBorder else Icons.Default.WatchLater,
                            contentDescription = null,
                            modifier = Modifier.size(80.dp),
                            tint = Color.White.copy(alpha = 0.2f)
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = if (mode == SavedMode.FAVORITES)
                                "No favorites yet — add some from the player"
                            else
                                "No watch history yet",
                            color = Color.White.copy(alpha = 0.5f),
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                }
            }

            else -> {
                LazyVerticalGrid(
                    columns = GridCells.Fixed(5),
                    modifier = Modifier.fillMaxSize(),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    items(filtered) { item ->
                        Surface(
                            onClick = {
                                when (item.contentType) {
                                    "live"   -> TvPlayerLauncher.play(context, item)
                                    "movie"  -> TvPlayerLauncher.play(context, item)
                                    "series" -> contentVm.loadSeriesDetail(item)
                                }
                            },
                            modifier = Modifier.aspectRatio(
                                if (item.contentType == "live") 16 / 9f else 2 / 3f
                            ),
                            scale = ClickableSurfaceDefaults.scale(focusedScale = 1.05f),
                            border = ClickableSurfaceDefaults.border(
                                focusedBorder = Border(
                                    BorderStroke(2.dp, MaterialTheme.colorScheme.primary)
                                )
                            ),
                            shape = ClickableSurfaceDefaults.shape(shape = MaterialTheme.shapes.medium)
                        ) {
                            Box(modifier = Modifier.fillMaxSize()) {
                                AsyncImage(
                                    model = item.imageUrl,
                                    contentDescription = null,
                                    modifier = Modifier.fillMaxSize(),
                                    contentScale = ContentScale.Crop
                                )
                                Box(
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .background(
                                            Brush.verticalGradient(
                                                listOf(Color.Transparent, Color.Black.copy(alpha = 0.85f))
                                            )
                                        )
                                )
                                Column(
                                    modifier = Modifier
                                        .align(Alignment.BottomStart)
                                        .padding(8.dp)
                                ) {
                                    Text(
                                        text = item.name,
                                        style = MaterialTheme.typography.labelMedium,
                                        color = Color.White,
                                        maxLines = 2
                                    )
                                    Text(
                                        text = item.contentType.uppercase(),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Series detail overlay
    state.seriesDetail?.let { detail ->
        TvSeriesDetailSheet(
            detail = detail,
            context = context,
            onDismiss = { contentVm.clearSeriesDetail() }
        )
    }
}

@Composable
fun TvSearchScreen() {
    val contentVm: TvContentViewModel = viewModel()
    val state by contentVm.state.collectAsState()
    val context = LocalContext.current
    val focusRequester = remember { FocusRequester() }
    var query by remember { mutableStateOf("") }

    // Debounce: trigger search 400ms after user stops typing
    LaunchedEffect(query) {
        delay(400)
        contentVm.search(query)
    }

    Column(modifier = Modifier.fillMaxSize().padding(32.dp)) {
        Text("Search", style = MaterialTheme.typography.headlineLarge, color = Color.White)
        Spacer(modifier = Modifier.height(24.dp))

        TextField(
            value = query,
            onValueChange = { query = it },
            modifier = Modifier.fillMaxWidth().focusRequester(focusRequester),
            placeholder = { Text("Search channels, movies, shows...", color = Color.Gray) },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = Color.White) },
            trailingIcon = {
                if (query.isNotEmpty()) {
                    IconButton(onClick = { query = "" }) {
                        Icon(Icons.Default.Clear, contentDescription = "Clear", tint = Color.White)
                    }
                }
            },
            colors = TextFieldDefaults.colors(
                focusedContainerColor = MaterialTheme.colorScheme.surface,
                unfocusedContainerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.5f),
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                cursorColor = MaterialTheme.colorScheme.primary
            )
        )

        LaunchedEffect(Unit) { focusRequester.requestFocus() }

        Spacer(modifier = Modifier.height(24.dp))

        when {
            query.isEmpty() -> {
                // Empty state
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            Icons.Default.Search,
                            contentDescription = null,
                            modifier = Modifier.size(80.dp),
                            tint = Color.White.copy(alpha = 0.2f)
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            "Search for your favorite content",
                            color = Color.White.copy(alpha = 0.5f),
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                }
            }

            state.isSearching -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                }
            }

            state.searchResults.isEmpty() -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            Icons.Default.SearchOff,
                            contentDescription = null,
                            modifier = Modifier.size(64.dp),
                            tint = Color.White.copy(alpha = 0.2f)
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            "No results for \"${state.searchQuery}\"",
                            color = Color.White.copy(alpha = 0.5f),
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                }
            }

            else -> {
                // Results header
                Text(
                    "${state.searchResults.size} results for \"${state.searchQuery}\"",
                    color = Color.White.copy(alpha = 0.6f),
                    style = MaterialTheme.typography.bodyMedium
                )
                Spacer(modifier = Modifier.height(16.dp))

                LazyVerticalGrid(
                    columns = GridCells.Fixed(5),
                    modifier = Modifier.fillMaxSize(),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    items(state.searchResults) { item ->
                        Surface(
                            onClick = {
                                when (item.contentType) {
                                    "live" -> TvPlayerLauncher.play(context, item)
                                    "movie" -> TvPlayerLauncher.play(context, item)
                                    "series" -> contentVm.loadSeriesDetail(item)
                                }
                            },
                            modifier = Modifier.aspectRatio(
                                if (item.contentType == "live") 16 / 9f else 2 / 3f
                            ),
                            scale = ClickableSurfaceDefaults.scale(focusedScale = 1.05f),
                            border = ClickableSurfaceDefaults.border(
                                focusedBorder = Border(
                                    BorderStroke(2.dp, MaterialTheme.colorScheme.primary)
                                )
                            ),
                            shape = ClickableSurfaceDefaults.shape(shape = MaterialTheme.shapes.medium)
                        ) {
                            Box(modifier = Modifier.fillMaxSize()) {
                                AsyncImage(
                                    model = item.imageUrl,
                                    contentDescription = null,
                                    modifier = Modifier.fillMaxSize(),
                                    contentScale = ContentScale.Crop
                                )
                                Box(
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .background(
                                            Brush.verticalGradient(
                                                listOf(Color.Transparent, Color.Black.copy(alpha = 0.85f))
                                            )
                                        )
                                )
                                Column(
                                    modifier = Modifier
                                        .align(Alignment.BottomStart)
                                        .padding(8.dp)
                                ) {
                                    Text(
                                        text = item.name,
                                        style = MaterialTheme.typography.labelMedium,
                                        color = Color.White,
                                        maxLines = 2
                                    )
                                    Text(
                                        text = when (item.contentType) {
                                            "live" -> "LIVE"
                                            "movie" -> "MOVIE"
                                            "series" -> "SERIES"
                                            else -> ""
                                        },
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Series detail overlay (reuses the same sheet from TvMoviesScreen)
    state.seriesDetail?.let { detail ->
        TvSeriesDetailSheet(
            detail = detail,
            context = context,
            onDismiss = { contentVm.clearSeriesDetail() }
        )
    }
}

@Composable
fun TvSettingsScreen(onSwitchPlaylist: () -> Unit = {}) {
    // Read current playlist info from TvRepository
    val context = LocalContext.current
    val (username, _, serverUrl) = remember { TvRepository.getPlaylistCredentials() }
    val playlistDisplay = if (serverUrl.isNotBlank()) serverUrl else "Not configured"

    // Dialog state
    var showAboutDialog by remember { mutableStateOf(false) }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(32.dp)) {
        item {
            Text("Settings", style = MaterialTheme.typography.headlineLarge, color = Color.White)
            Spacer(modifier = Modifier.height(32.dp))
        }

        // GROUP: Account
        item { SectionHeader("Account") }
        item {
            SettingsRow(
                label = "Playlist",
                value = playlistDisplay,
                onClick = {} // read-only info row, no action
            )
        }
        item {
            SettingsRow(
                label = "Switch / Re-login",
                value = "Change your playlist or server",
                onClick = onSwitchPlaylist
            )
        }

        item { Spacer(modifier = Modifier.height(24.dp)) }

        // GROUP: About
        item { SectionHeader("About") }
        item {
            SettingsRow(
                label = "App version",
                value = "1.0.0",
                onClick = {}
            )
        }
        item {
            SettingsRow(
                label = "Open source licenses",
                value = "",
                onClick = { showAboutDialog = true }
            )
        }
    }

    if (showAboutDialog) {
        AlertDialog(
            onDismissRequest = { showAboutDialog = false },
            title = { Text("Open Source Licenses") },
            text = { Text("ExoPlayer (Media3) — Apache 2.0\nRetrofit — Apache 2.0\nCoil — Apache 2.0\nJetpack Compose — Apache 2.0") },
            confirmButton = {
                TextButton(onClick = { showAboutDialog = false }) { Text("Close") }
            }
        )
    }
}

@Composable
private fun SectionHeader(title: String) {
    Column {
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.primary
        )
        Spacer(modifier = Modifier.height(16.dp))
    }
}

@Composable
private fun SettingsRow(label: String, value: String, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp).height(64.dp),
        colors = ClickableSurfaceDefaults.colors(
            containerColor = Color.Transparent,
            focusedContainerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Row(
            modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(label, color = Color.White, style = MaterialTheme.typography.bodyLarge)
            if (value.isNotBlank()) {
                Text(value, color = Color.White.copy(alpha = 0.5f), style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}
