import 'package:flutter/material.dart';
import '../../services/fullscreen_notifier.dart';

class MobileShellScreen extends StatefulWidget {
  final Widget child;
  final int selectedIndex;          // 0=Home, 1=Live, 2=Movies, 3=Series
  final ValueChanged<int> onItemSelected;
  final String currentTitle;
  final VoidCallback? onSearchTap;
  final VoidCallback onFavoritesTap;
  final VoidCallback onWatchLaterTap;
  final VoidCallback onSettingsTap;

  const MobileShellScreen({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.currentTitle,
    required this.onFavoritesTap,
    required this.onWatchLaterTap,
    required this.onSettingsTap,
    this.onSearchTap,
  });

  @override
  State<MobileShellScreen> createState() => _MobileShellScreenState();
}

class _MobileShellScreenState extends State<MobileShellScreen> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: fullscreenNotifier,
      builder: (context, isFullscreen, _) {
        return Scaffold(
          appBar: isFullscreen
              ? null
              : AppBar(
                  // TOP LEFT: Favorites + Watch Later
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Favorites',
                        icon: const Icon(Icons.favorite_outline),
                        onPressed: widget.onFavoritesTap,
                      ),
                      IconButton(
                        tooltip: 'Watch Later',
                        icon: const Icon(Icons.schedule_rounded),
                        onPressed: widget.onWatchLaterTap,
                      ),
                    ],
                  ),
                  leadingWidth: 96, // enough for two icon buttons (2 × 48dp)
                  // TOP CENTER: page title
                  title: Text(
                    widget.currentTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                  centerTitle: true,
                  // TOP RIGHT: Search (conditional) + Settings
                  actions: [
                    if (widget.onSearchTap != null)
                      IconButton(
                        tooltip: 'Search',
                        icon: const Icon(Icons.search),
                        onPressed: widget.onSearchTap,
                      ),
                    IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: widget.onSettingsTap,
                    ),
                  ],
                ),
          body: SafeArea(child: widget.child),
          // BOTTOM BAR: only the 4 main navigation tabs
          bottomNavigationBar: isFullscreen
              ? null
              : NavigationBar(
                  selectedIndex: widget.selectedIndex,
                  onDestinationSelected: widget.onItemSelected,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.live_tv_outlined),
                      selectedIcon: Icon(Icons.live_tv),
                      label: 'Live',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.movie_outlined),
                      selectedIcon: Icon(Icons.movie),
                      label: 'Movies',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.tv_outlined),
                      selectedIcon: Icon(Icons.tv),
                      label: 'Series',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
