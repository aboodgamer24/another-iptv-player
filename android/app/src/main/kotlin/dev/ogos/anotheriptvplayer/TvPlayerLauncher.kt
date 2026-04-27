package dev.ogos.anotheriptvplayer

import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject

object TvPlayerLauncher {

    fun play(context: Context, item: TvContentItem) {
        val intent = Intent(context, TvPlayerActivity::class.java).apply {
            putExtra("url", item.url)
            putExtra("title", item.name)
            putExtra("contentType", item.contentType)
            putExtra("subtitleUrl", item.subtitleUrl)
            putExtra("queueJson", "[]")
            putExtra("currentIndex", 0)
            putExtra("position", 0L)
        }
        context.startActivity(intent)
    }

    fun playQueue(
        context: Context,
        queue: List<TvContentItem>,
        currentIndex: Int,
        contentType: String,
    ) {
        if (queue.isEmpty()) return
        val current = queue[currentIndex.coerceIn(0, queue.lastIndex)]
        val queueJson = JSONArray(queue.map {
            JSONObject().apply {
                put("url", it.url)
                put("title", it.name)
                put("subtitleUrl", it.subtitleUrl)
            }
        }).toString()
        
        val intent = Intent(context, TvPlayerActivity::class.java).apply {
            putExtra("url", current.url)
            putExtra("title", current.name)
            putExtra("contentType", contentType)
            putExtra("subtitleUrl", current.subtitleUrl)
            putExtra("queueJson", queueJson)
            putExtra("currentIndex", currentIndex)
            putExtra("position", 0L)
        }
        context.startActivity(intent)
    }
}
