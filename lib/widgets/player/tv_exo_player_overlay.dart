import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';

/// TV-specific overlay for the ExoPlayer (native Android) path.
/// Renders on top of [TvExoPlayerScreen] and is responsible for:
///   - Channels / Episodes side panel with queue navigation
///   - Subtitle toggle (passed back via [onSubtitleToggle])
///   - Info tab showing Resolution, Codec, FPS from [videoStats]
class TvExoPlayerOverlay extends StatefulWidget {
  final String title;
  final ContentType? contentType;
  final VoidCallback onExit;

  /// Full queue for the Channels / Episodes list.
  final List<ContentItem> queue;

  /// Index of the currently playing item inside [queue].
  final int currentIndex;

  /// Called when the user picks a different item from the side panel.
  final ValueChanged<int> onIndexChanged;

  /// Called when the user toggles subtitles. [true] = subtitles on.
  final ValueChanged<bool>? onSubtitleToggle;

  /// Video metadata from [VideoStatsPlugin] (keys: width, height, codec, frameRate).
  final Map<String, dynamic>? videoStats;

  /// Whether subtitles are currently enabled (drives the icon state).
  final bool subtitlesEnabled;

  const TvExoPlayerOverlay({
    super.key,
    required this.title,
    required this.onExit,
    required this.queue,
    required this.currentIndex,
    required this.onIndexChanged,
    this.contentType,
    this.onSubtitleToggle,
    this.videoStats,
    this.subtitlesEnabled = true,
  });

  @override
  State<TvExoPlayerOverlay> createState() => _TvExoPlayerOverlayState();
}

class _TvExoPlayerOverlayState extends State<TvExoPlayerOverlay> {
  bool _overlayVisible = true;
  bool _sidePanelOpen = false;
  int _activeTab = 0; // 0 = Info, 1 = Channels, 2 = Episodes
  Timer? _hideTimer;

  // Focus nodes for the tab row
  final List<FocusNode> _tabNodes = List.generate(3, (_) => FocusNode());
  // Focus node for subtitle toggle button
  final FocusNode _subtitleFocusNode = FocusNode();
  // Focus node for side panel toggle
  final FocusNode _sidePanelFocusNode = FocusNode();
  // Focus node for exit button
  final FocusNode _exitFocusNode = FocusNode();
  // Focus node for list items
  final ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    for (final n in _tabNodes) {
      n.dispose();
    }
    _subtitleFocusNode.dispose();
    _sidePanelFocusNode.dispose();
    _exitFocusNode.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_sidePanelOpen) return;
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _overlayVisible = false);
    });
  }

  void _showOverlay() {
    setState(() => _overlayVisible = true);
    _startHideTimer();
  }

  void _toggleSidePanel() {
    setState(() {
      _sidePanelOpen = !_sidePanelOpen;
      _overlayVisible = true;
    });
    if (!_sidePanelOpen) _startHideTimer();
  }

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showOverlay,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // ── Overlay controls ──────────────────────────────
          AnimatedOpacity(
            opacity: _overlayVisible ? 1.0 : 0.0,
            duration: _overlayVisible
                ? const Duration(milliseconds: 60)
                : const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_overlayVisible,
              child: Stack(children: [_buildTopBar(), _buildBottomBar()]),
            ),
          ),

          // ── Side panel ────────────────────────────────────
          if (_sidePanelOpen) _buildSidePanel(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Top bar
  // ─────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            // Back / exit
            Focus(
              focusNode: _exitFocusNode,
              child: IconButton(
                onPressed: widget.onExit,
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
                iconSize: 28,
                tooltip: 'Exit',
              ),
            ),
            const SizedBox(width: 16),
            // Title
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Subtitle toggle
            Focus(
              focusNode: _subtitleFocusNode,
              child: IconButton(
                onPressed: () {
                  final next = !widget.subtitlesEnabled;
                  widget.onSubtitleToggle?.call(next);
                  _startHideTimer();
                },
                icon: Icon(
                  widget.subtitlesEnabled
                      ? Icons.subtitles_rounded
                      : Icons.subtitles_off_rounded,
                  color: widget.subtitlesEnabled
                      ? const Color(0xFF4F98A3)
                      : Colors.white54,
                ),
                iconSize: 26,
                tooltip: widget.subtitlesEnabled
                    ? 'Disable subtitles'
                    : 'Enable subtitles',
              ),
            ),
            const SizedBox(width: 4),
            // Side panel toggle
            Focus(
              focusNode: _sidePanelFocusNode,
              child: IconButton(
                onPressed: _toggleSidePanel,
                icon: Icon(
                  _sidePanelOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
                  color: _sidePanelOpen
                      ? const Color(0xFF4F98A3)
                      : Colors.white,
                ),
                iconSize: 26,
                tooltip: 'Side panel',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Bottom bar (Live badge)
  // ─────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final isLive = widget.contentType == ContentType.liveStream;
    if (!isLive) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Icon(Icons.circle, color: Colors.red, size: 10),
            SizedBox(width: 6),
            Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Side panel
  // ─────────────────────────────────────────────────────────

  Widget _buildSidePanel() {
    final isEpisode = widget.contentType == ContentType.series;

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      child: Container(
        width: 340,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.92),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        ),
        child: Column(
          children: [
            // ── Panel header ──────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 40, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Player',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleSidePanel,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab row ───────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _TabButton(
                    label: 'Info',
                    isSelected: _activeTab == 0,
                    focusNode: _tabNodes[0],
                    onPressed: () => setState(() => _activeTab = 0),
                  ),
                  _TabButton(
                    label: isEpisode ? 'Episodes' : 'Channels',
                    isSelected: _activeTab == 1,
                    focusNode: _tabNodes[1],
                    onPressed: () => setState(() => _activeTab = 1),
                  ),
                  if (isEpisode)
                    _TabButton(
                      label: 'Seasons',
                      isSelected: _activeTab == 2,
                      focusNode: _tabNodes[2],
                      onPressed: () => setState(() => _activeTab = 2),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            const Divider(color: Colors.white10, height: 1),

            // ── Tab content ───────────────────────────────
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: [
                  _buildInfoTab(),
                  _buildListTab(
                    isEpisode ? 'Episodes' : 'Channels',
                    widget.queue,
                  ),
                  if (isEpisode)
                    _buildListTab('Seasons', widget.queue)
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Info tab
  // ─────────────────────────────────────────────────────────

  Widget _buildInfoTab() {
    final stats = widget.videoStats;
    final contentTypeLabel = () {
      switch (widget.contentType) {
        case ContentType.liveStream:
          return 'Live Stream';
        case ContentType.vod:
          return 'Movie (VOD)';
        case ContentType.series:
          return 'Series';
        default:
          return 'Unknown';
      }
    }();

    String resolutionLabel = 'Detecting…';
    String codecLabel = 'Detecting…';
    String fpsLabel = 'Detecting…';

    if (stats != null) {
      final w = stats['width'] as int? ?? 0;
      final h = stats['height'] as int? ?? 0;
      final codec = (stats['codec'] as String? ?? '')
          .replaceFirst('video/', '')
          .toUpperCase();
      final fps = (stats['frameRate'] as num? ?? 0).toDouble();

      resolutionLabel = (w > 0 && h > 0) ? '$w × $h' : 'N/A';
      codecLabel = codec.isNotEmpty ? codec : 'N/A';
      fpsLabel = fps > 0 ? fps.toStringAsFixed(1) : 'Unknown';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Title', value: widget.title),
          _InfoRow(label: 'Type', value: contentTypeLabel),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          const Text(
            'Stream Info',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Resolution', value: resolutionLabel),
          _InfoRow(label: 'Codec', value: codecLabel),
          _InfoRow(label: 'FPS', value: fpsLabel),
          _InfoRow(label: 'Engine', value: 'ExoPlayer (Media3)'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Channel / Episode list tab
  // ─────────────────────────────────────────────────────────

  Widget _buildListTab(String type, List<ContentItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No $type available',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Scroll to the current item once after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listScrollController.hasClients) {
        const itemH = 60.0;
        final offset = (widget.currentIndex * itemH - 100).clamp(
          0.0,
          double.infinity,
        );
        _listScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _listScrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemExtent: 60,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isActive = index == widget.currentIndex;

        return _ChannelListTile(
          item: item,
          isActive: isActive,
          onTap: () {
            widget.onIndexChanged(index);
            _toggleSidePanel();
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onPressed;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.focusNode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Focus(
        focusNode: focusNode,
        child: GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4F98A3) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelListTile extends StatefulWidget {
  final ContentItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _ChannelListTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ChannelListTile> createState() => _ChannelListTileState();
}

class _ChannelListTileState extends State<_ChannelListTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF4F98A3);
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? accent.withValues(alpha: 0.18)
                : _focused
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isActive
                  ? accent.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: widget.item.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.item.imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.live_tv_rounded,
                            size: 18,
                            color: Colors.white24,
                          ),
                        )
                      : const Icon(
                          Icons.live_tv_rounded,
                          size: 18,
                          color: Colors.white24,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Name
              Expanded(
                child: Text(
                  widget.item.name,
                  style: TextStyle(
                    color: widget.isActive ? accent : Colors.white,
                    fontSize: 13,
                    fontWeight: widget.isActive
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Playing indicator
              if (widget.isActive)
                const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFF4F98A3),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
