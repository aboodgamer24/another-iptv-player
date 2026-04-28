package dev.ogos.anotheriptvplayer

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

sealed class WelcomeStep {
    object Welcome : WelcomeStep()
    object LoginForm : WelcomeStep()
    object RegisterForm : WelcomeStep()
    object Syncing : WelcomeStep()
    object NeedsPlaylist : WelcomeStep()
    object Done : WelcomeStep()
    data class Error(val message: String) : WelcomeStep()
}

class TvWelcomeViewModel : ViewModel() {
    private val _currentStep = MutableStateFlow<WelcomeStep>(WelcomeStep.Welcome)
    val currentStep = _currentStep.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage = _errorMessage.asStateFlow()

    var isGuestMode = false
    var pendingNavigationTab: Int? = null

    private val client = OkHttpClient()

    fun setStep(step: WelcomeStep) {
        _currentStep.value = step
        if (step is WelcomeStep.Error) {
            _errorMessage.value = step.message
        } else {
            _errorMessage.value = null
        }
    }

    fun signIn(context: Context, serverUrl: String, email: String, password: String) {
        setStep(WelcomeStep.Syncing)
        _isLoading.value = true

        viewModelScope.launch {
            try {
                val formattedUrl = if (serverUrl.endsWith("/")) serverUrl.removeSuffix("/") else serverUrl
                val json = JSONObject().apply {
                    put("email", email)
                    put("password", password)
                }
                val body = json.toString().toRequestBody("application/json; charset=utf-8".toMediaTypeOrNull())
                val request = Request.Builder()
                    .url("$formattedUrl/auth/login")
                    .post(body)
                    .build()

                val response = withContext(Dispatchers.IO) {
                    client.newCall(request).execute()
                }

                if (response.isSuccessful) {
                    val responseBody = response.body?.string()
                    val responseObj = JSONObject(responseBody ?: "")
                    val token = responseObj.optString("token")

                    if (token.isNotEmpty()) {
                        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        prefs.edit()
                            .putString("flutter.sync_token", token)
                            .putString("flutter.sync_server_url", formattedUrl)
                            .apply()

                        val hasPlaylist = prefs.contains("flutter.current_playlist_json") &&
                            !prefs.getString("flutter.current_playlist_json", "").isNullOrEmpty()

                        if (hasPlaylist) {
                            TvRepository.loadPlaylist(context)
                            setStep(WelcomeStep.Done)
                        } else {
                            // Logged in but no playlist stored yet — go to Settings so user can add one
                            setStep(WelcomeStep.NeedsPlaylist)
                        }
                    } else {
                        setStep(WelcomeStep.Error("Invalid response from server"))
                    }
                } else {
                    setStep(WelcomeStep.Error("Login failed: ${response.code}"))
                }
            } catch (e: Exception) {
                setStep(WelcomeStep.Error("Connection error: ${e.message}"))
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun register(context: Context, serverUrl: String, name: String, email: String, password: String) {
        setStep(WelcomeStep.Syncing)
        _isLoading.value = true

        viewModelScope.launch {
            try {
                val formattedUrl = if (serverUrl.endsWith("/")) serverUrl.removeSuffix("/") else serverUrl
                val json = JSONObject().apply {
                    put("name", name)
                    put("email", email)
                    put("password", password)
                }
                val body = json.toString().toRequestBody("application/json; charset=utf-8".toMediaTypeOrNull())
                val request = Request.Builder()
                    .url("$formattedUrl/auth/register")
                    .post(body)
                    .build()

                val response = withContext(Dispatchers.IO) {
                    client.newCall(request).execute()
                }

                if (response.isSuccessful) {
                    signIn(context, serverUrl, email, password)
                } else {
                    setStep(WelcomeStep.Error("Registration failed: ${response.code}"))
                    _isLoading.value = false
                }
            } catch (e: Exception) {
                setStep(WelcomeStep.Error("Connection error: ${e.message}"))
                _isLoading.value = false
            }
        }
    }
}
