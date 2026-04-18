import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import '../../controllers/xtream_code_home_controller.dart';
import '../../services/player_state.dart' as app_player_state;
import '../../models/content_type.dart';
import '../../models/category_view_model.dart';
import '../../utils/get_playlist_type.dart';

class C4PlayerOverlay extends StatefulWidget {
  final Player player;
  final VideoController controller;

  final XtreamCodeHomeController? homeController;
  final VoidCallback? onFullscreenOverride;
  final bool isInline;

  const C4PlayerOverlay({
    super.key,
    required this.player,
    required this.controller,
    this.homeController,
    this.onFullscreenOverride,
    this.isInline = false,
  });

  @override
  State<C4PlayerOverlay> createState() => _C4PlayerOverlayState();
}

enum _SidePanelMode { channels, categories }

class _C4PlayerOverlayState extends State<C4PlayerOverlay> {
  bool _isVisible = true;
  bool _showSidePanel = false;
  bool _showInfoPanel = false;
  _SidePanelMode _sidePanelMode = _SidePanelMode.channels;
  
  // Fullscreen state
  bool _isFullscreen = false;
  bool _isTogglingFullscreen = false;
  
  // Stream metadata state
  int? _resW;
  int? _resH;
  double? _fps;
  int? _bitrate;
  String? _codec;
  
  Timer? _hideTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _isMuted = false;
  late List<StreamSubscription> _subscriptions;

  @override
  void initState() {
    super.initState();
    _volume = widget.player.state.volume / 100.0;
    _isMuted = widget.player.state.volume == 0;
    _startHideTimer();
    _subscriptions = [
      widget.player.stream.position.listen((p) => setState(() => _position = p)),
      widget.player.stream.duration.listen((d) => setState(() => _duration = d)),
      widget.player.stream.volume.listen((v) => setState(() {
        _volume = v / 100.0;
        _isMuted = v == 0;
      })),
      widget.player.stream.videoParams.listen((vp) => setState(() {
        _resW = vp.w ?? _resW;
        _resH = vp.h ?? _resH;
      })),
      widget.player.stream.track.listen((track) => setState(() {
        final video = track.video;
        _resW = video.w != null && video.w! > 0 ? video.w : _resW;
        _resH = video.h != null && video.h! > 0 ? video.h : _resH;
        _fps = video.fps != null && video.fps! > 0 ? video.fps : _fps;
        _bitrate = video.bitrate != null && video.bitrate! > 0 ? video.bitrate : _bitrate;
        _codec = video.codec ?? _codec;
      })),
      widget.player.stream.track.listen((track) {
        if (mounted) {
          setState(() {
            app_player_state.PlayerState.subtitles = widget.player.state.tracks.subtitle;
            app_player_state.PlayerState.selectedSubtitle = widget.player.state.track.subtitle;
          });
        }
      }),
    ];
    
    // Initial check for fullscreen
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      windowManager.isFullScreen().then((value) {
        if (mounted) setState(() => _isFullscreen = value);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_showSidePanel || _showInfoPanel) return;
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _isVisible = false);
    });
  }

  void _toggleVisibility() {
    setState(() {
      _isVisible = !_isVisible;
      if (_isVisible) _startHideTimer();
    });
  }

  void _showOverlay() {
    setState(() {
      _isVisible = true;
      _startHideTimer();
    });
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return "${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
    }
    return "${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // First press simply reveals overlay
    if (!_isVisible) {
      _showOverlay();
      return;
    }

    _startHideTimer();

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.pageUp) {
      _adjustVolume(0.05);
    } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.pageDown) {
      _adjustVolume(-0.05);
    } else if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.backspace) {
      if (_showSidePanel) {
        setState(() => _showSidePanel = false);
      } else if (_showInfoPanel) {
        setState(() => _showInfoPanel = false);
      } else if (!widget.isInline) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _toggleFullscreen() async {
    // If an override is provided (e.g. inline Live TV player),
    // delegate to the caller instead of toggling OS fullscreen.
    if (widget.onFullscreenOverride != null) {
      widget.onFullscreenOverride!();
      return;
    }

    if (_isTogglingFullscreen) return;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _isTogglingFullscreen = true;
      try {
        final isFull = await windowManager.isFullScreen();
        await windowManager.setFullScreen(!isFull);
        if (mounted) setState(() => _isFullscreen = !isFull);
      } finally {
        _isTogglingFullscreen = false;
      }
    }
  }

  void _openSubtitleSelector() {
    _startHideTimer();
    final theme = Theme.of(context);
    final subs = app_player_state.PlayerState.subtitles;
    final selected = app_player_state.PlayerState.selectedSubtitle;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Subtitle Selection',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                   _buildSubtitleTile('Auto', SubtitleTrack.auto(), selected, theme),
                   _buildSubtitleTile('Off', SubtitleTrack.no(), selected, theme),
                   ...subs.map((track) => _buildSubtitleTile(
                     '${track.language ?? "Unknown"} ${track.title ?? ""}'.trim(), 
                     track, 
                     selected, 
                     theme
                   )),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleTile(String title, SubtitleTrack track, SubtitleTrack selected, ThemeData theme) {
    final isSelected = selected == track;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: isSelected ? theme.colorScheme.primary : Colors.white24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        widget.player.setSubtitleTrack(track);
        Navigator.pop(context);
      },
    );
  }

  ContentType? _currentContentType() {
    final queue = app_player_state.PlayerState.queue;
    if (queue == null || queue.isEmpty) return null;
    return queue.first.contentType;
  }

  void _adjustVolume(double delta) {
    double newVol = (_volume + delta).clamp(0.0, 1.0);
    widget.player.setVolume(newVol * 100);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = _duration.inSeconds == 0;
    final videoTrack = widget.player.state.track.video;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: _toggleVisibility,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Overlay Content
            AnimatedOpacity(
              opacity: _isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_isVisible,
                child: Stack(
                  children: [
                    // Top Bar
                    _buildTopBar(theme),

                    // Bottom Bar
                    _buildBottomBar(theme, isLive),

                    // Info Panel (Metadata overlay)
                    if (_showInfoPanel) _buildInfoPanel(theme, videoTrack),
                  ],
                ),
              ),
            ),

            // Side Panel (Always accessible if visible, or can trigger visibility)
            if (_showSidePanel) _buildSidePanel(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 120,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            if (!widget.isInline)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            if (!widget.isInline) const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    app_player_state.PlayerState.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isXtreamCode)
                    Text(
                      'Live TV Stream',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                _showInfoPanel ? Icons.info_rounded : Icons.info_outline_rounded,
                color: _showInfoPanel ? theme.colorScheme.primary : Colors.white,
              ),
              onPressed: () => setState(() {
                _showInfoPanel = !_showInfoPanel;
                _showSidePanel = false;
                _startHideTimer();
              }),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(
                _showSidePanel ? Icons.menu_open_rounded : Icons.menu_rounded,
                color: _showSidePanel ? theme.colorScheme.primary : Colors.white,
              ),
              onPressed: () => setState(() {
                _showSidePanel = !_showSidePanel;
                _showInfoPanel = false;
                _startHideTimer();
              }),
            ),
            IconButton(
              icon: Icon(
                Icons.subtitles_rounded,
                color: app_player_state.PlayerState.selectedSubtitle == SubtitleTrack.no() 
                    ? Colors.white 
                    : theme.colorScheme.primary,
              ),
              onPressed: _openSubtitleSelector,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                color: Colors.white,
              ),
              onPressed: _toggleFullscreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, bool isLive) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(60, 40, 60, 60),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress Slider
            if (!isLive) ...[
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: theme.colorScheme.primary,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: theme.colorScheme.primary,
                  overlayColor: theme.colorScheme.primary.withOpacity(0.2),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _position.inSeconds.toDouble(),
                  max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                  onChanged: (val) => widget.player.seek(Duration(seconds: val.toInt())),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(_position), style: const TextStyle(color: Colors.white70)),
                  Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ] else 
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.circle, color: Colors.red, size: 10),
                  SizedBox(width: 8),
                  Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            
            const SizedBox(height: 24),
            
            // Bottom Controls Row
            Row(
              children: [
                _PlayerControlBtn(
                  icon: widget.player.state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  isLarge: true,
                  onPressed: () => widget.player.playOrPause(),
                ),
                const SizedBox(width: 32),
                
                // Volume Controls
                Icon(
                  _isMuted || _volume == 0 ? Icons.volume_off_rounded : 
                  _volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
                SizedBox(
                  width: 150,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: Colors.white,
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: _volume,
                      onChanged: (val) => widget.player.setVolume(val * 100),
                    ),
                  ),
                ),
                const Spacer(),
                
                if (!isLive) ...[
                   _PlayerControlBtn(
                    icon: Icons.replay_10_rounded,
                    onPressed: () => widget.player.seek(_position - const Duration(seconds: 10)),
                  ),
                  const SizedBox(width: 16),
                  _PlayerControlBtn(
                    icon: Icons.forward_10_rounded,
                    onPressed: () => widget.player.seek(_position + const Duration(seconds: 10)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel(ThemeData theme, VideoTrack track) {
    return Positioned(
      top: 130,
      right: 40,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stream Information',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Title', value: app_player_state.PlayerState.title),
            _InfoRow(
              label: 'Resolution', 
              value: (_resW != null && _resH != null && _resW! > 0) ? '$_resW x $_resH' : 'N/A'
            ),
            _InfoRow(label: 'FPS', value: _fps != null ? _fps!.toStringAsFixed(2) : 'N/A'),
            _InfoRow(
              label: 'Bitrate', 
              value: _bitrate != null ? '${(_bitrate! / 1000).toStringAsFixed(0)} kbps' : 'N/A'
            ),
            _InfoRow(label: 'Codec', value: (_codec != null && _codec!.isNotEmpty) ? _codec! : 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildSidePanel(ThemeData theme) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 350,
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withOpacity(0.95),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _sidePanelMode == _SidePanelMode.channels ? 'Channel List' : 'Categories',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _showSidePanel = false),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _sidePanelMode == _SidePanelMode.channels 
                  ? _buildChannelListView(theme) 
                  : _buildCategoryListView(theme, widget.homeController),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      if (_sidePanelMode == _SidePanelMode.channels) {
                        if (widget.homeController != null) {
                          _sidePanelMode = _SidePanelMode.categories;
                        }
                      } else {
                        _sidePanelMode = _SidePanelMode.channels;
                      }
                    });
                  },
                  icon: Icon(_sidePanelMode == _SidePanelMode.channels 
                      ? Icons.explore_outlined 
                      : Icons.arrow_back_rounded),
                  label: Text(_sidePanelMode == _SidePanelMode.channels 
                      ? (widget.homeController != null ? 'Discover other categories' : 'Categories not available')
                      : 'Back to channel list'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white10),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelListView(ThemeData theme) {
    final channels = app_player_state.PlayerState.queue ?? [];
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final isPlaying = app_player_state.PlayerState.currentIndex == index;
        
        return ListTile(
          selected: isPlaying,
          selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white10,
            ),
            child: channel.imageUrl.isNotEmpty
                ? Image.network(
                    channel.imageUrl,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.live_tv, size: 20, color: Colors.white24),
                  )
                : const Icon(Icons.live_tv, size: 20, color: Colors.white24),
          ),
          title: Text(
            channel.name,
            style: TextStyle(
              color: isPlaying ? theme.colorScheme.primary : Colors.white,
              fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            app_player_state.PlayerState.currentIndex = index;
            app_player_state.PlayerState.title = channel.name;
            widget.player.open(Media(channel.url));
            
            // Ensure overlay is visible while new stream loads
            setState(() {
              _showSidePanel = false;
              _isVisible = true;
            });
            _startHideTimer();
          },
        );
      },
    );
  }

  Widget _buildCategoryListView(ThemeData theme, XtreamCodeHomeController? homeController) {
    final categories = homeController == null ? <CategoryViewModel>[] : (() {
      final type = _currentContentType();
      if (type == ContentType.vod) return homeController.visibleMovieCategories;
      if (type == ContentType.series) return homeController.visibleSeriesCategories;
      return homeController.liveCategories ?? [];
    })();

    if (homeController == null || categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'Categories not available for this playlist',
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final categoryVM = categories[index];
        
        return ListTile(
          title: Text(
            categoryVM.category.categoryName,
            style: const TextStyle(color: Colors.white),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
          onTap: () {
            // Update the global queue with the selected category's channels
            app_player_state.PlayerState.queue = categoryVM.contentItems;
            app_player_state.PlayerState.currentIndex = 0; // Default to first channel
            
            // Switch back to channel view for the new category
            setState(() {
              _sidePanelMode = _SidePanelMode.channels;
              _isVisible = true;
            });
            _startHideTimer();
          },
        );
      },
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _PlayerControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLarge;

  const _PlayerControlBtn({
    required this.icon,
    required this.onPressed,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Focus(
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isLarge ? 64 : 48,
              height: isLarge ? 64 : 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: focused ? theme.colorScheme.primary : Colors.white10,
                boxShadow: focused ? [
                  BoxShadow(color: theme.colorScheme.primary.withOpacity(0.5), blurRadius: 15, spreadRadius: 1)
                ] : [],
              ),
              child: Icon(
                icon,
                color: focused ? Colors.white : Colors.white70,
                size: isLarge ? 40 : 24,
              ),
            ),
          );
        }
      ),
    );
  }
}
