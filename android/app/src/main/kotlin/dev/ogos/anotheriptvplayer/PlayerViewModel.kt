package dev.ogos.anotheriptvplayer

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaItem.SubtitleConfiguration
import androidx.media3.common.MimeTypes
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

data class PlayerUiState(
    val isPlaying: Boolean = false,
    val isLoading: Boolean = true,
    val hasError: Boolean = false,
    val errorMessage: String = "",
    val currentPosition: Long = 0L,
    val duration: Long = 0L,
    val title: String = "",
    val currentIndex: Int = 0,
    val subtitlesEnabled: Boolean = true,
    val videoWidth: Int = 0,
    val videoHeight: Int = 0,
    val codec: String = "",
    val frameRate: Float = 0f,
)

class PlayerViewModel(app: Application) : AndroidViewModel(app) {

    val player: ExoPlayer = ExoPlayer.Builder(app).build().apply {
        playWhenReady = true
    }

    private val _state = MutableStateFlow(PlayerUiState())
    val state: StateFlow<PlayerUiState> = _state

    private var queueItems: List<QueueItem> = emptyList()

    data class QueueItem(val url: String, val title: String, val subtitleUrl: String = "")

    init {
        player.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                _state.value = _state.value.copy(isPlaying = isPlaying)
            }
            override fun onPlaybackStateChanged(state: Int) {
                _state.value = _state.value.copy(
                    isLoading = state == Player.STATE_BUFFERING,
                    hasError = state == Player.STATE_IDLE && _state.value.hasError
                )
            }
            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                _state.value = _state.value.copy(hasError = true, errorMessage = error.message ?: "Playback error")
            }
            override fun onVideoSizeChanged(videoSize: androidx.media3.common.VideoSize) {
                _state.value = _state.value.copy(
                    videoWidth = videoSize.width,
                    videoHeight = videoSize.height
                )
            }
        })
    }

    fun loadMedia(url: String, title: String, subtitleUrl: String, startPosition: Long) {
        val mediaItem = buildMediaItem(url, subtitleUrl)
        player.setMediaItem(mediaItem)
        player.prepare()
        if (startPosition > 0) player.seekTo(startPosition)
        _state.value = _state.value.copy(title = title, hasError = false, isLoading = true)
    }

    fun loadQueue(items: List<QueueItem>, startIndex: Int, startPosition: Long) {
        queueItems = items
        if (items.isEmpty()) return
        val idx = startIndex.coerceIn(0, items.lastIndex)
        val item = items[idx]
        _state.value = _state.value.copy(currentIndex = idx, title = item.title)
        loadMedia(item.url, item.title, item.subtitleUrl, startPosition)
    }

    fun jumpToIndex(index: Int) {
        if (index < 0 || index >= queueItems.size) return
        val item = queueItems[index]
        _state.value = _state.value.copy(currentIndex = index, title = item.title)
        loadMedia(item.url, item.title, item.subtitleUrl, 0L)
    }

    fun getQueue(): List<QueueItem> = queueItems

    fun togglePlayPause() {
        if (player.isPlaying) player.pause() else player.play()
    }

    fun seekForward() = player.seekTo(player.currentPosition + 10_000)
    fun seekBack()    = player.seekTo((player.currentPosition - 10_000).coerceAtLeast(0))

    fun toggleSubtitles(enabled: Boolean) {
        _state.value = _state.value.copy(subtitlesEnabled = enabled)
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, !enabled)
            .build()
    }

    private fun buildMediaItem(url: String, subtitleUrl: String): MediaItem {
        val builder = MediaItem.Builder().setUri(url)
        if (subtitleUrl.isNotBlank()) {
            val mimeType = if (subtitleUrl.endsWith(".vtt")) MimeTypes.TEXT_VTT else MimeTypes.APPLICATION_SUBRIP
            val sub = SubtitleConfiguration.Builder(Uri.parse(subtitleUrl))
                .setMimeType(mimeType)
                .setLanguage("und")
                .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                .build()
            builder.setSubtitleConfigurations(listOf(sub))
        }
        return builder.build()
    }

    override fun onCleared() {
        super.onCleared()
        player.release()
    }
}
