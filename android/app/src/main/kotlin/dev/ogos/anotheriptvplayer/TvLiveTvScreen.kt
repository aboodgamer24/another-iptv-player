package dev.ogos.anotheriptvplayer

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.tv.material3.*
import androidx.compose.material3.Text
import androidx.compose.material3.Icon

import coil.compose.AsyncImage

@Composable
fun TvLiveTvScreen() {
    val contentVm: TvContentViewModel = viewModel()
    val state by contentVm.state.collectAsState()
    val context = LocalContext.current
    var selectedCategoryId by remember { mutableStateOf<String?>(null) }

    // Set initial category
    LaunchedEffect(state.liveCategories) {
        if (selectedCategoryId == null && state.liveCategories.isNotEmpty()) {
            selectedCategoryId = state.liveCategories[0].id
        }
    }

    Row(modifier = Modifier.fillMaxSize()) {
        // Categories Panel
        LazyColumn(
            modifier = Modifier
                .width(240.dp)
                .fillMaxHeight()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(state.liveCategories) { category ->
                Button(
                    onClick = { selectedCategoryId = category.id },
                    modifier = Modifier.fillMaxWidth(),
                    scale = ButtonDefaults.scale(focusedScale = 1.1f)
                ) {
                    Text(category.name)
                }
            }
        }

        // Channels Grid
        val channels = state.liveChannels[selectedCategoryId] ?: emptyList()
        
        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
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
                            modifier = Modifier.aspectRatio(16/9f),
                            contentScale = androidx.compose.ui.layout.ContentScale.Crop
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
