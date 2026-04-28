package dev.ogos.anotheriptvplayer

import retrofit2.http.GET
import retrofit2.http.Query

interface XtreamApiService {
    @GET("player_api.php")
    suspend fun getLiveCategories(
        @Query("username") u: String,
        @Query("password") p: String,
        @Query("action") action: String = "get_live_categories"
    ): List<XtreamCategory>

    @GET("player_api.php")
    suspend fun getLiveStreams(
        @Query("username") u: String,
        @Query("password") p: String,
        @Query("category_id") categoryId: String,
        @Query("action") action: String = "get_live_streams"
    ): List<XtreamLiveStream>

    @GET("player_api.php")
    suspend fun getVodCategories(
        @Query("username") u: String,
        @Query("password") p: String,
        @Query("action") action: String = "get_vod_categories"
    ): List<XtreamCategory>

    @GET("player_api.php")
    suspend fun getVodStreams(
        @Query("username") u: String,
        @Query("password") p: String,
        @Query("category_id") categoryId: String,
        @Query("action") action: String = "get_vod_streams"
    ): List<XtreamVodStream>

    @GET("player_api.php")
    suspend fun getSeriesCategories(
        @Query("username") u: String,
        @Query("password") p: String,
        @Query("action") action: String = "get_series_categories"
    ): List<XtreamCategory>

    @GET("player_api.php")
    suspend fun getSeries(
        @Query("username") u: String,
        @Query("password") p: String,
        @Query("category_id") categoryId: String,
        @Query("action") action: String = "get_series"
    ): List<XtreamSeries>

    @GET("player_api.php")
    suspend fun getSeriesInfo(
        @Query("username") username: String,
        @Query("password") password: String,
        @Query("action") action: String = "get_series_info",
        @Query("series_id") seriesId: String
    ): SeriesInfoResponse

    @GET("player_api.php")
    suspend fun getVodInfo(
        @Query("username") u: String,
        @Query("password") p: String,
        @Query("vod_id") vodId: String,
        @Query("action") action: String = "get_vod_info"
    ): XtreamVodInfo
}

data class SeriesInfoResponse(
    val info: SeriesInfo? = null,
    val episodes: Map<String, List<EpisodeItem>>? = null
)

data class SeriesInfo(
    val name: String = "",
    val cover: String = "",
    val plot: String = "",
    val cast: String = "",
    val director: String = "",
    val genre: String = "",
    val releaseDate: String = "",
    val rating: String = ""
)

data class EpisodeItem(
    val id: String = "",
    val episode_num: Int = 0,
    val title: String = "",
    val container_extension: String = "mkv",
    val info: EpisodeInfo? = null
)

data class EpisodeInfo(
    val duration: String = "",
    val plot: String = "",
    val rating: String = ""
)

data class XtreamCategory(
    val category_id: String,
    val category_name: String
)

data class XtreamLiveStream(
    val stream_id: String,
    val name: String,
    val stream_icon: String?,
    val category_id: String
)

data class XtreamVodStream(
    val stream_id: String,
    val name: String,
    val stream_icon: String?,
    val category_id: String,
    val container_extension: String?
)

data class XtreamSeries(
    val series_id: String,
    val name: String,
    val cover: String?,
    val category_id: String
)

data class XtreamSeriesInfo(
    val info: XtreamSeriesMetadata,
    val episodes: Map<String, List<XtreamEpisode>>
)

data class XtreamSeriesMetadata(
    val name: String,
    val cover: String?,
    val plot: String?,
    val cast: String?,
    val director: String?,
    val releaseDate: String?,
    val rating: String?
)

data class XtreamEpisode(
    val id: String,
    val episode_num: String,
    val title: String,
    val container_extension: String?,
    val season: Int
)

data class XtreamVodInfo(
    val info: XtreamVodMetadata
)

data class XtreamVodMetadata(
    val name: String,
    val movie_image: String?,
    val plot: String?,
    val cast: String?,
    val director: String?,
    val release_date: String?,
    val rating: String?,
    val duration: String?
)
