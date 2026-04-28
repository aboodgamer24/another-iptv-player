package dev.ogos.anotheriptvplayer

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items as lazyGridItems
import androidx.compose.foundation.lazy.items as lazyListItems
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.tv.material3.*
import androidx.activity.compose.BackHandler
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow

@Composable
fun TvMoviesScreen() {
    TvContentGridScreen(contentType = "movie")
}

@Composable
fun TvSeriesScreen() {
    TvContentGridScreen(contentType = "series")
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvContentGridScreen(contentType: String) {
    val contentVm: TvContentViewModel = viewModel()
    val state by contentVm.state.collectAsState()
    val context = LocalContext.current
    
    val categories = if (contentType == "movie") state.vodCategories else state.seriesCategories
    val contentMap = if (contentType == "movie") state.vodItems else state.seriesItems
    
    var selectedCategoryId by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(categories) {
        if (selectedCategoryId == null && categories.isNotEmpty()) {
            selectedCategoryId = categories[0].id
        }
    }

    LaunchedEffect(selectedCategoryId) {
        selectedCategoryId?.let { id ->
            if (contentMap[id].isNullOrEmpty()) {
                if (contentType == "movie") contentVm.loadVodMovies(id)
                else contentVm.loadSeries(id)
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Row(modifier = Modifier.fillMaxSize()) {
            // Sidebar
            LazyColumn(
                modifier = Modifier
                    .width(260.dp)
                    .fillMaxHeight()
                    .background(TvColors.Surface)
                    .padding(vertical = 16.dp, horizontal = 12.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                item {
                    Text(
                        if (contentType == "movie") "Movies" else "Series",
                        style = MaterialTheme.typography.headlineMedium,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 16.dp)
                    )
                }
                lazyListItems(categories) { category ->
                    TvCategoryItem(
                        category = category,
                        isSelected = selectedCategoryId == category.id,
                        onClick = { selectedCategoryId = category.id }
                    )
                }
            }

            // Grid
            val items = contentMap[selectedCategoryId] ?: emptyList()
            if (state.isLoading && items.isEmpty()) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    androidx.compose.material3.CircularProgressIndicator(color = TvColors.Primary)
                }
            } else {
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(150.dp),
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(32.dp),
                    verticalArrangement = Arrangement.spacedBy(24.dp),
                    horizontalArrangement = Arrangement.spacedBy(24.dp)
                ) {
                    lazyGridItems(items) { item ->
                        TvCard(
                            item = item,
                            onClick = {
                                if (contentType == "movie") {
                                    TvPlayerLauncher.play(context, item)
                                } else {
                                    contentVm.loadSeriesDetail(item)
                                }
                            },
                            aspectRatio = 2/3f
                        )
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
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvSeriesDetailSheet(
    detail: SeriesDetailState,
    context: android.content.Context,
    onDismiss: () -> Unit
) {
    var selectedSeasonIndex by remember { mutableStateOf(0) }
    val seasonKeys = detail.seasons.keys.toList().sortedBy { it.toIntOrNull() ?: 0 }
    val episodes = if (seasonKeys.isNotEmpty()) detail.seasons[seasonKeys[selectedSeasonIndex]] ?: emptyList() else emptyList()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(TvColors.Background.copy(alpha = 0.98f))
            .padding(48.dp)
    ) {
        if (detail.isLoading) {
            androidx.compose.material3.CircularProgressIndicator(
                modifier = Modifier.align(Alignment.Center),
                color = TvColors.Primary
            )
        } else {
            Row(modifier = Modifier.fillMaxSize()) {
                // Info
                Column(modifier = Modifier.width(360.dp)) {
                    TvCard(item = detail.item, onClick = {}, aspectRatio = 2/3f, modifier = Modifier.width(360.dp))
                    Spacer(modifier = Modifier.height(24.dp))
                    Text(detail.item.name, style = MaterialTheme.typography.headlineMedium)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(detail.item.plot, style = MaterialTheme.typography.bodyMedium, color = TvColors.TextSecondary)
                    Spacer(modifier = Modifier.weight(1f))
                    TvSecondaryButton("Close", onDismiss, modifier = Modifier.fillMaxWidth())
                }

                Spacer(modifier = Modifier.width(64.dp))

                // Seasons & Episodes
                Column(modifier = Modifier.weight(1f)) {
                    if (seasonKeys.size > 1) {
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(seasonKeys.size) { index ->
                                var isFocused by remember { mutableStateOf(false) }
                                Surface(
                                    selected = selectedSeasonIndex == index,
                                    onClick = { selectedSeasonIndex = index },
                                    modifier = Modifier.onFocusChanged { isFocused = it.isFocused },
                                    colors = SelectableSurfaceDefaults.colors(
                                        containerColor = Color.Transparent,
                                        selectedContainerColor = TvColors.Primary
                                    )
                                ) {
                                    Text("Season ${seasonKeys[index]}", modifier = Modifier.padding(12.dp))
                                }
                            }
                        }
                        Spacer(modifier = Modifier.height(24.dp))
                    }

                    LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        lazyListItems(episodes) { episode ->
                            TvEpisodeItem(episode) {
                                TvPlayerLauncher.play(context, episode)
                            }
                        }
                    }
                }
            }
        }
    }
    BackHandler(onBack = onDismiss)
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvEpisodeItem(episode: TvContentItem, onClick: () -> Unit) {
    var isFocused by remember { mutableStateOf(false) }
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().onFocusChanged { isFocused = it.isFocused },
        colors = ClickableSurfaceDefaults.colors(
            containerColor = TvColors.Surface,
            focusedContainerColor = Color.White.copy(alpha = 0.1f)
        ),
        shape = ClickableSurfaceDefaults.shape(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
    ) {
        Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(episode.name, style = MaterialTheme.typography.bodyMedium, color = Color.White)
            Spacer(modifier = Modifier.weight(1f))
            if (isFocused) {
                Icon(Icons.Default.PlayArrow, contentDescription = null, tint = TvColors.Primary)
            }
        }
    }
}
