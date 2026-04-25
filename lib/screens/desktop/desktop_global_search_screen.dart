import 'dart:async';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Desktop global search across Live TV, Movies, and Series.
class DesktopGlobalSearchScreen extends StatefulWidget {
  const DesktopGlobalSearchScreen({super.key});

  @override
  State<DesktopGlobalSearchScreen> createState() =>
      _DesktopGlobalSearchScreenState();
}

class _DesktopGlobalSearchScreenState extends State<DesktopGlobalSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  Timer? _debounce;

  List<ContentItem> _liveResults = [];
  List<ContentItem> _movieResults = [];
  List<ContentItem> _seriesResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _liveResults.clear();
        _movieResults.clear();
        _seriesResults.clear();
        _hasSearched = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final repo = AppState.xtreamCodeRepository;
      if (repo == null) return;

      final results = await Future.wait([
        repo
            .searchLiveStreams(query)
            .then(
              (streams) => streams
                  .map(
                    (x) => ContentItem(
                      x.streamId,
                      x.name,
                      x.streamIcon,
                      ContentType.liveStream,
                      liveStream: x,
                    ),
                  )
                  .toList(),
            ),
        repo
            .searchMovies(query)
            .then(
              (movies) => movies
                  .map(
                    (x) => ContentItem(
                      x.streamId,
                      x.name,
                      x.streamIcon,
                      ContentType.vod,
                      containerExtension: x.containerExtension,
                      vodStream: x,
                    ),
                  )
                  .toList(),
            ),
        repo
            .searchSeries(query)
            .then(
              (series) => series
                  .map(
                    (x) => ContentItem(
                      x.seriesId,
                      x.name,
                      x.cover ?? '',
                      ContentType.series,
                      seriesStream: x,
                    ),
                  )
                  .toList(),
            ),
      ]);

      if (mounted) {
        setState(() {
          _liveResults = results[0];
          _movieResults = results[1];
          _seriesResults = results[2];
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  List<ContentItem> get _allResults => [
    ..._liveResults,
    ..._movieResults,
    ..._seriesResults,
  ];

  int get _totalCount =>
      _liveResults.length + _movieResults.length + _seriesResults.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: Column(
        children: [
          // Search header
          Container(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Search input
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search Live TV, Movies, and Series...',
                    hintStyle: const TextStyle(color: Color(0xFF747B8B)),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF747B8B),
                      size: 22,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Color(0xFF747B8B),
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF13161C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Tab bar
                if (_hasSearched)
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: const Color(0xFF5A45FF),
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF747B8B),
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: [
                      Tab(text: 'All ($_totalCount)'),
                      Tab(text: 'Live TV (${_liveResults.length})'),
                      Tab(text: 'Movies (${_movieResults.length})'),
                      Tab(text: 'Series (${_seriesResults.length})'),
                    ],
                  ),
              ],
            ),
          ),
          if (_hasSearched) const Divider(height: 1, color: Color(0xFF1E2128)),
          // Results
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5A45FF)),
                  )
                : _hasSearched
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildResultsGrid(_allResults),
                      _buildResultsGrid(_liveResults),
                      _buildResultsGrid(_movieResults),
                      _buildResultsGrid(_seriesResults),
                    ],
                  )
                : _buildInitialState(),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A1D24),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: Color(0xFF747B8B),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Search across all content',
            style: TextStyle(color: Color(0xFF747B8B), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid(List<ContentItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Color(0xFF747B8B),
            ),
            const SizedBox(height: 12),
            Text(
              context.loc.not_found_in_category,
              style: const TextStyle(color: Color(0xFF747B8B)),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _SearchResultCard(
          item: item,
          onTap: () => navigateByContentType(context, item),
        );
      },
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  final ContentItem item;
  final VoidCallback onTap;

  const _SearchResultCard({required this.item, required this.onTap});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF13161C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E2128)),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2C52FF).withValues(alpha: 0.2),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.item.imagePath.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.item.imagePath,
                              fit:
                                  widget.item.contentType ==
                                      ContentType.liveStream
                                  ? BoxFit.contain
                                  : BoxFit.cover,
                              errorWidget: (_, __, ___) => _buildFallback(),
                            )
                          : _buildFallback(),
                      if (_hovered)
                        Container(
                          color: Colors.black.withValues(alpha: 0.4),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF5A45FF),
                                    Color(0xFF00D1FF),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      // Content type badge
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _typeName(widget.item.contentType),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    widget.item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: const Color(0xFF0F1115),
      child: Center(
        child: Icon(
          _typeIcon(widget.item.contentType),
          size: 28,
          color: const Color(0xFF262A35),
        ),
      ),
    );
  }

  String _typeName(ContentType t) {
    switch (t) {
      case ContentType.liveStream:
        return 'LIVE';
      case ContentType.vod:
        return 'MOVIE';
      case ContentType.series:
        return 'SERIES';
    }
  }

  IconData _typeIcon(ContentType t) {
    switch (t) {
      case ContentType.liveStream:
        return Icons.live_tv_rounded;
      case ContentType.vod:
        return Icons.movie_rounded;
      case ContentType.series:
        return Icons.tv_rounded;
    }
  }
}
