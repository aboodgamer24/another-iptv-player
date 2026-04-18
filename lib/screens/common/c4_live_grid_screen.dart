import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../controllers/favorites_controller.dart';
import '../../l10n/localization_extension.dart';
import '../../models/playlist_content_model.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../widgets/player_widget.dart';
import '../../screens/live_stream/live_stream_screen.dart';

class C4LiveGridScreen extends StatefulWidget {
  const C4LiveGridScreen({super.key});

  @override
  State<C4LiveGridScreen> createState() => _C4LiveGridScreenState();
}

class _C4LiveGridScreenState extends State<C4LiveGridScreen> {
  int _selectedCategoryIndex = 0;
  ContentItem? _selectedChannel;
  Key _playerKey = UniqueKey();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _enterFullscreen() async {
    if (_selectedChannel == null) return;

    // Dispose the inline player by clearing the selected channel.
    // This triggers PlayerWidget to unmount and calls player.dispose().
    final channel = _selectedChannel!;

    setState(() {
      _selectedChannel = null; // Unmounts inline PlayerWidget → disposes player
    });

    // Small delay to let the player dispose before the new screen opens
    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) {
      // If unmounted, just restore internal state in case we're still alive
      _selectedChannel = channel;
      return;
    }

    // Navigate to the dedicated full-screen live stream screen.
    // LiveStreamScreen creates its own PlayerWidget with a fresh player.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveStreamScreen(content: channel),
      ),
    );

    // When user presses back, restore the inline player to the same channel
    if (mounted) {
      setState(() {
        _selectedChannel = channel;
        _playerKey = UniqueKey(); // fresh inline player
      });
    }
  }

  List<ContentItem> get _currentCategoryChannels {
    final controller = context.read<XtreamCodeHomeController>();
    final categories = controller.liveCategories!;
    return categories[_selectedCategoryIndex].contentItems;
  }

  Widget _buildIdlePlaceholder() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.live_tv, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              'Select a channel to start watching',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<XtreamCodeHomeController>();
    final favoritesController = context.watch<FavoritesController>();

    if (controller.liveCategories == null || controller.liveCategories!.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = controller.liveCategories!;
    final selectedCategory = categories[_selectedCategoryIndex];
    final channels = selectedCategory.contentItems;

    // Filter channels based on search query
    final filteredChannels = channels
        .where((c) => c.name.toLowerCase().contains(_searchQuery))
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Categories Sidebar (Left, 200px)
        Container(
          width: 200,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1), width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  context.loc.live_streams.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedCategoryIndex == index;
                    return _CategoryTile(
                      title: categories[index].category.categoryName,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedCategoryIndex = index;
                          _selectedChannel = null; // Reset selection on category change
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // 2. Center Column (Expanded)
        Expanded(
          child: Container(
            color: Colors.black.withValues(alpha: 0.1),
            child: Column(
              children: [
                // Top Half: Player Area (16:7)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selectedChannel == null
                        ? _buildIdlePlaceholder()
                        : PlayerWidget(
                            key: _playerKey,
                            contentItem: _selectedChannel!,
                            showControls: true,
                            showInfo: false,
                            onFullscreen: () => _enterFullscreen(),
                            queue: _currentCategoryChannels,
                            isInline: true,
                          ),
                  ),
                ),

                // Bottom Half: Search + Channel List
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Search bar
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "Search channels...",
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Channel List
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredChannels.length,
                            itemBuilder: (context, index) {
                              final channel = filteredChannels[index];
                              final isSelected = _selectedChannel?.id == channel.id;
                              final isFavorited = favoritesController.favorites.any(
                                (f) => f.streamId == channel.id && f.contentType == channel.contentType,
                              );

                              return Container(
                                height: 64,
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? theme.colorScheme.primary.withValues(alpha: 0.15) 
                                      : Colors.transparent,
                                  border: isSelected 
                                      ? Border(left: BorderSide(color: theme.colorScheme.primary, width: 3)) 
                                      : null,
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedChannel = channel;
                                      _playerKey = UniqueKey(); // forces rebuild & new stream
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        // Channel Logo
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            color: theme.colorScheme.surface,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: channel.imageUrl.isNotEmpty
                                              ? Image.network(channel.imageUrl, fit: BoxFit.contain)
                                              : const Icon(Icons.live_tv_rounded, size: 24, color: Colors.white24),
                                        ),
                                        const SizedBox(width: 16),
                                        // Name
                                        Expanded(
                                          child: Text(
                                            channel.name,
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Favorite button
                                        IconButton(
                                          icon: Icon(
                                            isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            color: isFavorited ? Colors.redAccent : theme.hintColor,
                                            size: 20,
                                          ),
                                          onPressed: () => favoritesController.toggleFavorite(channel),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Info Panel (Right, 320px)
        Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1), width: 1)),
          ),
          child: _selectedChannel == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tv_off_rounded, size: 48, color: theme.hintColor.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text("No channel selected", style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Large logo
                      Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _selectedChannel!.imageUrl.isNotEmpty
                              ? Image.network(_selectedChannel!.imageUrl, fit: BoxFit.contain)
                              : const Icon(Icons.live_tv_rounded, size: 64, color: Colors.white10),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Title + LIVE pill
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedChannel!.name,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "LIVE",
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 32),
                      // Watch Now Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => navigateByContentType(context, _selectedChannel!),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text("Watch Now"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Favorite Toggle Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => favoritesController.toggleFavorite(_selectedChannel!),
                          icon: Icon(
                            favoritesController.favorites.any((f) => f.streamId == _selectedChannel!.id)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                          ),
                          label: Text(
                            favoritesController.favorites.any((f) => f.streamId == _selectedChannel!.id)
                                ? "Remove from Favorites"
                                : "Add to Favorites",
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: favoritesController.favorites.any((f) => f.streamId == _selectedChannel!.id)
                                ? Colors.redAccent
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            side: BorderSide(
                              color: favoritesController.favorites.any((f) => f.streamId == _selectedChannel!.id)
                                  ? Colors.redAccent.withValues(alpha: 0.5)
                                  : theme.dividerColor,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      // EPG Section
                      Text(
                        "NEXT PROGRAM",
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.bold,
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text("No program info available.", style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Focus(
        onFocusChange: (focused) {
          if (focused) onTap();
        },
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? theme.colorScheme.primary.withValues(alpha: 0.2) 
                      : (focused ? theme.colorScheme.surface : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected 
                        ? theme.colorScheme.primary.withValues(alpha: 0.5) 
                        : (focused ? theme.colorScheme.primary.withValues(alpha: 0.3) : Colors.transparent),
                  ),
                ),
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected || focused ? Colors.white : theme.hintColor,
                    fontWeight: isSelected || focused ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}
