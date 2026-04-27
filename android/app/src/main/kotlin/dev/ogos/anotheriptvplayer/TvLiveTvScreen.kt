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
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.focus.onFocusChanged
import androidx.tv.material3.Surface
import androidx.tv.material3.ClickableSurfaceDefaults
import androidx.tv.material3.SelectableSurfaceDefaults
import androidx.compose.foundation.background
import androidx.compose.foundation.BorderStroke
import androidx.tv.material3.Border
import androidx.compose.ui.layout.ContentScale
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
        // CATEGORY LIST (w=260)
        LazyColumn(
            modifier = Modifier
                .width(260.dp)
                .fillMaxHeight()
                .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.5f))
                .padding(vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            items(state.liveCategories) { category ->
                val isSelected = selectedCategoryId == category.id
                Surface(
                    selected = isSelected,
                    onClick = { 
                        selectedCategoryId = category.id
                        contentVm.loadLiveChannels(category.id)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    colors = SelectableSurfaceDefaults.colors(
                        containerColor = if (isSelected) MaterialTheme.colorScheme.secondary else Color.Transparent,
                        focusedContainerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                    ),
                    shape = SelectableSurfaceDefaults.shape(shape = MaterialTheme.shapes.extraSmall)
                ) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.CenterStart) {
                        Row(
                            modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            if (isSelected) {
                                Box(modifier = Modifier.width(3.dp).height(20.dp).background(MaterialTheme.colorScheme.primary))
                                Spacer(modifier = Modifier.width(12.dp))
                            }
                            Text(
                                text = category.name,
                                style = MaterialTheme.typography.bodyLarge,
                                color = if (isSelected) Color.White else Color(0xFF9A9AA8),
                                maxLines = 1
                            )
                        }
                    }
                }
            }
        }

        // CHANNEL GRID
        val channels = state.liveChannels[selectedCategoryId] ?: emptyList()
        
        LazyVerticalGrid(
            columns = GridCells.Fixed(4),
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(24.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
            horizontalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            items(channels) { channel ->
                var isFocused by remember { mutableStateOf(false) }
                Surface(
                    onClick = { TvPlayerLauncher.play(context, channel) },
                    modifier = Modifier
                        .aspectRatio(16/9f)
                        .onFocusChanged { isFocused = it.isFocused },
                    scale = ClickableSurfaceDefaults.scale(focusedScale = 1.05f),
                    border = ClickableSurfaceDefaults.border(
                        focusedBorder = Border(BorderStroke(2.5.dp, MaterialTheme.colorScheme.primary))
                    ),
                    shape = ClickableSurfaceDefaults.shape(shape = MaterialTheme.shapes.medium)
                ) {
                    Box(modifier = Modifier.fillMaxSize()) {
                        AsyncImage(
                            model = channel.imageUrl,
                            contentDescription = null,
                            modifier = Modifier.fillMaxSize(),
                            contentScale = androidx.compose.ui.layout.ContentScale.Crop
                        )
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(androidx.compose.ui.graphics.Brush.verticalGradient(
                                    listOf(Color.Transparent, Color.Black.copy(alpha = 0.8f))
                                ))
                        )
                        Text(
                            text = channel.name,
                            modifier = Modifier.align(Alignment.BottomStart).padding(8.dp),
                            style = MaterialTheme.typography.labelMedium,
                            color = Color.White
                        )
                    }
                }
            }
        }
    }
}
