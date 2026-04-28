package dev.ogos.anotheriptvplayer

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
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
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.tv.material3.*
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.Button
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SentimentDissatisfied
import androidx.compose.material.icons.filled.WifiOff
import coil.compose.AsyncImage

@Composable
fun TvHomeScreen() {
    val contentVm: TvContentViewModel = viewModel()
    val state by contentVm.state.collectAsState()
    val context = LocalContext.current

    Box(modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        when {
            // Loading state — show shimmer or spinner
            state.isLoading -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                }
            }

            // No playlist at all
            state.noPlaylist -> {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        Icons.Default.SentimentDissatisfied,
                        contentDescription = null,
                        tint = Color.White.copy(alpha = 0.3f),
                        modifier = Modifier.size(80.dp)
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        "No playlist configured",
                        style = MaterialTheme.typography.headlineMedium,
                        color = Color.White.copy(alpha = 0.5f)
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        "Go to Settings to add your Xtream playlist",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White.copy(alpha = 0.3f)
                    )
                }
            }

            // API error
            state.loadError.isNotBlank() -> {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        Icons.Default.WifiOff,
                        contentDescription = null,
                        tint = Color.White.copy(alpha = 0.3f),
                        modifier = Modifier.size(80.dp)
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        "Could not reach server",
                        style = MaterialTheme.typography.headlineMedium,
                        color = Color.White.copy(alpha = 0.5f)
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        state.loadError,
                        style = MaterialTheme.typography.bodySmall,
                        color = Color.White.copy(alpha = 0.3f)
                    )
                    Spacer(modifier = Modifier.height(24.dp))
                    Button(onClick = { contentVm.loadContent(context) }) {
                        Text("Retry")
                    }
                }
            }

            // Content loaded but all rows are empty
            state.liveChannels.isEmpty() && state.vodItems.isEmpty() && state.seriesItems.isEmpty() -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                }
            }

            // Happy path — render rows
            else -> {
                TvHomeContent(state = state, contentVm = contentVm, context = context)
            }
        }
    }
}

@Composable
private fun TvHomeContent(
    state: TvContentState,
    contentVm: TvContentViewModel,
    context: android.content.Context
) {
    Column(modifier = Modifier.fillMaxSize()) {
        // Hero Banner
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(320.dp)
        ) {
            val firstItem = state.liveChannels.values.firstOrNull()?.firstOrNull()
            
            if (firstItem != null) {
                AsyncImage(
                    model = firstItem.imageUrl,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
                )
            }

            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, MaterialTheme.colorScheme.background)
                        )
                    )
            )

            Column(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(32.dp)
            ) {
                Text(
                    text = firstItem?.name ?: "Welcome to C4-TV",
                    style = MaterialTheme.typography.displayMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(12.dp))
                Button(onClick = { 
                    firstItem?.let { TvPlayerLauncher.play(context, it) }
                }) {
                    Text("Watch Now")
                }
            }
        }

        // Recommendations / Categories
        state.liveCategories.take(5).forEach { category ->
            val channels = state.liveChannels[category.id] ?: emptyList()
            if (channels.isNotEmpty()) {
                Text(
                    text = category.name,
                    style = MaterialTheme.typography.headlineSmall,
                    color = Color.White,
                    modifier = Modifier.padding(horizontal = 32.dp, vertical = 12.dp)
                )
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 32.dp),
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    items(channels) { channel ->
                        Card(
                            onClick = { TvPlayerLauncher.play(context, channel) }
                        ) {
                            Column {
                                AsyncImage(
                                    model = channel.imageUrl,
                                    contentDescription = null,
                                    modifier = Modifier.size(160.dp, 90.dp),
                                    contentScale = ContentScale.Crop
                                )
                                Text(
                                    text = channel.name,
                                    modifier = Modifier.padding(8.dp),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = Color.White
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
