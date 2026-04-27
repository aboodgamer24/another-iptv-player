package dev.ogos.anotheriptvplayer

import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.tv.material3.*

@Composable
fun TvMoviesScreen() {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Movies Screen", style = MaterialTheme.typography.headlineLarge)
    }
}

@Composable
fun TvMovieDetailScreen(item: TvContentItem) {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Movie Detail: ${item.name}", style = MaterialTheme.typography.headlineLarge)
    }
}
