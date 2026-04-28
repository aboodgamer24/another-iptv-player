package dev.ogos.anotheriptvplayer

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import androidx.compose.material3.CircularProgressIndicator
import android.content.Context

class TvMainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContent {
            TvAppTheme {
                // Start with a loading state — read SharedPreferences off the UI thread
                var isReady     by remember { mutableStateOf(false) }
                var hasPlaylist by remember { mutableStateOf(false) }
                var isGuestMode by remember { mutableStateOf(false) }
                var forcedTab   by remember { mutableStateOf<Int?>(null) }

                LaunchedEffect(Unit) {
                    val (playlist, _) = withContext(Dispatchers.IO) {
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        val playlistJson = prefs.getString("flutter.current_playlist_json", null)
                        Pair(!playlistJson.isNullOrEmpty(), playlistJson)
                    }
                    hasPlaylist = playlist
                    isReady = true
                }

                when {
                    !isReady -> {
                        // Splash / loading — dark background with no visible content
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(Color(0xFF0D0D0F)),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator(color = Color(0xFF00C8B4))
                        }
                    }

                    !hasPlaylist && !isGuestMode -> {
                        val vm: TvWelcomeViewModel = viewModel()
                        TvWelcomeScreen(
                            onDone = {
                                isGuestMode = vm.isGuestMode
                                forcedTab = vm.pendingNavigationTab
                                hasPlaylist = true
                            }
                        )
                    }

                    else -> {
                        val initialTab = forcedTab ?: (if (isGuestMode) 7 else 0)
                        TvAppShell(initialTab = initialTab)
                    }
                }
            }
        }
    }
}
