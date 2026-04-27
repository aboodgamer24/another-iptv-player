package dev.ogos.anotheriptvplayer

import androidx.compose.foundation.BorderStroke
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
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.tv.material3.*
import androidx.compose.material3.Text
import coil.compose.AsyncImage

@Composable
fun TvMoviesScreen() {
    TvContentGridScreen(contentType = "movie")
}

@Composable
fun TvSeriesScreen() {
    TvContentGridScreen(contentType = "series")
}

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
            if (contentType == "movie") contentVm.loadVodMovies(categories[0].id)
            else contentVm.loadSeries(categories[0].id)
        }
    }

    Row(modifier = Modifier.fillMaxSize()) {
        // CATEGORY LIST
        LazyColumn(
            modifier = Modifier
                .width(260.dp)
                .fillMaxHeight()
                .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.5f))
                .padding(vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            items(categories) { category ->
                val isSelected = selectedCategoryId == category.id
                Surface(
                    selected = isSelected,
                    onClick = { 
                        selectedCategoryId = category.id
                        if (contentType == "movie") contentVm.loadVodMovies(category.id)
                        else contentVm.loadSeries(category.id)
                    },
                    modifier = Modifier.fillMaxWidth().height(48.dp),
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

        // CONTENT GRID
        val items = contentMap[selectedCategoryId] ?: emptyList()
        
        LazyVerticalGrid(
            columns = GridCells.Fixed(5),
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(24.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
            horizontalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            items(items) { item ->
                Surface(
                    onClick = { /* Navigate to Detail */ },
                    modifier = Modifier
                        .aspectRatio(2/3f),
                    scale = ClickableSurfaceDefaults.scale(focusedScale = 1.05f),
                    border = ClickableSurfaceDefaults.border(
                        focusedBorder = Border(BorderStroke(2.5.dp, MaterialTheme.colorScheme.primary))
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
                                .background(androidx.compose.ui.graphics.Brush.verticalGradient(
                                    listOf(Color.Transparent, Color.Black.copy(alpha = 0.8f))
                                ))
                        )
                        Text(
                            text = item.name,
                            modifier = Modifier.align(Alignment.BottomStart).padding(8.dp),
                            style = MaterialTheme.typography.labelMedium,
                            color = Color.White,
                            maxLines = 2
                        )
                    }
                }
            }
        }
    }
}
