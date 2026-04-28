package dev.ogos.anotheriptvplayer

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.tv.material3.*

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvLiveTvScreen() {
    val contentVm: TvContentViewModel = viewModel()
    val state by contentVm.state.collectAsState()
    val context = LocalContext.current
    var selectedCategoryId by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(state.liveCategories) {
        if (selectedCategoryId == null && state.liveCategories.isNotEmpty()) {
            selectedCategoryId = state.liveCategories[0].id
        }
    }

    LaunchedEffect(selectedCategoryId) {
        selectedCategoryId?.let { id ->
            if (state.liveChannels[id].isNullOrEmpty()) {
                contentVm.loadLiveChannels(id)
            }
        }
    }

    Row(modifier = Modifier.fillMaxSize()) {
        // Categories Sidebar
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
                    "Live TV",
                    style = MaterialTheme.typography.headlineMedium,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 16.dp)
                )
            }
            items(state.liveCategories) { category ->
                val isSelected = selectedCategoryId == category.id
                TvCategoryItem(
                    category = category,
                    isSelected = isSelected,
                    onClick = { selectedCategoryId = category.id }
                )
            }
        }

        // Channels Grid
        val channels = state.liveChannels[selectedCategoryId] ?: emptyList()
        if (state.isLoading && channels.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                androidx.compose.material3.CircularProgressIndicator(color = TvColors.Primary)
            }
        } else {
            LazyVerticalGrid(
                columns = GridCells.Adaptive(180.dp),
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(32.dp),
                verticalArrangement = Arrangement.spacedBy(24.dp),
                horizontalArrangement = Arrangement.spacedBy(24.dp)
            ) {
                items(channels) { channel ->
                    TvCard(
                        item = channel,
                        onClick = { TvPlayerLauncher.play(context, channel) },
                        aspectRatio = 16/9f
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvCategoryItem(
    category: TvCategory,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    var isFocused by remember { mutableStateOf(false) }
    Surface(
        selected = isSelected,
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .onFocusChanged { isFocused = it.isFocused },
        colors = SelectableSurfaceDefaults.colors(
            containerColor = Color.Transparent,
            focusedContainerColor = Color.White.copy(alpha = 0.1f),
            selectedContainerColor = TvColors.Primary.copy(alpha = 0.1f),
            focusedSelectedContainerColor = TvColors.Primary
        ),
        shape = SelectableSurfaceDefaults.shape(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
    ) {
        Box(modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp), contentAlignment = Alignment.CenterStart) {
            Text(
                text = category.name,
                style = MaterialTheme.typography.bodyMedium,
                color = if (isFocused || isSelected) Color.White else TvColors.TextSecondary,
                fontWeight = if (isFocused || isSelected) FontWeight.Bold else FontWeight.Normal,
                maxLines = 1
            )
        }
    }
}
