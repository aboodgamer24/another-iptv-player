package dev.ogos.anotheriptvplayer

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

class TvShellViewModel : ViewModel() {
    private val _selectedIndex = MutableStateFlow(0)
    val selectedIndex = _selectedIndex.asStateFlow()

    private val _railExpanded = MutableStateFlow(false)
    val railExpanded = _railExpanded.asStateFlow()

    fun setSelectedIndex(index: Int) {
        _selectedIndex.value = index
    }

    fun setRailExpanded(expanded: Boolean) {
        _railExpanded.value = expanded
    }
}
