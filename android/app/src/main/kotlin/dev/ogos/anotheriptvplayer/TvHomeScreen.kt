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
import coil.compose.AsyncImage

@Composable
fun TvHomeScreen() {
    val contentVm: TvContentViewModel = viewModel()
    val state by contentVm.state.collectAsState()
    val context = LocalContext.current

    Box(modifier = Modifier.fillMaxSize()) {
        if (state.isLoading) {
            CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
        } else {
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
                            fontWeight = FontWeight.Bold
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
                                            style = MaterialTheme.typography.labelMedium
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
