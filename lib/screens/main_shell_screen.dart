import 'package:flutter/material.dart';
import '../services/fullscreen_notifier.dart';
import '../widgets/common/c4_rail.dart';
import '../widgets/common/c4_header.dart';

class MainShellScreen extends StatefulWidget {
  final Widget child;
  final String currentTitle;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback? onSearchTap;

  const MainShellScreen({
    super.key,
    required this.child,
    required this.currentTitle,
    required this.selectedIndex,
    required this.onItemSelected,
    this.onSearchTap,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final FocusNode _railFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();

  @override
  void dispose() {
    _railFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: fullscreenNotifier,
      builder: (context, isFullscreen, _) {
        return Scaffold(
          body: Row(
            children: [
              // Sidebar - Keep in tree but hide via Offstage to preserve child state
              Offstage(
                offstage: isFullscreen,
                child: FocusScope(
                  node: FocusScopeNode(),
                  child: C4Rail(
                    items: const [
                      C4RailItem(
                        icon: Icons.home_outlined,
                        label: 'Home',
                        route: '/home',
                      ),
                      C4RailItem(
                        icon: Icons.live_tv_outlined,
                        label: 'Live',
                        route: '/live',
                      ),
                      C4RailItem(
                        icon: Icons.movie_outlined,
                        label: 'Movies',
                        route: '/movies',
                      ),
                      C4RailItem(
                        icon: Icons.tv_outlined,
                        label: 'Series',
                        route: '/series',
                      ),
                      C4RailItem(
                        icon: Icons.favorite_outline,
                        label: 'Favorites',
                        route: '/favorites',
                      ),
                      C4RailItem(
                        icon: Icons.schedule_rounded,
                        label: 'Watch Later',
                        route: '/watch_later',
                      ),
                      C4RailItem(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        route: '/settings',
                      ),
                    ],
                    selectedIndex: widget.selectedIndex,
                    onItemSelected: widget.onItemSelected,
                  ),
                ),
              ),

              // Main Content
              Expanded(
                child: Column(
                  children: [
                    // Header
                    Offstage(
                      offstage: isFullscreen,
                      child: C4Header(
                        title: widget.currentTitle,
                        onSearchTap: widget.onSearchTap,
                      ),
                    ),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
