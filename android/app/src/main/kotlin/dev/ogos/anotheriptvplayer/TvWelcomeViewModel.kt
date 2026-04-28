package dev.ogos.anotheriptvplayer

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

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
            val result = TvSyncService.login(context, serverUrl, email, password)
            if (result.isSuccess) {
                val ok = TvSyncApplier.pullAndApply(context)
                if (ok) {
                    // Check if we have any playlist in the DB now
                    if (TvRepository.hasPlaylist(context)) {
                        setStep(WelcomeStep.Done)
                    } else {
                        setStep(WelcomeStep.NeedsPlaylist)
                    }
                } else {
                    setStep(WelcomeStep.Error("Sync failed after login"))
                }
            } else {
                setStep(WelcomeStep.Error("Login failed: ${result.exceptionOrNull()?.message}"))
            }
            _isLoading.value = false
        }
    }

    fun register(context: Context, serverUrl: String, name: String, email: String, password: String) {
        setStep(WelcomeStep.Syncing)
        _isLoading.value = true

        viewModelScope.launch {
            val result = TvSyncService.register(context, serverUrl, email, password, name)
            if (result.isSuccess) {
                // Registration usually logs in automatically, so pull sync
                val ok = TvSyncApplier.pullAndApply(context)
                if (ok) {
                    if (TvRepository.hasPlaylist(context)) {
                        setStep(WelcomeStep.Done)
                    } else {
                        setStep(WelcomeStep.NeedsPlaylist)
                    }
                } else {
                    setStep(WelcomeStep.Done) // Still done, but maybe no playlists
                }
            } else {
                setStep(WelcomeStep.Error("Registration failed: ${result.exceptionOrNull()?.message}"))
            }
            _isLoading.value = false
        }
    }
}
