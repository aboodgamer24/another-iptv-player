import 'package:flutter/material.dart';

/// Desktop left sidebar navigation with collapsible support,
/// hover effects, and smooth transitions.
class DesktopSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final String? playlistName;

  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    this.playlistName,
  });

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  int? _hoveredIndex;
  late AnimationController _animController;
  late Animation<double> _widthAnim;

  static const double _expandedWidth = 220;
  static const double _collapsedWidth = 72;

  static const List<_NavItem> _items = [
    _NavItem(Icons.home_rounded, 'Home', 0),
    _NavItem(Icons.live_tv_rounded, 'Live TV', 1),
    _NavItem(Icons.movie_rounded, 'Movies', 2),
    _NavItem(Icons.tv_rounded, 'Series', 3),
    _NavItem(Icons.search_rounded, 'Search', 4),
    _NavItem(Icons.favorite_rounded, 'Favorites', 5),
    _NavItem(Icons.settings_rounded, 'Settings', 6),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _widthAnim = Tween<double>(
      begin: _expandedWidth,
      end: _collapsedWidth,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _animController.reverse();
    } else {
      _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _widthAnim,
      builder: (context, child) {
        final w = _widthAnim.value;
        return Container(
          width: w,
          decoration: const BoxDecoration(
            color: Color(0xFF0D1017),
            border: Border(
              right: BorderSide(color: Color(0xFF1E2128), width: 1),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Logo
              _buildLogo(w),
              const SizedBox(height: 24),
              const Divider(height: 1, color: Color(0xFF1E2128)),
              const SizedBox(height: 12),

              // Navigation items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: _items.map((item) {
                    return _buildNavItem(item, w);
                  }).toList(),
                ),
              ),

              // Collapse toggle
              const Divider(height: 1, color: Color(0xFF1E2128)),
              _buildCollapseButton(w),

              // Playlist name footer
              if (widget.playlistName != null && _isExpanded) ...[
                const Divider(height: 1, color: Color(0xFF1E2128)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF4ADE80),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.playlistName!,
                          style: const TextStyle(
                            color: Color(0xFF747B8B),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogo(double width) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onIndexChanged(0),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5A45FF), Color(0xFF00D1FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              'IP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, double width) {
    final isSelected = widget.selectedIndex == item.index;
    final isHovered = _hoveredIndex == item.index;
    final showLabel = _isExpanded;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = item.index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onIndexChanged(item.index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.symmetric(
            horizontal: _isExpanded ? 12 : 8,
            vertical: 2,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: _isExpanded ? 14 : 0,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2C52FF).withValues(alpha: 0.15)
                : (isHovered ? const Color(0xFF1E2128) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2C52FF).withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: showLabel
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 20,
                color: isSelected
                    ? Colors.white
                    : (isHovered
                          ? const Color(0xFFDCE0EA)
                          : const Color(0xFF747B8B)),
              ),
              if (showLabel) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isHovered
                                ? const Color(0xFFDCE0EA)
                                : const Color(0xFFA0A5B5)),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton(double width) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Icon(
            _isExpanded
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            color: const Color(0xFF747B8B),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int index;

  const _NavItem(this.icon, this.label, this.index);
}
