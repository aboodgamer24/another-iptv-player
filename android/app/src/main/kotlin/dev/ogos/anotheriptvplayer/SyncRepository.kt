package dev.ogos.anotheriptvplayer

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.MediaType.Companion.toMediaType
import org.json.JSONArray

object SyncRepository {

    private val client = OkHttpClient()

    suspend fun pullFavoritesFromServer(context: Context): List<TvContentItem> {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = prefs.getString("flutter.sync_token", null) ?: return emptyList()
        val serverUrl = prefs.getString("flutter.sync_server_url", null) ?: return emptyList()

        return withContext(Dispatchers.IO) {
            try {
                val request = Request.Builder()
                    .url("$serverUrl/api/favorites")
                    .addHeader("Authorization", "Bearer $token")
                    .get()
                    .build()

                val response = client.newCall(request).execute()
                if (!response.isSuccessful) return@withContext emptyList()

                val body = response.body?.string() ?: return@withContext emptyList()
                val arr = JSONArray(body)
                (0 until arr.length()).map { i ->
                    val obj = arr.getJSONObject(i)
                    TvContentItem(
                        id          = obj.optString("stream_id").ifBlank { obj.optString("id") },
                        name        = obj.optString("name"),
                        url         = obj.optString("stream_url").ifBlank { obj.optString("url") },
                        imageUrl    = obj.optString("stream_icon").ifBlank { obj.optString("image_url") },
                        contentType = obj.optString("content_type").ifBlank { obj.optString("type") },
                        categoryId  = obj.optString("category_id")
                    )
                }
            } catch (_: Exception) {
                emptyList()
            }
        }
    }

    suspend fun pushFavoriteToServer(context: Context, item: TvContentItem, remove: Boolean = false) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = prefs.getString("flutter.sync_token", null) ?: return
        val serverUrl = prefs.getString("flutter.sync_server_url", null) ?: return

        withContext(Dispatchers.IO) {
            try {
                val json = org.json.JSONObject().apply {
                    put("stream_id",    item.id)
                    put("name",         item.name)
                    put("stream_url",   item.url)
                    put("stream_icon",  item.imageUrl)
                    put("content_type", item.contentType)
                }
                val body = json.toString()
                    .toByteArray()
                    .let { okhttp3.RequestBody.create("application/json".toMediaType(), it) }

                val method = if (remove) "DELETE" else "POST"
                val request = Request.Builder()
                    .url("$serverUrl/api/favorites")
                    .addHeader("Authorization", "Bearer $token")
                    .method(method, if (remove) null else body)
                    .build()

                client.newCall(request).execute().close()
            } catch (_: Exception) {}
        }
    }
}
