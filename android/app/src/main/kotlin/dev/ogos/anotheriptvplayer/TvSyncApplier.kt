package dev.ogos.anotheriptvplayer

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * TvSyncApplier mirrors the logic from Flutter's SyncApplier.
 * It takes the JSON payload from the sync server and applies it to the local SQLite database and preferences.
 */
object TvSyncApplier {
    private const val TAG = "TvSyncApplier"
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val DB_NAME = "another-iptv-player.sqlite"

    /**
     * Pulls data from the sync server and applies it locally.
     */
    suspend fun pullAndApply(context: Context): Boolean {
        try {
            TvSyncService.init(context)
            val data = TvSyncService.pullSync() ?: return false

            Log.d(TAG, "Pull successful. Applying data...")

            // 1. Apply settings first
            applySettings(context, data.optJSONObject("settings"))

            // 2. Apply last playlist ID
            val settings = data.optJSONObject("settings")
            val lastPlaylistId = settings?.optString("last_playlist_id") ?: settings?.optString("lastPlaylistId")
            if (!lastPlaylistId.isNullOrEmpty()) {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putString("flutter.last_playlist_id", lastPlaylistId).apply()
            }

            // 3. Apply playlists
            applyPlaylists(context, data.optJSONArray("playlists"))

            // 4. Apply favorites
            applyFavorites(context, data.optJSONArray("favorites"))

            // 5. Apply watch later
            applyWatchLater(context, data.optJSONArray("watch_later"))

            // 6. Apply continue watching
            applyContinueWatching(context, data.optJSONArray("continue_watching"))

            Log.d(TAG, "Sync applied successfully")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error applying sync", e)
            return false
        }
    }

    private fun applySettings(context: Context, settings: JSONObject?) {
        if (settings == null) return
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()

        // Upscale preset handling (mirror Flutter logic)
        val rawPreset = settings.optString("upscale_preset", settings.optString("upscalePreset", "standard"))
        editor.putString("flutter.upscale_preset", rawPreset)
        
        // Apply other settings (e.g., tmdb key)
        val tmdbKey = settings.optString("tmdb_api_key", settings.optString("tmdbApiKey", ""))
        if (tmdbKey.isNotEmpty()) {
            editor.putString("flutter.tmdb_api_key", tmdbKey)
        }

        editor.apply()
    }

    private fun applyPlaylists(context: Context, playlists: JSONArray?) {
        if (playlists == null || playlists.length() == 0) return
        
        val db = openDatabase(context) ?: return
        db.use { database ->
            for (i in 0 until playlists.length()) {
                val p = playlists.getJSONObject(i)
                val id = p.optString("id")
                if (id.isEmpty()) continue

                val values = ContentValues().apply {
                    put("id", id)
                    put("name", p.optString("name"))
                    put("type", p.optString("type"))
                    put("url", p.optString("url"))
                    put("username", p.optString("username"))
                    put("password", p.optString("password"))
                    put("created_at", parseDateToUnix(p.optString("createdAt", p.optString("created_at"))))
                }

                // Check if exists
                val cursor = database.query("playlists", arrayOf("id"), "id = ?", arrayOf(id), null, null, null)
                val exists = cursor.use { it.moveToFirst() }
                
                if (!exists) {
                    database.insert("playlists", null, values)
                    Log.d(TAG, "Restored playlist: ${p.optString("name")}")
                }
            }
        }
    }

    private fun applyFavorites(context: Context, favorites: JSONArray?) {
        if (favorites == null || favorites.length() == 0) return
        
        val db = openDatabase(context) ?: return
        db.use { database ->
            for (i in 0 until favorites.length()) {
                val f = favorites.getJSONObject(i)
                val id = f.optString("id")
                if (id.isEmpty()) continue

                val values = ContentValues().apply {
                    put("id", id)
                    put("playlist_id", f.optString("playlistId", f.optString("playlist_id")))
                    put("content_type", parseContentType(f.optString("contentType")))
                    put("stream_id", f.optString("streamId", f.optString("stream_id")))
                    put("episode_id", f.optString("episodeId", f.optString("episode_id")))
                    put("name", f.optString("name"))
                    put("image_path", f.optString("imagePath", f.optString("image_path")))
                    put("sort_order", f.optInt("sortOrder", f.optInt("sort_order", 0)))
                    put("created_at", parseDateToUnix(f.optString("createdAt", f.optString("created_at"))))
                    put("updated_at", parseDateToUnix(f.optString("updatedAt", f.optString("updated_at"))))
                }

                database.insertWithOnConflict("favorites", null, values, SQLiteDatabase.CONFLICT_REPLACE)
            }
        }
    }

    private fun applyWatchLater(context: Context, watchLater: JSONArray?) {
        if (watchLater == null || watchLater.length() == 0) return
        
        val db = openDatabase(context) ?: return
        db.use { database ->
            for (i in 0 until watchLater.length()) {
                val w = watchLater.getJSONObject(i)
                val id = w.optString("id")
                if (id.isEmpty()) continue

                val values = ContentValues().apply {
                    put("id", id)
                    put("playlist_id", w.optString("playlistId", w.optString("playlist_id")))
                    put("content_type", parseContentType(w.optString("contentType")))
                    put("stream_id", w.optString("streamId", w.optString("stream_id")))
                    put("title", w.optString("title"))
                    put("image_path", w.optString("imagePath", w.optString("image_path")))
                    put("added_at", parseDateToUnix(w.optString("addedAt", w.optString("added_at"))))
                }

                database.insertWithOnConflict("watch_laters", null, values, SQLiteDatabase.CONFLICT_REPLACE)
            }
        }
    }

    private fun applyContinueWatching(context: Context, items: JSONArray?) {
        if (items == null || items.length() == 0) return
        
        val db = openDatabase(context) ?: return
        db.use { database ->
            for (i in 0 until items.length()) {
                val item = items.getJSONObject(i)
                val playlistId = item.optString("playlistId", item.optString("playlist_id"))
                val streamId = item.optString("streamId", item.optString("stream_id"))
                if (playlistId.isEmpty() || streamId.isEmpty()) continue

                val values = ContentValues().apply {
                    put("playlist_id", playlistId)
                    put("content_type", parseContentType(item.optString("contentType")))
                    put("stream_id", streamId)
                    put("series_id", item.optString("seriesId", item.optString("series_id")))
                    put("watch_duration", item.optInt("watchDuration", item.optInt("watch_duration", 0)))
                    put("total_duration", item.optInt("totalDuration", item.optInt("total_duration", 0)))
                    put("last_watched", parseDateToUnix(item.optString("lastWatched", item.optString("last_watched"))))
                    put("image_path", item.optString("imagePath", item.optString("image_path")))
                    put("title", item.optString("title"))
                }

                database.insertWithOnConflict("watch_histories", null, values, SQLiteDatabase.CONFLICT_REPLACE)
            }
        }
    }

    private fun openDatabase(context: Context): SQLiteDatabase? {
        val dbFile = context.getDatabasePath(DB_NAME)
        if (!dbFile.exists()) {
            Log.e(TAG, "Database file not found: ${dbFile.absolutePath}")
            return null
        }
        return try {
            SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open database", e)
            null
        }
    }

    private fun parseContentType(value: String?): Int {
        if (value == null) return 0
        return when {
            value.contains("liveStream", ignoreCase = true) -> 0
            value.contains("vod", ignoreCase = true) -> 1
            value.contains("series", ignoreCase = true) -> 2
            value == "0" -> 0
            value == "1" -> 1
            value == "2" -> 2
            else -> 0
        }
    }

    private fun parseDateToUnix(dateStr: String?): Long {
        if (dateStr.isNullOrEmpty()) return System.currentTimeMillis()
        return try {
            // ISO 8601 format
            val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
            format.parse(dateStr)?.time ?: System.currentTimeMillis()
        } catch (e: Exception) {
            // Try numeric
            dateStr.toLongOrNull() ?: System.currentTimeMillis()
        }
    }
}
