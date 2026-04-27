package dev.ogos.anotheriptvplayer

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.HorizontalDivider
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.*

enum class SidePanelTab { INFO, CHANNELS, EPISODES }

@Composable
fun TvSidePanel(
    visible: Boolean,
    state: PlayerUiState,
    queue: List<PlayerViewModel.QueueItem>,
    contentType: String,
    onIndexSelected: (Int) -> Unit,
    onDismiss: () -> Unit,
) {
    AnimatedVisibility(
        visible = visible,
        enter = slideInHorizontally { it },
        exit  = slideOutHorizontally { it },
    ) {
        Box(
            Modifier
                .fillMaxHeight()
                .width(360.dp)
                .background(Color(0xE0101010))
                .padding(vertical = 16.dp)
        ) {
            var activeTab by remember { mutableStateOf(SidePanelTab.INFO) }

            Column(Modifier.fillMaxSize()) {
                // Tab row
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    listOf(
                        SidePanelTab.INFO     to "Info",
                        SidePanelTab.CHANNELS to "Channels",
                        SidePanelTab.EPISODES to "Episodes",
                    ).forEach { (tab, label) ->
                        SidePanelTabButton(
                            label = label,
                            selected = activeTab == tab,
                            onClick = { activeTab = tab }
                        )
                    }
                }

                HorizontalDivider(color = Color.White.copy(alpha = 0.15f), modifier = Modifier.padding(vertical = 8.dp))

                when (activeTab) {
                    SidePanelTab.INFO -> InfoTab(state, contentType)
                    SidePanelTab.CHANNELS -> ListTab(
                        items = queue,
                        currentIndex = state.currentIndex,
                        emptyLabel = "No channels available",
                        onSelect = onIndexSelected
                    )
                    SidePanelTab.EPISODES -> ListTab(
                        items = queue,
                        currentIndex = state.currentIndex,
                        emptyLabel = "No episodes available",
                        onSelect = onIndexSelected
                    )
                }
            }
        }
    }
}

@Composable
private fun SidePanelTabButton(label: String, selected: Boolean, onClick: () -> Unit) {
    val bg = if (selected) Color(0xFF01696F) else Color.Transparent
    val textColor = if (selected) Color.White else Color.White.copy(alpha = 0.6f)
    Surface(
        onClick = onClick,
        modifier = Modifier.padding(4.dp),
        shape = ClickableSurfaceDefaults.shape(shape = MaterialTheme.shapes.small),
        colors = ClickableSurfaceDefaults.colors(
            containerColor = bg,
            focusedContainerColor = if (selected) bg else Color.White.copy(alpha = 0.1f)
        ),
    ) {
        Text(
            text = label,
            color = textColor,
            fontSize = 13.sp,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
        )
    }
}

@Composable
private fun InfoTab(state: PlayerUiState, contentType: String) {
    Column(
        Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(state.title, color = Color.White, fontSize = 15.sp, maxLines = 2)
        HorizontalDivider(color = Color.White.copy(alpha = 0.1f))
        InfoRow("Type", contentType.replaceFirstChar { it.uppercase() })
        if (state.videoWidth > 0) InfoRow("Resolution", "${state.videoWidth}×${state.videoHeight}")
        if (state.codec.isNotBlank()) InfoRow("Codec", state.codec.removePrefix("video/").uppercase())
        if (state.frameRate > 0) InfoRow("FPS", "%.1f".format(state.frameRate))
        else InfoRow("Engine", "Media3 ExoPlayer")
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = Color.White.copy(alpha = 0.55f), fontSize = 12.sp)
        Text(value, color = Color.White, fontSize = 12.sp)
    }
}

@Composable
private fun ListTab(
    items: List<PlayerViewModel.QueueItem>,
    currentIndex: Int,
    emptyLabel: String,
    onSelect: (Int) -> Unit,
) {
    if (items.isEmpty()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(emptyLabel, color = Color.White.copy(alpha = 0.4f), fontSize = 13.sp)
        }
        return
    }
    val listState = rememberLazyListState(initialFirstVisibleItemIndex = currentIndex.coerceAtLeast(0))
    LazyColumn(state = listState, modifier = Modifier.fillMaxSize()) {
        itemsIndexed(items) { index, item ->
            val isSelected = index == currentIndex
            val bg = if (isSelected) Color(0xFF01696F).copy(alpha = 0.35f) else Color.Transparent
            Surface(
                onClick = { onSelect(index) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 3.dp),
                shape = ClickableSurfaceDefaults.shape(shape = MaterialTheme.shapes.small),
                colors = ClickableSurfaceDefaults.colors(
                    containerColor = bg,
                    focusedContainerColor = Color(0xFF01696F).copy(alpha = 0.5f)
                ),
            ) {
                Row(
                    Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        item.title.ifBlank { "Item ${index + 1}" },
                        color = if (isSelected) Color.White else Color.White.copy(alpha = 0.75f),
                        fontSize = 13.sp,
                        maxLines = 1,
                        modifier = Modifier.weight(1f)
                    )
                    if (isSelected) {
                        Text("▶", color = Color(0xFF4F98A3), fontSize = 12.sp)
                    }
                }
            }
        }
    }
}
