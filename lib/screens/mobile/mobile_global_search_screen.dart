import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../services/app_state.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../l10n/localization_extension.dart';

class MobileGlobalSearchScreen extends StatefulWidget {
  const MobileGlobalSearchScreen({super.key});

  @override
  State<MobileGlobalSearchScreen> createState() => _MobileGlobalSearchScreenState();
}

class _MobileGlobalSearchScreenState extends State<MobileGlobalSearchScreen> with SingleTickerProviderStateMixin {
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
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _performSearch(query));
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
        repo.searchLiveStreams(query).then((streams) => streams.map((x) => ContentItem(x.streamId, x.name, x.streamIcon, ContentType.liveStream, liveStream: x)).toList()),
        repo.searchMovies(query).then((movies) => movies.map((x) => ContentItem(x.streamId, x.name, x.streamIcon, ContentType.vod, containerExtension: x.containerExtension, vodStream: x)).toList()),
        repo.searchSeries(query).then((series) => series.map((x) => ContentItem(x.seriesId, x.name, x.cover ?? '', ContentType.series, seriesStream: x)).toList()),
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
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13161C),
        leading: const BackButton(),
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
        bottom: _hasSearched
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  Tab(text: 'All (${_liveResults.length + _movieResults.length + _seriesResults.length})'),
                  Tab(text: 'Live (${_liveResults.length})'),
                  Tab(text: 'Movies (${_movieResults.length})'),
                  Tab(text: 'Series (${_seriesResults.length})'),
                ],
              )
            : null,
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _hasSearched
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildResultsList([..._liveResults, ..._movieResults, ..._seriesResults]),
                    _buildResultsList(_liveResults),
                    _buildResultsList(_movieResults),
                    _buildResultsList(_seriesResults),
                  ],
                )
              : _buildInitialState(),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(context.loc.search, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildResultsList(List<ContentItem> items) {
    if (items.isEmpty) {
      return Center(child: Text(context.loc.not_found_in_category, style: const TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: item.imageUrl,
              width: 50,
              height: 40,
              fit: item.contentType == ContentType.liveStream ? BoxFit.contain : BoxFit.cover,
              errorWidget: (_, __, ___) => const Icon(Icons.movie, color: Colors.white24),
            ),
          ),
          title: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: Text(
            item.contentType == ContentType.liveStream ? 'Live' : (item.contentType == ContentType.vod ? 'Movie' : 'Series'),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          onTap: () => navigateByContentType(context, item),
        );
      },
    );
  }
}
