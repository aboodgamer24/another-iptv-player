package dev.ogos.anotheriptvplayer

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.*
import androidx.lifecycle.viewmodel.compose.viewModel
import android.content.Context

class TvMainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Keep screen on for TV
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        setContent {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val playlistJson = prefs.getString("flutter.current_playlist_json", null)
            val syncToken = prefs.getString("flutter.sync_token", null)

            var hasPlaylist by remember { mutableStateOf(!playlistJson.isNullOrEmpty()) }
            var isGuestMode by remember { mutableStateOf(false) }

            TvAppTheme {
                if (!hasPlaylist && !isGuestMode) {
                    val vm: TvWelcomeViewModel = viewModel()
                    TvWelcomeScreen(
                        onDone = {
                            isGuestMode = vm.isGuestMode
                            hasPlaylist = true
                        }
                    )
                } else {
                    val initialTab = if (isGuestMode) 7 else 0
                    TvAppShell(initialTab = initialTab)
                }
            }
        }
    }
}
