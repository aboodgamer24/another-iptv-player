package dev.ogos.anotheriptvplayer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class TvContentViewModel : ViewModel() {
    private val _state = MutableStateFlow(TvContentState())
    val state = _state.asStateFlow()

    fun loadContent() {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true)
            val api = TvRepository.getApiService()
            val (u, p, _) = TvRepository.getPlaylistCredentials()
            
            if (api != null) {
                try {
                    val liveCats = api.getLiveCategories(u, p)
                    val vodCats = api.getVodCategories(u, p)
                    val seriesCats = api.getSeriesCategories(u, p)
                    
                    _state.value = _state.value.copy(
                        isLoading = false,
                        liveCategories = liveCats.map { TvCategory(it.category_id, it.category_name) },
                        vodCategories = vodCats.map { TvCategory(it.category_id, it.category_name) },
                        seriesCategories = seriesCats.map { TvCategory(it.category_id, it.category_name) }
                    )
                    
                    // Load initial data for first 5 categories in parallel
                    liveCats.take(5).forEach { loadLiveChannels(it.category_id) }
                    vodCats.take(5).forEach { loadVodMovies(it.category_id) }
                    seriesCats.take(5).forEach { loadSeries(it.category_id) }
                    
                } catch (e: Exception) {
                    _state.value = _state.value.copy(isLoading = false)
                }
            } else {
                _state.value = _state.value.copy(isLoading = false)
            }
        }
    }

    fun loadLiveChannels(categoryId: String) {
        viewModelScope.launch {
            val api = TvRepository.getApiService()
            val (u, p, _) = TvRepository.getPlaylistCredentials()
            if (api != null) {
                try {
                    val channels = api.getLiveStreams(u, p, categoryId)
                    val items = channels.map {
                        TvContentItem(
                            id = it.stream_id,
                            name = it.name,
                            url = TvRepository.buildStreamUrl(it.stream_id, "live"),
                            imageUrl = it.stream_icon ?: "",
                            contentType = "live",
                            categoryId = it.category_id
                        )
                    }
                    val newMap = _state.value.liveChannels.toMutableMap()
                    newMap[categoryId] = items
                    _state.value = _state.value.copy(liveChannels = newMap)
                } catch (e: Exception) {}
            }
        }
    }

    fun loadVodMovies(categoryId: String) {
        viewModelScope.launch {
            val api = TvRepository.getApiService()
            val (u, p, _) = TvRepository.getPlaylistCredentials()
            if (api != null) {
                try {
                    val movies = api.getVodStreams(u, p, categoryId)
                    val items = movies.map {
                        TvContentItem(
                            id = it.stream_id,
                            name = it.name,
                            url = TvRepository.buildStreamUrl(it.stream_id, "movie", it.container_extension ?: "mp4"),
                            imageUrl = it.stream_icon ?: "",
                            contentType = "movie",
                            categoryId = it.category_id
                        )
                    }
                    val newMap = _state.value.vodItems.toMutableMap()
                    newMap[categoryId] = items
                    _state.value = _state.value.copy(vodItems = newMap)
                } catch (e: Exception) {}
            }
        }
    }

    fun loadSeries(categoryId: String) {
        viewModelScope.launch {
            val api = TvRepository.getApiService()
            val (u, p, _) = TvRepository.getPlaylistCredentials()
            if (api != null) {
                try {
                    val series = api.getSeries(u, p, categoryId)
                    val items = series.map {
                        TvContentItem(
                            id = it.series_id,
                            name = it.name,
                            url = "", // Series need info fetch for episode URLs
                            imageUrl = it.cover ?: "",
                            contentType = "series",
                            categoryId = it.category_id
                        )
                    }
                    val newMap = _state.value.seriesItems.toMutableMap()
                    newMap[categoryId] = items
                    _state.value = _state.value.copy(seriesItems = newMap)
                } catch (e: Exception) {}
            }
        }
    }
}

data class TvContentState(
    val isLoading: Boolean = false,
    val liveCategories: List<TvCategory> = emptyList(),
    val liveChannels: Map<String, List<TvContentItem>> = emptyMap(),
    val vodCategories: List<TvCategory> = emptyList(),
    val vodItems: Map<String, List<TvContentItem>> = emptyMap(),
    val seriesCategories: List<TvCategory> = emptyList(),
    val seriesItems: Map<String, List<TvContentItem>> = emptyMap()
)

data class TvContentItem(
    val id: String,
    val name: String,
    val url: String,
    val imageUrl: String,
    val contentType: String,
    val categoryId: String = "",
    val rating: String = "",
    val plot: String = "",
    val cast: String = "",
    val director: String = "",
    val year: String = "",
    val duration: String = "",
    val subtitleUrl: String = ""
)

data class TvCategory(val id: String, val name: String)
