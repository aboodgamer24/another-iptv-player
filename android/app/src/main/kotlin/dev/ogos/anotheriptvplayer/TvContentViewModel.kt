package dev.ogos.anotheriptvplayer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Dispatchers
import android.content.Context

class TvContentViewModel : ViewModel() {
    private val _state = MutableStateFlow(TvContentState())
    val state = _state.asStateFlow()

    fun loadContent(context: Context) {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true)

            // Ensure playlist is loaded — this is fast (SharedPreferences read)
            // but must complete before we call getApiService()
            withContext(Dispatchers.IO) {
                TvRepository.loadPlaylist(context)
            }

            val api = TvRepository.getApiService()
            val (u, p, _) = TvRepository.getPlaylistCredentials()

            if (api == null) {
                // No playlist configured yet — not an error, just nothing to load
                _state.value = _state.value.copy(isLoading = false, noPlaylist = true)
                return@launch
            }

            try {
                val liveCats  = api.getLiveCategories(u, p)
                val vodCats   = api.getVodCategories(u, p)
                val seriesCats = api.getSeriesCategories(u, p)

                _state.value = _state.value.copy(
                    isLoading       = false,
                    noPlaylist      = false,
                    liveCategories  = liveCats.map  { TvCategory(it.category_id, it.category_name) },
                    vodCategories   = vodCats.map   { TvCategory(it.category_id, it.category_name) },
                    seriesCategories = seriesCats.map { TvCategory(it.category_id, it.category_name) }
                )

                liveCats.take(5).forEach   { loadLiveChannels(it.category_id) }
                vodCats.take(5).forEach    { loadVodMovies(it.category_id)    }
                seriesCats.take(5).forEach { loadSeries(it.category_id)       }

            } catch (e: Exception) {
                _state.value = _state.value.copy(
                    isLoading = false,
                    loadError = e.message ?: "Failed to load content"
                )
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

    fun loadSeriesDetail(series: TvContentItem) {
        viewModelScope.launch {
            _state.value = _state.value.copy(
                seriesDetail = SeriesDetailState(item = series, isLoading = true)
            )
            val api = TvRepository.getApiService()
            val (u, p, _) = TvRepository.getPlaylistCredentials()
            if (api == null) {
                _state.value = _state.value.copy(
                    seriesDetail = _state.value.seriesDetail?.copy(isLoading = false, error = "No playlist configured")
                )
                return@launch
            }
            try {
                val info = api.getSeriesInfo(u, p, seriesId = series.id)
                val seasons = info.episodes?.mapValues { (_, eps) ->
                    eps.map { ep ->
                        TvContentItem(
                            id = ep.id,
                            name = "E${ep.episode_num} — ${ep.title}",
                            url = TvRepository.buildEpisodeUrl(ep.id, ep.container_extension ?: "mkv"),
                            imageUrl = series.imageUrl,
                            contentType = "series",
                        )
                    }
                } ?: emptyMap()
                _state.value = _state.value.copy(
                    seriesDetail = SeriesDetailState(item = series, isLoading = false, seasons = seasons)
                )
            } catch (e: Exception) {
                _state.value = _state.value.copy(
                    seriesDetail = _state.value.seriesDetail?.copy(isLoading = false, error = e.message ?: "Error")
                )
            }
        }
    }

    fun clearSeriesDetail() {
        _state.value = _state.value.copy(seriesDetail = null)
    }

    fun search(query: String) {
        if (query.isBlank()) {
            _state.value = _state.value.copy(
                searchResults = emptyList(),
                isSearching = false,
                searchQuery = ""
            )
            return
        }
        viewModelScope.launch {
            _state.value = _state.value.copy(isSearching = true, searchQuery = query)
            val api = TvRepository.getApiService()
            val (u, p, _) = TvRepository.getPlaylistCredentials()

            if (api == null) {
                _state.value = _state.value.copy(isSearching = false, searchResults = emptyList())
                return@launch
            }

            val results = mutableListOf<TvContentItem>()

            // Search live channels: filter already-loaded channels by name
            _state.value.liveChannels.values.flatten().filter {
                it.name.contains(query, ignoreCase = true)
            }.let { results.addAll(it) }

            // Search VOD: filter already-loaded movies by name
            _state.value.vodItems.values.flatten().filter {
                it.name.contains(query, ignoreCase = true)
            }.let { results.addAll(it) }

            // Search Series: filter already-loaded series by name
            _state.value.seriesItems.values.flatten().filter {
                it.name.contains(query, ignoreCase = true)
            }.let { results.addAll(it) }

            // If results are sparse (< 5), also fetch from API directly without category_id filter
            if (results.size < 5) {
                try {
                    val liveCategories = _state.value.liveCategories
                    if (liveCategories.isNotEmpty()) {
                        val all = api.getLiveStreams(u, p, liveCategories[0].id)
                        all.filter { it.name.contains(query, ignoreCase = true) }
                            .map {
                                TvContentItem(
                                    id = it.stream_id, name = it.name,
                                    url = TvRepository.buildStreamUrl(it.stream_id, "live"),
                                    imageUrl = it.stream_icon ?: "", contentType = "live"
                                )
                            }.let { results.addAll(it) }
                    }
                } catch (_: Exception) {}

                try {
                    val vodCategories = _state.value.vodCategories
                    if (vodCategories.isNotEmpty()) {
                        val all = api.getVodStreams(u, p, vodCategories[0].id)
                        all.filter { it.name.contains(query, ignoreCase = true) }
                            .map {
                                TvContentItem(
                                    id = it.stream_id, name = it.name,
                                    url = TvRepository.buildStreamUrl(it.stream_id, "movie", it.container_extension ?: "mp4"),
                                    imageUrl = it.stream_icon ?: "", contentType = "movie"
                                )
                            }.let { results.addAll(it) }
                    }
                } catch (_: Exception) {}
            }

            _state.value = _state.value.copy(
                isSearching = false,
                searchResults = results.distinctBy { it.id + it.contentType }.take(60)
            )
        }
    }

    fun loadFavorites(context: Context) {
        viewModelScope.launch {
            _state.value = _state.value.copy(isFavoritesLoading = true)

            // 1. Load local SQLite first (fast, immediate)
            val localItems = withContext(Dispatchers.IO) {
                TvRepository.getFavorites(context)
            }
            _state.value = _state.value.copy(favorites = localItems)

            // 2. Pull from server in background (may override/extend local)
            val serverItems = SyncRepository.pullFavoritesFromServer(context)
            if (serverItems.isNotEmpty()) {
                // Merge: server is source of truth, write back to local SQLite
                withContext(Dispatchers.IO) {
                    serverItems.forEach { TvRepository.saveFavorite(context, it) }
                }
                _state.value = _state.value.copy(
                    favorites = serverItems,
                    favoriteIds = serverItems.map { it.id }.toSet()
                )
            } else {
                _state.value = _state.value.copy(
                    favoriteIds = localItems.map { it.id }.toSet()
                )
            }

            _state.value = _state.value.copy(isFavoritesLoading = false)
        }
    }

    fun toggleFavorite(context: Context, item: TvContentItem) {
        viewModelScope.launch {
            val isFav = _state.value.favoriteIds.contains(item.id)
            withContext(Dispatchers.IO) {
                if (isFav) {
                    TvRepository.removeFavorite(context, item.id)
                    SyncRepository.pushFavoriteToServer(context, item, remove = true)
                } else {
                    TvRepository.saveFavorite(context, item)
                    SyncRepository.pushFavoriteToServer(context, item, remove = false)
                }
            }
            _state.value = if (isFav) {
                _state.value.copy(
                    favoriteIds = _state.value.favoriteIds - item.id,
                    favorites = _state.value.favorites.filter { it.id != item.id }
                )
            } else {
                _state.value.copy(
                    favoriteIds = _state.value.favoriteIds + item.id,
                    favorites = listOf(item) + _state.value.favorites
                )
            }
        }
    }

    fun loadWatchHistory(context: Context) {
        viewModelScope.launch {
            _state.value = _state.value.copy(isHistoryLoading = true)
            val items = withContext(Dispatchers.IO) {
                TvRepository.getWatchHistory(context)
            }
            _state.value = _state.value.copy(watchHistory = items, isHistoryLoading = false)
        }
    }
}

data class SeriesDetailState(
    val item: TvContentItem,
    val isLoading: Boolean = true,
    val seasons: Map<String, List<TvContentItem>> = emptyMap(), // season number → episodes
    val error: String = ""
)

data class TvContentState(
    val isLoading: Boolean = false,
    val noPlaylist: Boolean = false,
    val loadError: String = "",
    val liveCategories: List<TvCategory> = emptyList(),
    val liveChannels: Map<String, List<TvContentItem>> = emptyMap(),
    val vodCategories: List<TvCategory> = emptyList(),
    val vodItems: Map<String, List<TvContentItem>> = emptyMap(),
    val seriesCategories: List<TvCategory> = emptyList(),
    val seriesItems: Map<String, List<TvContentItem>> = emptyMap(),
    val seriesDetail: SeriesDetailState? = null,
    val searchResults: List<TvContentItem> = emptyList(),
    val isSearching: Boolean = false,
    val searchQuery: String = "",
    val favorites: List<TvContentItem> = emptyList(),
    val favoriteIds: Set<String> = emptySet(),
    val watchHistory: List<TvContentItem> = emptyList(),
    val isFavoritesLoading: Boolean = false,
    val isHistoryLoading: Boolean = false
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
