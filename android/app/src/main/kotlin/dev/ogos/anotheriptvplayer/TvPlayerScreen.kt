package dev.ogos.anotheriptvplayer

import android.view.ViewGroup
import androidx.activity.compose.BackHandler
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.*
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.media3.ui.PlayerView
import androidx.tv.material3.*
import kotlinx.coroutines.delay

@Composable
fun TvPlayerScreen(
    viewModel: PlayerViewModel,
    contentType: String,
    onBack: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var controlsVisible by remember { mutableStateOf(true) }
    var sidePanelVisible by remember { mutableStateOf(false) }
    val focusRequester = remember { FocusRequester() }

    // Auto-hide controls after 4 seconds of inactivity
    LaunchedEffect(controlsVisible) {
        if (controlsVisible && !sidePanelVisible) {
            delay(4_000)
            controlsVisible = false
        }
    }

    BackHandler {
        when {
            sidePanelVisible -> sidePanelVisible = false
            controlsVisible  -> onBack()
            else             -> controlsVisible = true
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black)
            .focusRequester(focusRequester)
            .focusable()
            .onKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                controlsVisible = true
                when (event.key) {
                    Key.DirectionCenter, Key.Enter -> { viewModel.togglePlayPause(); true }
                    Key.DirectionRight -> { viewModel.seekForward(); true }
                    Key.DirectionLeft  -> { viewModel.seekBack(); true }
                    Key.Menu           -> { sidePanelVisible = !sidePanelVisible; true }
                    else -> false
                }
            }
    ) {
        // 1. ExoPlayer surface
        AndroidView(
            factory = { ctx ->
                PlayerView(ctx).apply {
                    layoutParams = ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )
                    useController = false   // we draw our own controls
                    player = viewModel.player
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // 2. Loading indicator
        if (state.isLoading) {
            CircularProgressIndicator(
                color = Color(0xFF4F98A3),
                modifier = Modifier.align(Alignment.Center)
            )
        }

        // 3. Error state
        if (state.hasError) {
            Column(
                Modifier.align(Alignment.Center),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(Icons.Default.ErrorOutline, contentDescription = null, tint = Color(0xFFDD6974), modifier = Modifier.size(48.dp))
                Text("Playback error", color = Color.White, fontSize = 18.sp)
                Text(state.errorMessage, color = Color.White.copy(alpha = 0.6f), fontSize = 13.sp)
            }
        }

        // 4. Subtitle overlay (top of video, below controls)
        // Media3 renders subtitles natively via PlayerView — but we expose a toggle
        // that drives trackSelectionParameters in PlayerViewModel.toggleSubtitles().

        // 5. Controls overlay
        AnimatedVisibility(
            visible = controlsVisible,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.fillMaxSize()
        ) {
            TvPlayerControls(
                state = state,
                onPlayPause = viewModel::togglePlayPause,
                onSeekForward = viewModel::seekForward,
                onSeekBack = viewModel::seekBack,
                onToggleSubtitles = { viewModel.toggleSubtitles(!state.subtitlesEnabled) },
                onToggleSidePanel = { sidePanelVisible = !sidePanelVisible },
                onBack = onBack,
            )
        }

        // 6. Side panel (right edge)
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.CenterEnd) {
            TvSidePanel(
                visible = sidePanelVisible,
                state = state,
                queue = viewModel.getQueue(),
                contentType = contentType,
                onIndexSelected = { idx ->
                    viewModel.jumpToIndex(idx)
                    sidePanelVisible = false
                    controlsVisible = true
                },
                onDismiss = { sidePanelVisible = false },
            )
        }
    }

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }
}

@Composable
private fun TvPlayerControls(
    state: PlayerUiState,
    onPlayPause: () -> Unit,
    onSeekForward: () -> Unit,
    onSeekBack: () -> Unit,
    onToggleSubtitles: () -> Unit,
    onToggleSidePanel: () -> Unit,
    onBack: () -> Unit,
) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.45f))
    ) {
        // Title top-left
        Text(
            state.title,
            color = Color.White,
            fontSize = 16.sp,
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(24.dp)
        )

        // Center controls
        Row(
            Modifier.align(Alignment.Center),
            horizontalArrangement = Arrangement.spacedBy(32.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            ControlButton(icon = Icons.Default.Replay10, contentDesc = "Seek back", onClick = onSeekBack)
            ControlButton(
                icon = if (state.isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                contentDesc = "Play/Pause",
                size = 64.dp,
                onClick = onPlayPause
            )
            ControlButton(icon = Icons.Default.Forward10, contentDesc = "Seek forward", onClick = onSeekForward)
        }

        // Bottom-right button row
        Row(
            Modifier
                .align(Alignment.BottomEnd)
                .padding(24.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            ControlButton(
                icon = if (state.subtitlesEnabled) Icons.Default.Subtitles else Icons.Default.SubtitlesOff,
                contentDesc = "Subtitles",
                onClick = onToggleSubtitles
            )
            ControlButton(icon = Icons.Default.Menu, contentDesc = "Side panel", onClick = onToggleSidePanel)
        }

        // Back button top-left below title
        IconButton(
            onClick = onBack,
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(start = 24.dp, top = 56.dp)
        ) {
            Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White)
        }
    }
}

@Composable
private fun ControlButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    contentDesc: String,
    size: androidx.compose.ui.unit.Dp = 48.dp,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        colors = ClickableSurfaceDefaults.colors(
            containerColor = Color.White.copy(alpha = 0.15f),
            focusedContainerColor = Color.White.copy(alpha = 0.3f)
        ),
        shape = ClickableSurfaceDefaults.shape(shape = MaterialTheme.shapes.medium),
        modifier = Modifier.size(size),
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.fillMaxSize()) {
            Icon(
                icon,
                contentDescription = contentDesc,
                tint = Color.White,
                modifier = Modifier.size(size * 0.55f)
            )
        }
    }
}
