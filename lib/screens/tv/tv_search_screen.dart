import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../models/playlist_content_model.dart';
import 'tv_content_grid.dart';
import 'tv_player_screen.dart';

class TvSearchScreen extends StatefulWidget {
  const TvSearchScreen({super.key});

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _gridFocus = FocusNode();
  List<ContentItem> _results = [];
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
    _queryCtrl.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _queryCtrl.removeListener(_onQueryChanged);
    _queryCtrl.dispose();
    _searchFocus.dispose();
    _gridFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final q = _queryCtrl.text.trim().toLowerCase();
    if (q == _lastQuery) return;
    _lastQuery = q;
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final ctrl = context.read<XtreamCodeHomeController>();
    final all = [
      ...ctrl.allLiveChannels,
      ...ctrl.allMovies,
      ...ctrl.allSeries,
    ];
    setState(() {
      _results = all
          .where((c) => c.name.toLowerCase().contains(q))
          .take(100)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowDown &&
                  _results.isNotEmpty) {
                _gridFocus.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _queryCtrl,
              focusNode: _searchFocus,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 20),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Search channels, movies, series…',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 18),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _queryCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _queryCtrl.clear();
                          _searchFocus.requestFocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),

        // ── Results ──
        if (_queryCtrl.text.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'Start typing to search',
                style: TextStyle(color: Colors.white38, fontSize: 18),
              ),
            ),
          )
        else if (_results.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No results found',
                style: TextStyle(color: Colors.white38, fontSize: 18),
              ),
            ),
          )
        else
          Expanded(
            child: Focus(
              focusNode: _gridFocus,
              onKeyEvent: (node, event) {
                // Up from top row of grid → back to search bar
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _searchFocus.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TvContentGrid(
                sectionKey: 'search_results',
                items: _results,
                onSelect: (item, index, queue) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TvPlayerScreen(
                        contentItem: item,
                        queue: queue,
                        initialIndex: index,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
