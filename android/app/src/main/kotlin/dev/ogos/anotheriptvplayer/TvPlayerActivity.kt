package dev.ogos.anotheriptvplayer

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import org.json.JSONArray

class TvPlayerActivity : ComponentActivity() {

    companion object {
        const val EXTRA_URL           = "url"
        const val EXTRA_TITLE         = "title"
        const val EXTRA_CONTENT_TYPE  = "contentType"
        const val EXTRA_SUBTITLE_URL  = "subtitleUrl"
        const val EXTRA_QUEUE_JSON    = "queueJson"
        const val EXTRA_CURRENT_INDEX = "currentIndex"
        const val EXTRA_POSITION      = "position"
    }

    private val viewModel: PlayerViewModel by viewModels()
    private var url: String = ""
    private var title: String = ""
    private var contentType: String = "live"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        url         = intent.getStringExtra(EXTRA_URL) ?: ""
        title       = intent.getStringExtra(EXTRA_TITLE) ?: ""
        contentType = intent.getStringExtra(EXTRA_CONTENT_TYPE) ?: "live"
        val subtitleUrl = intent.getStringExtra(EXTRA_SUBTITLE_URL) ?: ""
        val queueJson   = intent.getStringExtra(EXTRA_QUEUE_JSON) ?: "[]"
        val currentIdx  = intent.getIntExtra(EXTRA_CURRENT_INDEX, 0)
        val position    = intent.getLongExtra(EXTRA_POSITION, 0L)

        val queue = parseQueueJson(queueJson)

        if (queue.isNotEmpty()) {
            viewModel.loadQueue(queue, currentIdx, position)
        } else {
            viewModel.loadMedia(url, title, subtitleUrl, position)
        }

        // Check if this item is already in favorites
        val isFav = TvRepository.getFavorites(this).any { it.id == url || it.url == url }
        viewModel.setFavorite(isFav)

        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                TvPlayerScreen(
                    viewModel = viewModel,
                    contentType = contentType,
                    onBack = { finish() },
                    onToggleFavorite = {
                        val currentlyFav = viewModel.state.value.isFavorite
                        val item = TvContentItem(
                            id = url, name = title, url = url,
                            imageUrl = "", contentType = contentType
                        )
                        if (currentlyFav) {
                            TvRepository.removeFavorite(this, url)
                        } else {
                            TvRepository.saveFavorite(this, item)
                        }
                        viewModel.setFavorite(!currentlyFav)
                    }
                )
            }
        }
    }

    override fun onStop() {
        super.onStop()
        val pos = viewModel.getCurrentPositionForHistory()
        val dur = viewModel.player.duration
        if (pos > 5_000) { // only save if watched more than 5 seconds
            val item = TvContentItem(
                id = url, name = title, url = url,
                imageUrl = "", contentType = contentType
            )
            TvRepository.saveWatchHistory(this, item, pos, dur)
        }
    }

    private fun parseQueueJson(json: String): List<PlayerViewModel.QueueItem> {
        return try {
            val arr = JSONArray(json)
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                PlayerViewModel.QueueItem(
                    url         = obj.optString("url", ""),
                    title       = obj.optString("title", ""),
                    subtitleUrl = obj.optString("subtitleUrl", ""),
                )
            }.filter { it.url.isNotBlank() }
        } catch (_: Exception) {
            emptyList()
        }
    }
}
