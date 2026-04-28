package dev.ogos.anotheriptvplayer

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.*

object TvRepository {
    private const val TAG = "TvRepository"
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val DB_NAME = "another-iptv-player.sqlite"
    private const val KEY_PLAYLIST_LEGACY = "flutter.flutter.current_playlist_json"
    private const val KEY_LAST_PLAYLIST_ID = "flutter.last_playlist_id"

    private var _apiService: XtreamApiService? = null
    private var currentPlaylist: JSONObject? = null
    private var _credentials: Triple<String, String, String>? = null

    fun loadPlaylist(context: Context): JSONObject? {
        // 1. Try to load by last_playlist_id from SQLite
        val lastId = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_LAST_PLAYLIST_ID, null)
        
        val fromDb = loadPlaylistFromSqlite(context, lastId)
        if (fromDb != null) return fromDb

        // 2. Fallback: legacy SharedPreferences key
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json  = prefs.getString(KEY_PLAYLIST_LEGACY, null) ?: return null

        return try {
            val obj = JSONObject(json)
            val url = obj.optString("url")
            if (url.isBlank()) return null
            currentPlaylist = obj
            _credentials   = null
            setupApi()
            Log.d(TAG, "loadPlaylist ← SharedPrefs url=$url")
            currentPlaylist
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing legacy playlist", e)
            null
        }
    }

    private fun loadPlaylistFromSqlite(context: Context, targetId: String?): JSONObject? {
        val dbFile = context.getDatabasePath(DB_NAME)
        if (!dbFile.exists()) return null

        return try {
            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
            db.use { database ->
                val cursor = if (targetId != null) {
                    database.query("playlists", null, "id = ?", arrayOf(targetId), null, null, null)
                } else {
                    // Get most recently added xtream playlist
                    database.query("playlists", null, "type LIKE '%xtream%'", null, null, null, "created_at DESC", "1")
                }

                cursor.use {
                    if (it.moveToFirst()) {
                        buildPlaylistJson(it)
                    } else if (targetId != null) {
                        // If targeted ID not found, try getting any
                        database.query("playlists", null, null, null, null, null, "created_at DESC", "1").use { fallback ->
                            if (fallback.moveToFirst()) buildPlaylistJson(fallback) else null
                        }
                    } else null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "loadPlaylistFromSqlite error", e)
            null
        }
    }

    private fun buildPlaylistJson(cursor: Cursor): JSONObject? {
        fun col(name: String) = runCatching {
            cursor.getString(cursor.getColumnIndexOrThrow(name)) ?: ""
        }.getOrDefault("")

        val url      = col("url")
        val username = col("username")
        val password = col("password")
        val name     = col("name")
        val type     = col("type")
        val id       = col("id")

        if (url.isBlank()) return null

        val obj = JSONObject().apply {
            put("id",       id)
            put("url",      url)
            put("username", username)
            put("password", password)
            put("name",     name)
            put("type",     if (type.contains("xtream")) "xtream" else "m3u")
        }
        currentPlaylist = obj
        _credentials   = null
        setupApi()
        Log.d(TAG, "loadPlaylist ← SQLite id=$id url=$url")
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
        val formattedBaseUrl = baseUrl.trimEnd('/')
        return when (type) {
            "live" -> "$formattedBaseUrl/live/$u/$p/$streamId.$extension"
            "movie" -> "$formattedBaseUrl/movie/$u/$p/$streamId.$extension"
            "series" -> "$formattedBaseUrl/series/$u/$p/$streamId.$extension"
            else -> "$formattedBaseUrl/live/$u/$p/$streamId.$extension"
        }
    }

    fun buildEpisodeUrl(episodeId: String, ext: String): String {
        val (u, p, baseUrl) = getPlaylistCredentials()
        val formattedBaseUrl = baseUrl.trimEnd('/')
        return "$formattedBaseUrl/series/$u/$p/$episodeId.$ext"
    }

    fun hasPlaylist(context: Context): Boolean {
        val dbFile = context.getDatabasePath(DB_NAME)
        if (dbFile.exists()) {
            try {
                val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
                db.use {
                    it.rawQuery("SELECT COUNT(*) FROM playlists", null).use { c ->
                        return c.moveToFirst() && c.getInt(0) > 0
                    }
                }
            } catch (_: Exception) {}
        }
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return !prefs.getString(KEY_PLAYLIST_LEGACY, null).isNullOrBlank()
    }

    fun savePlaylist(context: Context, url: String, username: String, password: String) {
        val id = UUID.randomUUID().toString()
        val json = JSONObject().apply {
            put("id", id)
            put("url", url)
            put("username", username)
            put("password", password)
            put("type", "xtream")
            put("name", url)
        }

        // Save to SharedPrefs for legacy/temporary access
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putString(KEY_PLAYLIST_LEGACY, json.toString())
            .putString(KEY_LAST_PLAYLIST_ID, id)
            .apply()

        // Write to SQLite
        val dbFile = context.getDatabasePath(DB_NAME)
        if (dbFile.exists()) {
            try {
                val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
                db.use {
                    val values = ContentValues().apply {
                        put("id", id)
                        put("name", url)
                        put("type", "PlaylistType.xtream")
                        put("url", url)
                        put("username", username)
                        put("password", password)
                        put("created_at", System.currentTimeMillis())
                    }
                    it.insertWithOnConflict("playlists", null, values, SQLiteDatabase.CONFLICT_REPLACE)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write playlist to SQLite", e)
            }
        }

        currentPlaylist = json
        _credentials = null
        setupApi()

        // Push to server if logged in
        kotlinx.coroutines.GlobalScope.launch(kotlinx.coroutines.Dispatchers.IO) {
            TvSyncService.init(context)
            if (TvSyncService.isLoggedIn) {
                val playlists = JSONArray().put(json)
                TvSyncService.pushField("playlists", playlists)
            }
        }
    }

    fun getFavorites(context: Context): List<TvContentItem> {
        return readItemsFromSqlite(context, "favorites")
    }

    fun saveFavorite(context: Context, item: TvContentItem) {
        val playlistId = currentPlaylist?.optString("id") ?: ""
        if (playlistId.isEmpty()) return

        val dbFile = context.getDatabasePath(DB_NAME)
        if (!dbFile.exists()) return

        try {
            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
            db.use {
                val values = ContentValues().apply {
                    put("id", UUID.randomUUID().toString())
                    put("playlist_id", playlistId)
                    put("content_type", parseContentType(item.contentType))
                    put("stream_id", item.id)
                    put("name", item.name)
                    put("image_path", item.imageUrl)
                    put("created_at", System.currentTimeMillis())
                    put("updated_at", System.currentTimeMillis())
                }
                it.insertWithOnConflict("favorites", null, values, SQLiteDatabase.CONFLICT_REPLACE)
            }
        } catch (_: Exception) {}
    }

    fun removeFavorite(context: Context, itemId: String) {
        val dbFile = context.getDatabasePath(DB_NAME)
        if (!dbFile.exists()) return
        try {
            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
            db.use { it.delete("favorites", "stream_id = ?", arrayOf(itemId)) }
        } catch (_: Exception) {}
    }

    fun getWatchHistory(context: Context): List<TvContentItem> {
        return readItemsFromSqlite(context, "watch_histories")
    }

    fun saveWatchHistory(context: Context, item: TvContentItem, position: Long, total: Long) {
        val playlistId = currentPlaylist?.optString("id") ?: ""
        if (playlistId.isEmpty()) return

        val dbFile = context.getDatabasePath(DB_NAME)
        if (!dbFile.exists()) return

        try {
            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
            db.use {
                val values = ContentValues().apply {
                    put("playlist_id", playlistId)
                    put("content_type", parseContentType(item.contentType))
                    put("stream_id", item.id)
                    put("watch_duration", position.toInt())
                    put("total_duration", total.toInt())
                    put("last_watched", System.currentTimeMillis())
                    put("image_path", item.imageUrl)
                    put("title", item.name)
                }
                it.insertWithOnConflict("watch_histories", null, values, SQLiteDatabase.CONFLICT_REPLACE)
            }
        } catch (_: Exception) {}
    }

    private fun readItemsFromSqlite(context: Context, table: String): List<TvContentItem> {
        val dbFile = context.getDatabasePath(DB_NAME)
        if (!dbFile.exists()) return emptyList()

        val items = mutableListOf<TvContentItem>()
        try {
            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
            db.use { database ->
                val orderBy = if (table == "favorites") "created_at DESC" else "last_watched DESC"
                val cursor = database.query(table, null, null, null, null, null, orderBy, "200")
                cursor.use {
                    while (it.moveToNext()) {
                        fun col(name: String): String = runCatching {
                            it.getString(it.getColumnIndexOrThrow(name)) ?: ""
                        }.getOrDefault("")

                        items.add(
                            TvContentItem(
                                id          = col("stream_id"),
                                name        = if (table == "favorites") col("name") else col("title"),
                                url         = "", // Not stored in DB, will be built on demand
                                imageUrl    = col("image_path"),
                                contentType = if (col("content_type") == "0") "live" else if (col("content_type") == "1") "movie" else "series",
                                categoryId  = col("category_id")
                            )
                        )
                    }
                }
            }
        } catch (_: Exception) {}
        return items
    }

    private fun parseContentType(type: String): Int = when (type) {
        "live" -> 0
        "movie" -> 1
        "series" -> 2
        else -> 0
    }
}

data class TvNavItem(val icon: androidx.compose.ui.graphics.vector.ImageVector, val label: String)

data class TvContentItem(
    val id: String,
    val name: String,
    val url: String,
    val imageUrl: String,
    val contentType: String,
    val categoryId: String = "",
    val plot: String = "",
    val rating: String = "",
    val year: String = "",
    val duration: String = "",
    val subtitleUrl: String = ""
)
