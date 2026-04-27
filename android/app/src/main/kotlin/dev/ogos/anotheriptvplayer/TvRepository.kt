package dev.ogos.anotheriptvplayer

import android.content.Context
import org.json.JSONObject
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

object TvRepository {
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_PLAYLIST = "flutter.current_playlist_json"

    private var apiService: XtreamApiService? = null
    private var currentPlaylist: JSONObject? = null

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
        apiService = Retrofit.Builder()
            .baseUrl(if (url.endsWith("/")) url else "$url/")
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(XtreamApiService::class.java)
    }

    fun getApiService(): XtreamApiService? = apiService

    fun getPlaylistCredentials(): Triple<String, String, String> {
        val u = currentPlaylist?.optString("username") ?: ""
        val p = currentPlaylist?.optString("password") ?: ""
        val url = currentPlaylist?.optString("url") ?: ""
        return Triple(u, p, url)
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

    fun getPlaylistType(): String {
        val type = currentPlaylist?.optString("type") ?: ""
        return if (type.contains("xtream")) "xtream" else "m3u"
    }

    // SQLite reading logic for Favorites and History can be added here
    // using context.getDatabasePath("another-iptv-player.sqlite")
}

data class TvNavItem(val icon: androidx.compose.ui.graphics.vector.ImageVector, val label: String)
