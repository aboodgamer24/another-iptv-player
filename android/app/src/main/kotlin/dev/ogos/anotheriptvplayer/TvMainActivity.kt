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
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import androidx.compose.material3.CircularProgressIndicator

class TvMainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContent {
            TvTheme {
                var isReady     by remember { mutableStateOf(false) }
                var hasPlaylist by remember { mutableStateOf(false) }
                var isGuestMode by remember { mutableStateOf(false) }
                var forcedTab   by remember { mutableStateOf<Int?>(null) }

                LaunchedEffect(Unit) {
                    withContext(Dispatchers.IO) {
                        // Initialize sync service and pull data
                        TvSyncService.init(this@TvMainActivity)
                        if (TvSyncService.isLoggedIn) {
                            TvSyncApplier.pullAndApply(this@TvMainActivity)
                        }
                        
                        hasPlaylist = TvRepository.hasPlaylist(this@TvMainActivity)
                    }
                    isReady = true
                }

                when {
                    !isReady -> {
                        Box(
                            modifier = Modifier.fillMaxSize().background(TvColors.Background),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator(color = TvColors.Primary)
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
                        val initialTab = forcedTab ?: 0
                        TvAppShell(initialTab = initialTab)
                    }
                }
            }
        }
    }
}
