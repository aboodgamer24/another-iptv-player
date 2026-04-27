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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val url         = intent.getStringExtra(EXTRA_URL) ?: ""
        val title       = intent.getStringExtra(EXTRA_TITLE) ?: ""
        val contentType = intent.getStringExtra(EXTRA_CONTENT_TYPE) ?: "live"
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

        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                TvPlayerScreen(
                    viewModel = viewModel,
                    contentType = contentType,
                    onBack = { finish() }
                )
            }
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
