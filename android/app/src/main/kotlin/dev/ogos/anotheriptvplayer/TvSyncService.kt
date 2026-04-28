package dev.ogos.anotheriptvplayer

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

/**
 * TvSyncService mirrors the logic from Flutter's SyncService.
 * It handles authentication and communication with the sync server.
 */
object TvSyncService {
    private const val TAG = "TvSyncService"
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_TOKEN = "flutter.sync_token"
    private const val KEY_SERVER_URL = "flutter.sync_server_url"
    private const val KEY_USER = "flutter.sync_user"

    private val client = OkHttpClient()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    private var token: String? = null
    private var serverUrl: String? = null

    /**
     * Initializes the service by reading stored credentials from SharedPreferences.
     */
    fun init(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        serverUrl = prefs.getString(KEY_SERVER_URL, null)
        token = prefs.getString(KEY_TOKEN, null)
        Log.d(TAG, "Initialized: serverUrl=$serverUrl, hasToken=${!token.isNullOrEmpty()}")
    }

    val isLoggedIn: Boolean get() = !token.isNullOrEmpty()

    private fun getHeaders(token: String?): Map<String, String> {
        val headers = mutableMapOf("Content-Type" to "application/json")
        token?.let { headers["Authorization"] = "Bearer $it" }
        return headers
    }

    suspend fun login(context: Context, url: String, email: String, password: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val formattedUrl = url.trimEnd('/')
            val json = JSONObject().apply {
                put("email", email)
                put("password", password)
            }
            
            val request = Request.Builder()
                .url("$formattedUrl/auth/login")
                .post(json.toString().toRequestBody(jsonMediaType))
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val data = JSONObject(response.body?.string() ?: "{}")
                saveSession(context, formattedUrl, data.getString("token"), data.getJSONObject("user"))
                Result.success(Unit)
            } else {
                Result.failure(Exception("Login failed: ${response.code}"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Login error", e)
            Result.failure(e)
        }
    }

    suspend fun register(context: Context, url: String, email: String, password: String, displayName: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val formattedUrl = url.trimEnd('/')
            val json = JSONObject().apply {
                put("email", email)
                put("password", password)
                put("displayName", displayName)
            }

            val request = Request.Builder()
                .url("$formattedUrl/auth/register")
                .post(json.toString().toRequestBody(jsonMediaType))
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val data = JSONObject(response.body?.string() ?: "{}")
                saveSession(context, formattedUrl, data.getString("token"), data.getJSONObject("user"))
                Result.success(Unit)
            } else {
                Result.failure(Exception("Registration failed: ${response.code}"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Registration error", e)
            Result.failure(e)
        }
    }

    private fun saveSession(context: Context, url: String, newToken: String, user: JSONObject) {
        serverUrl = url
        token = newToken
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString(KEY_SERVER_URL, url)
            putString(KEY_TOKEN, newToken)
            putString(KEY_USER, user.toString())
            apply()
        }
        Log.d(TAG, "Session saved")
    }

    suspend fun logout(context: Context) {
        token = null
        serverUrl = null
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString(KEY_TOKEN, "")
            putString(KEY_USER, "{}")
            apply()
        }
    }

    suspend fun pullSync(): JSONObject? = withContext(Dispatchers.IO) {
        if (serverUrl == null || !isLoggedIn) return@withContext null
        try {
            val request = Request.Builder()
                .url("$serverUrl/sync")
                .addHeader("Authorization", "Bearer $token")
                .get()
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                JSONObject(response.body?.string() ?: "{}")
            } else null
        } catch (e: Exception) {
            Log.e(TAG, "Pull failed", e)
            null
        }
    }

    suspend fun pushField(field: String, data: Any) = withContext(Dispatchers.IO) {
        if (serverUrl == null || !isLoggedIn) return@withContext
        try {
            val json = JSONObject().put("data", data)
            val request = Request.Builder()
                .url("$serverUrl/sync/$field")
                .addHeader("Authorization", "Bearer $token")
                .patch(json.toString().toRequestBody(jsonMediaType))
                .build()

            client.newCall(request).execute().use { 
                Log.d(TAG, "Pushed field: $field, success=${it.isSuccessful}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Push $field failed", e)
        }
    }

    suspend fun pushAll(data: JSONObject) = withContext(Dispatchers.IO) {
        if (serverUrl == null || !isLoggedIn) return@withContext
        try {
            val request = Request.Builder()
                .url("$serverUrl/sync")
                .addHeader("Authorization", "Bearer $token")
                .put(data.toString().toRequestBody(jsonMediaType))
                .build()

            client.newCall(request).execute().use {
                Log.d(TAG, "Full push complete, success=${it.isSuccessful}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Full push failed", e)
        }
    }

    suspend fun getProfile(): JSONObject? = withContext(Dispatchers.IO) {
        if (serverUrl == null || !isLoggedIn) return@withContext null
        try {
            val request = Request.Builder()
                .url("$serverUrl/sync/me")
                .addHeader("Authorization", "Bearer $token")
                .get()
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                JSONObject(response.body?.string() ?: "{}")
            } else null
        } catch (e: Exception) {
            null
        }
    }
}
