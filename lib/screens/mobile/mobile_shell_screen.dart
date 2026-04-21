import 'package:flutter/material.dart';
import '../../services/fullscreen_notifier.dart';

class MobileShellScreen extends StatefulWidget {
  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final String currentTitle;
  final VoidCallback? onSearchTap;

  const MobileShellScreen({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.currentTitle,
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
                  title: Text(widget.currentTitle),
                  centerTitle: false,
                  actions: [
                    if (widget.onSearchTap != null)
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: widget.onSearchTap,
                      ),
                  ],
                ),
          body: SafeArea(child: widget.child),
          bottomNavigationBar: isFullscreen
              ? null
              : NavigationBar(
                  selectedIndex: widget.selectedIndex,
                  onDestinationSelected: widget.onItemSelected,
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.home_outlined),      selectedIcon: Icon(Icons.home),       label: 'Home'),
                    NavigationDestination(icon: Icon(Icons.live_tv_outlined),    selectedIcon: Icon(Icons.live_tv),    label: 'Live'),
                    NavigationDestination(icon: Icon(Icons.movie_outlined),      selectedIcon: Icon(Icons.movie),      label: 'Movies'),
                    NavigationDestination(icon: Icon(Icons.tv_outlined),         selectedIcon: Icon(Icons.tv),         label: 'Series'),
                    NavigationDestination(icon: Icon(Icons.favorite_outline),    selectedIcon: Icon(Icons.favorite),   label: 'Favorites'),
                    NavigationDestination(icon: Icon(Icons.schedule_rounded),    selectedIcon: Icon(Icons.schedule),   label: 'Later'),
                    NavigationDestination(icon: Icon(Icons.settings_outlined),   selectedIcon: Icon(Icons.settings),   label: 'Settings'),
                  ],
                ),
        );
      },
    );
  }
}
