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

@Composable
fun TvFavoritesScreen() {
    TvTabbedContentScreen(title = "Favorites")
}

@Composable
fun TvWatchLaterScreen() {
    TvTabbedContentScreen(title = "Watch Later")
}

@Composable
fun TvTabbedContentScreen(title: String) {
    var selectedTab by remember { mutableStateOf(0) }
    val tabs = listOf("Live", "Movies", "Series")

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
        
        // Grid Content (Placeholder for now)
        LazyVerticalGrid(
            columns = GridCells.Fixed(5),
            modifier = Modifier.fillMaxSize(),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(15) { i ->
                Surface(
                    onClick = {},
                    modifier = Modifier.aspectRatio(if (selectedTab == 0) 16/9f else 2/3f),
                    colors = ClickableSurfaceDefaults.colors(containerColor = MaterialTheme.colorScheme.surface)
                ) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("Item $i", color = Color.White.copy(alpha = 0.5f))
                    }
                }
            }
        }
    }
}

@Composable
fun TvSearchScreen() {
    val focusRequester = remember { FocusRequester() }
    var query by remember { mutableStateOf("") }

    Column(modifier = Modifier.fillMaxSize().padding(32.dp)) {
        Text("Search", style = MaterialTheme.typography.headlineLarge, color = Color.White)
        Spacer(modifier = Modifier.height(24.dp))
        
        TextField(
            value = query,
            onValueChange = { query = it },
            modifier = Modifier
                .fillMaxWidth()
                .focusRequester(focusRequester),
            placeholder = { Text("Search channels, movies, shows...", color = Color.Gray) },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = Color.White) },
            colors = TextFieldDefaults.colors(
                focusedContainerColor = MaterialTheme.colorScheme.surface,
                unfocusedContainerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.5f),
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                cursorColor = MaterialTheme.colorScheme.primary
            )
        )
        
        LaunchedEffect(Unit) {
            focusRequester.requestFocus()
        }

        Spacer(modifier = Modifier.height(24.dp))
        
        if (query.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Default.Search, contentDescription = null, modifier = Modifier.size(80.dp), tint = Color.White.copy(alpha = 0.2f))
                    Text("Search for your favorite content", color = Color.White.copy(alpha = 0.5f))
                }
            }
        } else {
            // Results Grid
            LazyVerticalGrid(
                columns = GridCells.Fixed(5),
                modifier = Modifier.fillMaxSize(),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                items(10) { i ->
                    Surface(
                        onClick = {},
                        modifier = Modifier.aspectRatio(2/3f),
                        colors = ClickableSurfaceDefaults.colors(containerColor = MaterialTheme.colorScheme.surface)
                    ) {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text("Result $i", modifier = Modifier.padding(8.dp), color = Color.White)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun TvSettingsScreen() {
    val settingsGroups = listOf(
        "Account" to listOf("Playlist: Current", "Re-login / Switch playlist"),
        "Playback" to listOf("Default quality", "Subtitle size", "Subtitle language"),
        "Appearance" to listOf("Language", "Theme (Dark only)"),
        "About" to listOf("App version: 1.0.0", "Open source licenses")
    )

    LazyColumn(modifier = Modifier.fillMaxSize().padding(32.dp)) {
        item {
            Text("Settings", style = MaterialTheme.typography.headlineLarge, color = Color.White)
            Spacer(modifier = Modifier.height(32.dp))
        }

        settingsGroups.forEach { (group, items) ->
            item {
                Text(group, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
                Spacer(modifier = Modifier.height(16.dp))
            }
            items(items) { setting ->
                Surface(
                    onClick = {},
                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp).height(56.dp),
                    colors = ClickableSurfaceDefaults.colors(
                        containerColor = Color.Transparent,
                        focusedContainerColor = MaterialTheme.colorScheme.surface
                    )
                ) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.CenterStart) {
                        Row(
                            modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("►", modifier = Modifier.padding(end = 12.dp), color = MaterialTheme.colorScheme.primary)
                            Text(setting, color = Color.White)
                        }
                    }
                }
            }
            item { Spacer(modifier = Modifier.height(24.dp)) }
        }
    }
}
