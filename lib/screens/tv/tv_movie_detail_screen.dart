import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/screens/tv/tv_exo_player_screen.dart';
import 'package:another_iptv_player/controllers/favorites_controller.dart';
import 'package:another_iptv_player/controllers/watch_later_controller.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:provider/provider.dart';

class TvMovieDetailScreen extends StatefulWidget {
  final ContentItem contentItem;

  const TvMovieDetailScreen({super.key, required this.contentItem});

  @override
  State<TvMovieDetailScreen> createState() => _TvMovieDetailScreenState();
}

class _TvMovieDetailScreenState extends State<TvMovieDetailScreen> {
  late FavoritesController _favoritesController;
  late WatchLaterController _watchLaterController;

  bool _isFavorite = false;
  bool _isInWatchLater = false;

  final FocusNode _playNode = FocusNode(debugLabel: 'movie-play');
  final FocusNode _watchLaterNode = FocusNode(debugLabel: 'movie-wl');
  final FocusNode _favoriteNode = FocusNode(debugLabel: 'movie-fav');

  @override
  void initState() {
    super.initState();
    _favoritesController = context.read<FavoritesController>();
    _watchLaterController = context.read<WatchLaterController>();
    _checkStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _playNode.dispose();
    _watchLaterNode.dispose();
    _favoriteNode.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final fav = await _favoritesController.isFavorite(
      widget.contentItem.id,
      widget.contentItem.contentType,
    );
    final wl = await _watchLaterController.isWatchLater(
      widget.contentItem.id,
      widget.contentItem.contentType,
    );

    if (mounted) {
      setState(() {
        _isFavorite = fav;
        _isInWatchLater = wl;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final result = await _favoritesController.toggleFavorite(widget.contentItem);
    if (mounted) {
      setState(() {
        _isFavorite = result;
      });
    }
  }

  Future<void> _toggleWatchLater() async {
    final result = await _watchLaterController.toggleWatchLater(widget.contentItem);
    if (mounted) {
      setState(() {
        _isInWatchLater = result;
      });
    }
  }

  void _playMovie() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvExoPlayerScreen(contentItem: widget.contentItem),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.backspace) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
          // Background Image with Gradient
          Positioned.fill(
            child: widget.contentItem.imagePath.isNotEmpty
                ? Image.network(
                    widget.contentItem.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.black),
                  )
                : Container(color: Colors.black),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF0F1014),
                    const Color(0xFF0F1014).withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF0F1014),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4],
                ),
              ),
            ),
          ),

          // Content
          Positioned(
            left: 64,
            bottom: 64,
            top: 64,
            width: MediaQuery.of(context).size.width * 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: widget.contentItem.id,
                  child: Text(
                    widget.contentItem.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('MOVIE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    const Text('VOD', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Buttons
                FocusTraversalGroup(
                  child: Row(
                    children: [
                      _buildButton(
                        focusNode: _playNode,
                        icon: Icons.play_arrow_rounded,
                        label: context.loc.start_watching,
                        onPressed: _playMovie,
                        isPrimary: true,
                      ),
                      const SizedBox(width: 16),
                      _buildButton(
                        focusNode: _watchLaterNode,
                        icon: _isInWatchLater ? Icons.watch_later : Icons.watch_later_outlined,
                        label: 'Watch Later',
                        onPressed: _toggleWatchLater,
                      ),
                      const SizedBox(width: 16),
                      _buildButton(
                        focusNode: _favoriteNode,
                        icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                        label: 'Favorite',
                        onPressed: _toggleFavorite,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildButton({
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (focused) => setState(() {}),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.select) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: focusNode.hasFocus 
                ? Colors.white 
                : (isPrimary ? Theme.of(context).colorScheme.primary : Colors.white10),
            borderRadius: BorderRadius.circular(8),
            border: focusNode.hasFocus ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: focusNode.hasFocus 
                    ? Colors.black 
                    : (isPrimary ? Colors.white : Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: focusNode.hasFocus 
                      ? Colors.black 
                      : (isPrimary ? Colors.white : Colors.white),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
