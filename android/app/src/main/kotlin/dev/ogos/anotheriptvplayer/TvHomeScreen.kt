package dev.ogos.anotheriptvplayer

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.tv.material3.*
import coil.compose.AsyncImage

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvHomeScreen() {
    val context = LocalContext.current
    val contentVm: TvContentViewModel = viewModel()
    val state by contentVm.state.collectAsState()

    LaunchedEffect(Unit) {
        contentVm.loadFavorites(context)
        contentVm.loadWatchHistory(context)
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 48.dp)
    ) {
        // Hero Section
        item {
            HeroSection(state)
        }

        // Continue Watching
        if (state.watchHistory.isNotEmpty()) {
            item {
                ContentShelf("Continue Watching", state.watchHistory)
            }
        }

        // Favorites
        if (state.favorites.isNotEmpty()) {
            item {
                ContentShelf("My Favorites", state.favorites)
            }
        }

        // Categories Shelves
        state.liveCategories.take(3).forEach { category ->
            item {
                val items = state.liveChannels[category.id] ?: emptyList()
                if (items.isNotEmpty()) {
                    ContentShelf(category.name, items)
                }
            }
        }

        state.vodCategories.take(3).forEach { category ->
            item {
                val items = state.vodItems[category.id] ?: emptyList()
                if (items.isNotEmpty()) {
                    ContentShelf(category.name, items)
                }
            }
        }
    }
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun HeroSection(state: TvContentState) {
    val featured = state.liveChannels.values.flatten().firstOrNull() ?: state.favorites.firstOrNull()
    
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(400.dp)
    ) {
        if (featured != null) {
            AsyncImage(
                model = featured.imageUrl,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop
            )
        }
        
        // Gradient overlay
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Color.Transparent, TvColors.Background),
                        startY = 100f
                    )
                )
        )
        
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(horizontal = 48.dp, vertical = 48.dp)
        ) {
            Text(
                text = "FEATURED",
                style = MaterialTheme.typography.labelSmall,
                color = TvColors.Primary,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = featured?.name ?: "Welcome to Another IPTV",
                style = MaterialTheme.typography.displayLarge.copy(fontSize = 48.sp),
                maxLines = 2
            )
            Spacer(modifier = Modifier.height(16.dp))
            Row {
                TvPrimaryButton("Watch Now", {})
                Spacer(modifier = Modifier.width(16.dp))
                TvSecondaryButton("More Info", {})
            }
        }
    }
}

@Composable
fun ContentShelf(title: String, items: List<TvContentItem>) {
    val context = LocalContext.current
    Column(modifier = Modifier.padding(vertical = 16.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.padding(horizontal = 48.dp, vertical = 8.dp)
        )
        LazyRow(
            contentPadding = PaddingValues(horizontal = 48.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(items) { item ->
                TvCard(
                    item = item,
                    onClick = {
                        TvPlayerLauncher.launch(context, item)
                    }
                )
            }
        }
    }
}
