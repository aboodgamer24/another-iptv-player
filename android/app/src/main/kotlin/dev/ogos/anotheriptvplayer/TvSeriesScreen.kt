package dev.ogos.anotheriptvplayer

import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.tv.material3.*

@Composable
fun TvSeriesScreen() {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Series Screen", style = MaterialTheme.typography.headlineLarge)
    }
}

@Composable
fun TvSeriesDetailScreen(item: TvContentItem) {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Series Detail: ${item.name}", style = MaterialTheme.typography.headlineLarge)
    }
}
