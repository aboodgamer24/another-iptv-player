import 'package:flutter/material.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../repositories/iptv_repository.dart';
import '../../services/app_state.dart';
import '../../utils/navigate_by_content_type.dart';
import 'c4_card.dart';

class C4SearchModal extends StatefulWidget {
  const C4SearchModal({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
       barrierLabel: 'Search',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const C4SearchModal();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.1, end: 1.0).animate(anim1),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<C4SearchModal> createState() => _C4SearchModalState();
}

class _C4SearchModalState extends State<C4SearchModal> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final IptvRepository _repository = AppState.xtreamCodeRepository!;
  
  List<ContentItem> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSearch(String query) async {
    if (query.length < 2) {
      if (mounted) setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final List<ContentItem> allResults = [];
      
      // 1. Search Live
      final live = await _repository.searchLiveStreams(query);
      allResults.addAll(live.take(10).map((x) => ContentItem(x.streamId, x.name, x.streamIcon, ContentType.liveStream, liveStream: x)));
      
      // 2. Search Movies
      final movies = await _repository.searchMovies(query);
      allResults.addAll(movies.take(10).map((x) => ContentItem(x.streamId, x.name, x.streamIcon, ContentType.vod, vodStream: x)));
      
      // 3. Search Series
      final series = await _repository.searchSeries(query);
      allResults.addAll(series.take(10).map((x) => ContentItem(x.seriesId, x.name, x.cover ?? '', ContentType.series, seriesStream: x)));

      if (mounted) {
        setState(() {
          _results = allResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              // Search Input
              TextField(
                controller: _controller,
                focusNode: _inputFocusNode,
                onChanged: _handleSearch,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Search for movies, series or channels...',
                  prefixIcon: const Icon(Icons.search, size: 32),
                  suffixIcon: _isLoading ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ) : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              const SizedBox(height: 40),

              // Results area
              Expanded(
                child: _results.isEmpty 
                  ? Center(child: Text(_controller.text.isEmpty ? 'Type to start searching' : 'No results found', style: theme.textTheme.titleMedium?.copyWith(color: theme.hintColor)))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        childAspectRatio: 2/3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return C4Card(
                          title: item.name,
                          imageUrl: item.imageUrl,
                          contentType: item.contentType,
                          onTap: () {
                            Navigator.pop(context);
                            navigateByContentType(context, item);
                          },
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
