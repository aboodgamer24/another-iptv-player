package dev.ogos.anotheriptvplayer

import android.content.Context
import org.json.JSONObject
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

object TvRepository {
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_PLAYLIST = "flutter.current_playlist_json"

    private var _apiService: XtreamApiService? = null
    private var currentPlaylist: JSONObject? = null
    private var _credentials: Triple<String, String, String>? = null

    fun loadPlaylist(context: Context): JSONObject? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_PLAYLIST, null)
        if (json != null) {
            currentPlaylist = JSONObject(json)
            setupApi()
        }
        return currentPlaylist
    }

    private fun setupApi() {
        val url = currentPlaylist?.optString("url") ?: return
        _apiService = Retrofit.Builder()
            .baseUrl(if (url.endsWith("/")) url else "$url/")
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(XtreamApiService::class.java)
    }

    fun getApiService(): XtreamApiService? = _apiService

    fun getPlaylistCredentials(): Triple<String, String, String> {
        _credentials?.let { return it }

        val u = currentPlaylist?.optString("username") ?: ""
        val p = currentPlaylist?.optString("password") ?: ""
        val url = currentPlaylist?.optString("url") ?: ""
        
        val creds = Triple(u, p, url)
        if (u.isNotBlank()) {
            _credentials = creds
        }
        return creds
    }

    fun buildStreamUrl(streamId: String, type: String, extension: String = "ts"): String {
        val (u, p, baseUrl) = getPlaylistCredentials()
        val formattedBaseUrl = if (baseUrl.endsWith("/")) baseUrl.removeSuffix("/") else baseUrl
        return when (type) {
            "live" -> "$formattedBaseUrl/live/$u/$p/$streamId.$extension"
            "movie" -> "$formattedBaseUrl/movie/$u/$p/$streamId.$extension"
            "series" -> "$formattedBaseUrl/series/$u/$p/$streamId.$extension"
            else -> "$formattedBaseUrl/live/$u/$p/$streamId.$extension"
        }
    }

    fun buildEpisodeUrl(episodeId: String, ext: String): String {
        val (username, password, serverUrl) = getPlaylistCredentials()
        val formattedBaseUrl = if (serverUrl.endsWith("/")) serverUrl.removeSuffix("/") else serverUrl
        return "$formattedBaseUrl/series/$username/$password/$episodeId.$ext"
    }

    fun clearPlaylist(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(KEY_PLAYLIST).apply()
        _apiService = null
        _credentials = null
        currentPlaylist = null
    }

    fun hasPlaylist(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_PLAYLIST, null)
        return !json.isNullOrBlank()
    }

    fun getPlaylistType(): String {
        val type = currentPlaylist?.optString("type") ?: ""
        return if (type.contains("xtream")) "xtream" else "m3u"
    }

    fun getFavorites(context: Context): List<TvContentItem> {
        return readItemsFromSqlite(context, "favorites")
    }

    fun getWatchHistory(context: Context): List<TvContentItem> {
        return readItemsFromSqlite(context, "watch_history")
    }

    private fun readItemsFromSqlite(context: Context, table: String): List<TvContentItem> {
        val dbFile = context.getDatabasePath("another-iptv-player.sqlite")
        if (!dbFile.exists()) return emptyList()

        val items = mutableListOf<TvContentItem>()
        val db = android.database.sqlite.SQLiteDatabase.openDatabase(
            dbFile.absolutePath,
            null,
            android.database.sqlite.SQLiteDatabase.OPEN_READONLY
        )

        try {
            val cursor = db.rawQuery("SELECT * FROM $table ORDER BY rowid DESC LIMIT 200", null)
            cursor.use {
                while (it.moveToNext()) {
                    fun col(name: String): String =
                        runCatching { it.getString(it.getColumnIndexOrThrow(name)) ?: "" }.getOrDefault("")

                    items.add(
                        TvContentItem(
                            id          = col("stream_id").ifBlank { col("id") },
                            name        = col("name"),
                            url         = col("stream_url").ifBlank { col("url") },
                            imageUrl    = col("stream_icon").ifBlank { col("image_url") },
                            contentType = col("content_type").ifBlank { col("type") },
                            categoryId  = col("category_id"),
                            plot        = col("plot"),
                            rating      = col("rating"),
                            year        = col("year"),
                            duration    = col("duration"),
                            subtitleUrl = col("subtitle_url")
                        )
                    )
                }
            }
        } catch (_: Exception) {
        } finally {
            db.close()
        }
        return items
    }
}

data class TvNavItem(val icon: androidx.compose.ui.graphics.vector.ImageVector, val label: String)
