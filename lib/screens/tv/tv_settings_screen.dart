import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:focusable_control_builder/focusable_control_builder.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../../controllers/locale_provider.dart';
import '../../controllers/theme_provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../database/database.dart';
import '../../l10n/localization_extension.dart';
import '../../l10n/supported_languages.dart';
import '../../models/m3u_item.dart';
import '../../repositories/user_preferences.dart';
import '../../utils/app_config.dart';
import '../../services/app_state.dart';
import '../../services/player_state.dart';
import '../../services/playlist_service.dart';
import '../../services/service_locator.dart';
import '../../services/sync_applier.dart';
import '../../services/sync_service.dart';
import '../../services/upscale_service.dart';
import '../../utils/app_transitions.dart';
import '../../utils/get_playlist_type.dart';
import '../../utils/tv_utils.dart';
import '../playlist_screen.dart';
import '../settings/parental_controls_screen.dart';
import '../welcome_screen.dart';
import '../../services/parental_control_service.dart';
import '../../controllers/home_rails_controller.dart';
import '../m3u/m3u_data_loader_screen.dart';
import '../xtream-codes/xtream_code_data_loader_screen.dart';
import '../../utils/show_loading_dialog.dart';
import '../../services/m3u_parser.dart';

class TvSettingsScreen extends StatefulWidget {
  const TvSettingsScreen({super.key});

  @override
  State<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  int _selectedIndex = 0;
  final FocusScopeNode _leftScope = FocusScopeNode(debugLabel: 'settings-left', traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop);
  final FocusScopeNode _rightScope = FocusScopeNode(debugLabel: 'settings-right', traversalEdgeBehavior: TraversalEdgeBehavior.parentScope);
  
  final List<FocusNode> _sidebarNodes = List.generate(7, (i) => FocusNode(debugLabel: 'sidebar-$i'));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sidebarNodes[_selectedIndex].requestFocus();
    });
  }

  @override
  void dispose() {
    _leftScope.dispose();
    _rightScope.dispose();
    for (var node in _sidebarNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onCategorySelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: const Border(right: BorderSide(color: Colors.white10, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.settings, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        context.loc.settings,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: FocusScope(
                    node: _leftScope,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        return _TvSidebarTile(
                          index: index,
                          focusNode: _sidebarNodes[index],
                          isSelected: _selectedIndex == index,
                          onFocus: () => _onCategorySelected(index),
                          onRight: () => _rightScope.requestFocus(),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: FocusScope(
              node: _rightScope,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.goBack) {
                    _leftScope.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    final moved = node.focusInDirection(TraversalDirection.left);
                    if (!moved) {
                      _leftScope.requestFocus();
                      return KeyEventResult.handled;
                    }
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                child: _buildSelectedPanel(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPanel() {
    switch (_selectedIndex) {
      case 0: return const _TvGeneralPanel();
      case 1: return const _TvPlayerPanel();
      case 2: return const _TvSubtitlePanel();
      case 3: return const _TvCategoryPanel();
      case 4: return const _TvHomeLayoutPanel();
      case 5: return const _TvParentalPanel();
      case 6: return const _TvAccountPanel();
      default: return const Center(child: Text('Coming Soon'));
    }
  }
}

class _TvSidebarTile extends StatelessWidget {
  final int index;
  final FocusNode focusNode;
  final bool isSelected;
  final VoidCallback onFocus;
  final VoidCallback onRight;

  const _TvSidebarTile({
    required this.index,
    required this.focusNode,
    required this.isSelected,
    required this.onFocus,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = [
      context.loc.general_settings,
      context.loc.player_settings,
      context.loc.subtitle_settings,
      context.loc.categories,
      context.loc.home_customization,
      'Parental',
      'Account'
    ];
    final icons = [
      Icons.tune_rounded,
      Icons.play_circle_rounded,
      Icons.subtitles_rounded,
      Icons.category_rounded,
      Icons.dashboard_customize_rounded,
      Icons.family_restroom_rounded,
      Icons.manage_accounts_rounded,
    ];

    return Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) onFocus();
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select || 
              event.logicalKey == LogicalKeyboardKey.enter) {
            onRight();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            TvNavigation.requestRailFocus(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: FocusableControlBuilder(
        builder: (context, state) {
          final isFocused = state.isFocused;
          return Container(
            height: 52,
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isFocused ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFocused ? theme.colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icons[index],
                  size: 20,
                  color: isSelected ? Colors.white : (isFocused ? theme.colorScheme.primary : Colors.white70),
                ),
                const SizedBox(width: 12),
                Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 16,
                    color: isSelected ? Colors.white : (isFocused ? theme.colorScheme.primary : Colors.white70),
                    fontWeight: isSelected || isFocused ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANELS
// ─────────────────────────────────────────────────────────────────────────────

class _TvGeneralPanel extends StatefulWidget {
  const _TvGeneralPanel();
  @override
  State<_TvGeneralPanel> createState() => _TvGeneralPanelState();
}

class _TvGeneralPanelState extends State<_TvGeneralPanel> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = info.version);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _TvPanelScaffold(
      title: context.loc.general_settings,
      children: [
        _TvSectionTitle(title: 'Account'),
        _TvTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Icon(
              SyncService.instance.isLoggedIn ? Icons.account_circle_rounded : Icons.person_outline_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          title: SyncService.instance.isLoggedIn ? 'Account & Sync' : 'Sign In / Register',
          subtitle: SyncService.instance.isLoggedIn ? 'Manage your account and cloud sync' : 'Connect to your sync server',
          onTap: () {
             final state = context.findAncestorStateOfType<_TvSettingsScreenState>();
             state?._onCategorySelected(6);
          },
        ),

        _TvSectionTitle(title: 'Playlist'),
        _TvTile(
          leading: const Icon(Icons.home),
          title: context.loc.playlist_list,
          onTap: () async {
            await UserPreferences.removeLastPlaylist();
            if (!context.mounted) return;
            Navigator.pushReplacement(context, fadeRoute(builder: (c) => const PlaylistScreen()));
          },
        ),

        _TvSectionTitle(title: context.loc.general_settings),
        _TvPickerTile<Locale>(
          icon: Icons.language,
          label: context.loc.app_language,
          value: Localizations.localeOf(context),
          items: supportedLanguages.map((l) => MapEntry(Locale(l['code']), l['name'] as String)).toList(),
          onChanged: (v) => context.read<LocaleProvider>().setLocale(v),
        ),
        _TvPickerTile<String>(
          icon: Icons.color_lens_outlined,
          label: context.loc.theme,
          value: context.watch<ThemeProvider>().themeName,
          items: [
            MapEntry('light', context.loc.light),
            MapEntry('dark', context.loc.dark),
            const MapEntry('skyBlue', 'Sky Blue'),
            const MapEntry('crimson', 'Crimson'),
          ],
          onChanged: (v) => context.read<ThemeProvider>().setTheme(v),
        ),
        _TvTile(
          leading: const Icon(Icons.refresh),
          title: context.loc.refresh_contents,
          onTap: () => _refreshContents(context),
        ),
        if (isXtreamCode)
          _TvTile(
            leading: const Icon(Icons.subtitles_outlined),
            title: context.loc.hide_category,
            onTap: () {
               // Navigate to the Categories tab in settings sidebar
               final state = context.findAncestorStateOfType<_TvSettingsScreenState>();
               if (state != null) {
                 state._onCategorySelected(3);
                 state._sidebarNodes[3].requestFocus();
               }
            },
          ),

        _TvSectionTitle(title: 'TMDB'),
        _TvTile(
          leading: const Icon(Icons.api_rounded),
          title: 'TMDB API Key',
          subtitle: AppConfig.tmdbApiKey.isNotEmpty 
              ? '${AppConfig.tmdbApiKey.substring(0, 4)}••••••••' 
              : 'Not set — tap to enter',
          onTap: () => _showTmdbKeyDialog(context),
        ),

        _TvSectionTitle(title: 'Home Screen'),
        _TvTile(
          leading: const Icon(Icons.dashboard_customize_rounded),
          title: 'Customize Home Layout',
          subtitle: 'Show/hide and reorder home screen rows',
          onTap: () {
            final state = context.findAncestorStateOfType<_TvSettingsScreenState>();
            if (state != null) {
              state._onCategorySelected(4);
              state._sidebarNodes[4].requestFocus();
            }
          },
        ),

        _TvSectionTitle(title: 'About'),
        _TvTile(
          leading: const Icon(Icons.info_outline),
          title: context.loc.app_version,
          subtitle: _appVersion.isNotEmpty ? _appVersion : '...',
        ),
        _TvTile(
          leading: const Icon(Icons.code),
          title: context.loc.support_on_github,
          onTap: () async {
            final url = Uri.parse('https://github.com/bsogulcan/another-iptv-player');
            if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
          },
        ),
      ],
    );
  }

  void _showTmdbKeyDialog(BuildContext context) {
    final controller = TextEditingController(text: AppConfig.tmdbApiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text('TMDB API Key', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your TMDB API key to enable movie/series artwork and metadata.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. abc123def456...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                ),
                onSubmitted: (val) async {
                  await AppConfig.setTmdbApiKey(val.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
        actions: [
          FocusableControlBuilder(
            onPressed: () async {
              await AppConfig.setTmdbApiKey('');
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            builder: (c, s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: s.isFocused ? Colors.red.withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: s.isFocused ? Colors.red : Colors.transparent, width: 2),
              ),
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          ),
          FocusableControlBuilder(
            onPressed: () async {
              await AppConfig.setTmdbApiKey(controller.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            builder: (c, s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: s.isFocused ? Theme.of(context).primaryColor.withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: s.isFocused ? Theme.of(context).primaryColor : Colors.transparent, width: 2),
              ),
              child: Text('Save', style: TextStyle(color: s.isFocused ? Colors.white : Colors.white54)),
            ),
          ),
          FocusableControlBuilder(
            onPressed: () => Navigator.pop(ctx),
            builder: (c, s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: s.isFocused ? Colors.white12 : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: s.isFocused ? Colors.white24 : Colors.transparent, width: 2),
              ),
              child: Text('Cancel', style: TextStyle(color: s.isFocused ? Colors.white : Colors.white54)),
            ),
          ),
        ],
      ),
    );
  }

  void _refreshContents(BuildContext context) async {
    if (isXtreamCode) {
      Navigator.pushReplacement(context, fadeRoute(builder: (c) => XtreamCodeDataLoaderScreen(playlist: AppState.currentPlaylist!, refreshAll: true)));
    } else if (isM3u) {
      _refreshM3u(context);
    }
  }

  Future<void> _refreshM3u(BuildContext context) async {
    final database = getIt<AppDatabase>();
    List<M3uItem> oldM3uItems = AppState.m3uItems ?? [];
    List<M3uItem> newM3uItems = [];

    if (AppState.currentPlaylist!.url!.startsWith('http')) {
      showLoadingDialog(context, context.loc.loading_m3u);
      final params = {'id': AppState.currentPlaylist!.id, 'url': AppState.currentPlaylist!.url!};
      newM3uItems = await compute(M3uParser.parseM3uUrl, params);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot refresh local M3U file without re-picking')));
      return;
    }

    newM3uItems = _updateM3UItemIdsByPosition(oldItems: oldM3uItems, newItems: newM3uItems);

    await database.deleteAllM3uItems(AppState.currentPlaylist!.id);
    if (!context.mounted) return;
    Navigator.pushReplacement(context, fadeRoute(builder: (c) => M3uDataLoaderScreen(playlist: AppState.currentPlaylist!, m3uItems: newM3uItems)));
  }

  List<M3uItem> _updateM3UItemIdsByPosition({required List<M3uItem> oldItems, required List<M3uItem> newItems}) {
    Map<String, List<MapEntry<int, String>>> groupedOldItems = {};
    for (int i = 0; i < oldItems.length; i++) {
      M3uItem item = oldItems[i];
      String key = "${item.url}|||${item.name}";
      groupedOldItems.putIfAbsent(key, () => []);
      groupedOldItems[key]!.add(MapEntry(i, item.id));
    }
    Map<String, int> groupUsageCounter = {};
    List<M3uItem> updatedItems = [];
    for (int i = 0; i < newItems.length; i++) {
      M3uItem newItem = newItems[i];
      String key = "${newItem.url}|||${newItem.name}";
      if (groupedOldItems.containsKey(key)) {
        List<MapEntry<int, String>> oldGroup = groupedOldItems[key]!;
        int usageCount = groupUsageCounter[key] ?? 0;
        if (usageCount < oldGroup.length) {
          String oldId = oldGroup[usageCount].value;
          updatedItems.add(newItem.copyWith(id: oldId));
          groupUsageCounter[key] = usageCount + 1;
        } else {
          updatedItems.add(newItem);
        }
      } else {
        updatedItems.add(newItem);
      }
    }
    return updatedItems;
  }
}

class _TvPlayerPanel extends StatefulWidget {
  const _TvPlayerPanel();
  @override
  State<_TvPlayerPanel> createState() => _TvPlayerPanelState();
}

class _TvPlayerPanelState extends State<_TvPlayerPanel> {
  bool _bgPlay = false;
  String _upscale = 'standard';
  bool _enhancement = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _bgPlay = await UserPreferences.getBackgroundPlay();
    _upscale = await UserPreferences.getUpscalePreset();
    _enhancement = await UserPreferences.getStreamEnhancement();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _TvPanelScaffold(
      title: context.loc.player_settings,
      children: [
        _TvSwitchTile(
          icon: Icons.play_circle_outline,
          title: context.loc.continue_on_background,
          subtitle: context.loc.continue_on_background_description,
          value: _bgPlay,
          onChanged: (v) async {
            await UserPreferences.setBackgroundPlay(v);
            setState(() => _bgPlay = v);
          },
        ),
        if (!Platform.isAndroid && availableUpscalePresets.isNotEmpty) ...[
          _TvSectionTitle(title: 'Video Upscaling'),
          for (var p in availableUpscalePresets)
            _TvRadioTile<String>(
              title: upscalePresetLabel(p),
              subtitle: upscalePresetDescription(p),
              value: p,
              groupValue: _upscale,
              onChanged: (v) async {
                await UserPreferences.setUpscalePreset(v);
                setState(() => _upscale = v);
                final player = PlayerState.activePlayer;
                if (player != null) await applyUpscalePreset(player, v);
              },
            ),
        ],
        if (isMpvSupported)
          _TvSwitchTile(
            icon: Icons.auto_fix_high_rounded,
            title: 'Stream Enhancement',
            subtitle: 'Reduces banding and compression blur.',
            value: _enhancement,
            onChanged: (v) async {
              await UserPreferences.setStreamEnhancement(v);
              setState(() => _enhancement = v);
              final player = PlayerState.activePlayer;
              if (player != null) await applyStreamEnhancement(player, v);
            },
          ),
      ],
    );
  }
}

class _TvSubtitlePanel extends StatefulWidget {
  const _TvSubtitlePanel();
  @override
  State<_TvSubtitlePanel> createState() => _TvSubtitlePanelState();
}

class _TvSubtitlePanelState extends State<_TvSubtitlePanel> {
  double _fontSize = 32.0;
  double _height = 1.4;
  double _letterSpacing = 0.0;
  double _wordSpacing = 0.0;
  double _padding = 24.0;
  String _fontWeight = 'normal';
  String _textAlign = 'center';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _fontSize = await UserPreferences.getSubtitleFontSize();
    _height = await UserPreferences.getSubtitleHeight();
    _letterSpacing = await UserPreferences.getSubtitleLetterSpacing();
    _wordSpacing = await UserPreferences.getSubtitleWordSpacing();
    _padding = await UserPreferences.getSubtitlePadding();
    final fw = await UserPreferences.getSubtitleFontWeight();
    _fontWeight = fw == FontWeight.w300 ? 'thin' : fw == FontWeight.w500 ? 'medium' : fw == FontWeight.bold ? 'bold' : fw == FontWeight.w900 ? 'extra' : 'normal';
    final ta = await UserPreferences.getSubtitleTextAlign();
    _textAlign = ta == TextAlign.left ? 'left' : ta == TextAlign.right ? 'right' : ta == TextAlign.justify ? 'justify' : 'center';
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    await UserPreferences.setSubtitleFontSize(_fontSize);
    await UserPreferences.setSubtitleHeight(_height);
    await UserPreferences.setSubtitleLetterSpacing(_letterSpacing);
    await UserPreferences.setSubtitleWordSpacing(_wordSpacing);
    await UserPreferences.setSubtitlePadding(_padding);
    final fw = _fontWeight == 'thin' ? FontWeight.w300 : _fontWeight == 'medium' ? FontWeight.w500 : _fontWeight == 'bold' ? FontWeight.bold : _fontWeight == 'extra' ? FontWeight.w900 : FontWeight.normal;
    await UserPreferences.setSubtitleFontWeight(fw);
    final ta = _textAlign == 'left' ? TextAlign.left : _textAlign == 'right' ? TextAlign.right : _textAlign == 'justify' ? TextAlign.justify : TextAlign.center;
    await UserPreferences.setSubtitleTextAlign(ta);
  }

  void _reset() {
    setState(() {
      _fontSize = 32.0; _height = 1.4; _letterSpacing = 0.0;
      _wordSpacing = 0.0; _padding = 24.0; _fontWeight = 'normal'; _textAlign = 'center';
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      children: [
        Row(
          children: [
            const Text('Subtitles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const Spacer(),
            FocusableControlBuilder(
              onPressed: _reset,
              builder: (c, s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: s.isFocused ? Colors.white12 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: s.isFocused ? Theme.of(context).primaryColor : Colors.white24),
                ),
                child: const Text('Reset', style: TextStyle(color: Colors.white70)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _TvSliderTile(icon: Icons.format_size, label: 'Font Size', value: _fontSize, min: 24, max: 96, divisions: 18,
          onChanged: (v) { setState(() => _fontSize = v); _save(); }),
        _TvSliderTile(icon: Icons.format_line_spacing, label: 'Line Height', value: _height, min: 1.0, max: 2.5, divisions: 15,
          onChanged: (v) { setState(() => _height = v); _save(); }),
        _TvSliderTile(icon: Icons.space_bar, label: 'Letter Spacing', value: _letterSpacing, min: -2.0, max: 5.0, divisions: 70,
          onChanged: (v) { setState(() => _letterSpacing = v); _save(); }),
        _TvSliderTile(icon: Icons.format_textdirection_l_to_r, label: 'Word Spacing', value: _wordSpacing, min: -2.0, max: 10.0, divisions: 120,
          onChanged: (v) { setState(() => _wordSpacing = v); _save(); }),
        _TvSliderTile(icon: Icons.padding, label: 'Padding', value: _padding, min: 8.0, max: 48.0, divisions: 40,
          onChanged: (v) { setState(() => _padding = v); _save(); }),
        _TvPickerTile<String>(icon: Icons.format_bold, label: 'Font Weight', value: _fontWeight,
          items: const [MapEntry('thin','Thin'), MapEntry('normal','Normal'), MapEntry('medium','Medium'), MapEntry('bold','Bold'), MapEntry('extra','Extra Bold')],
          onChanged: (v) { setState(() => _fontWeight = v); _save(); }),
        _TvPickerTile<String>(icon: Icons.format_align_center, label: 'Text Align', value: _textAlign,
          items: const [MapEntry('left','Left'), MapEntry('center','Center'), MapEntry('right','Right'), MapEntry('justify','Justify')],
          onChanged: (v) { setState(() => _textAlign = v); _save(); }),
      ],
    );
  }
}

class _TvCategoryPanel extends StatefulWidget {
  const _TvCategoryPanel();
  @override
  State<_TvCategoryPanel> createState() => _TvCategoryPanelState();
}

class _TvCategoryPanelState extends State<_TvCategoryPanel> {
  Set<String> _hidden = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await UserPreferences.getHiddenCategories();
    if (mounted) setState(() => _hidden = h.toSet());
  }

  Future<void> _toggle(String id, bool visible) async {
    setState(() { if (visible) { _hidden.remove(id); } else { _hidden.add(id); } });
    await UserPreferences.setHiddenCategories(_hidden.toList());
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<XtreamCodeHomeController?>(context) ?? XtreamCodeHomeController(false);
    final live = ctrl.liveCategories ?? [];
    final movies = ctrl.movieCategories;
    final series = ctrl.seriesCategories;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      children: [
        const Text('Categories', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text('Toggle categories on/off to show or hide them.', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 24),
        if (live.isNotEmpty) ...[
          _TvSectionTitle(title: 'Live'),
          for (var cat in live)
            _TvSwitchTile(icon: Icons.live_tv, title: cat.category.categoryName, subtitle: '',
              value: !_hidden.contains(cat.category.categoryId),
              onChanged: (v) => _toggle(cat.category.categoryId, v)),
        ],
        if (movies.isNotEmpty) ...[
          _TvSectionTitle(title: 'Movies'),
          for (var cat in movies)
            _TvSwitchTile(icon: Icons.movie, title: cat.category.categoryName, subtitle: '',
              value: !_hidden.contains(cat.category.categoryId),
              onChanged: (v) => _toggle(cat.category.categoryId, v)),
        ],
        if (series.isNotEmpty) ...[
          _TvSectionTitle(title: 'Series'),
          for (var cat in series)
            _TvSwitchTile(icon: Icons.tv, title: cat.category.categoryName, subtitle: '',
              value: !_hidden.contains(cat.category.categoryId),
              onChanged: (v) => _toggle(cat.category.categoryId, v)),
        ],
        if (live.isEmpty && movies.isEmpty && series.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No categories available.\nLoad an Xtream Codes playlist first.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 16)))),
      ],
    );
  }
}

class _TvHomeLayoutPanel extends StatefulWidget {
  const _TvHomeLayoutPanel();
  @override
  State<_TvHomeLayoutPanel> createState() => _TvHomeLayoutPanelState();
}

class _TvHomeLayoutPanelState extends State<_TvHomeLayoutPanel> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeRailsController>();
    final rails = controller.rails;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      children: [
        const Text('Home Layout', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text('Toggle home screen rows on or off. Use the Move Up/Down buttons to reorder.', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 24),
        for (int i = 0; i < rails.length; i++)
          _TvHomeRailTile(
            rail: rails[i],
            index: i,
            total: rails.length,
            onToggle: (v) => controller.toggleRail(rails[i].id, v),
            onMoveUp: i > 0 ? () {
              final updated = List.from(rails);
              final item = updated.removeAt(i);
              updated.insert(i - 1, item);
              controller.updateRails(updated.cast());
            } : null,
            onMoveDown: i < rails.length - 1 ? () {
              final updated = List.from(rails);
              final item = updated.removeAt(i);
              updated.insert(i + 1, item);
              controller.updateRails(updated.cast());
            } : null,
          ),
      ],
    );
  }
}

class _TvHomeRailTile extends StatelessWidget {
  final dynamic rail;
  final int index;
  final int total;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  const _TvHomeRailTile({required this.rail, required this.index, required this.total, required this.onToggle, this.onMoveUp, this.onMoveDown});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: FocusableControlBuilder(
              onPressed: () => onToggle(!rail.visible),
              builder: (c, s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: s.isFocused ? Theme.of(context).primaryColor : Colors.transparent, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(rail.visible ? Icons.visibility : Icons.visibility_off, color: rail.visible ? Colors.white70 : Colors.white24, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(rail.label, style: TextStyle(color: rail.visible ? Colors.white : Colors.white38, fontSize: 16))),
                    Switch(value: rail.visible, onChanged: onToggle),
                  ],
                ),
              ),
            ),
          ),
          if (onMoveUp != null)
            FocusableControlBuilder(
              onPressed: onMoveUp!,
              builder: (c, s) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: s.isFocused ? Colors.white12 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: s.isFocused ? Theme.of(context).primaryColor : Colors.transparent, width: 2),
                ),
                child: const Icon(Icons.arrow_upward, color: Colors.white54, size: 20),
              ),
            ),
          if (onMoveDown != null)
            FocusableControlBuilder(
              onPressed: onMoveDown!,
              builder: (c, s) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: s.isFocused ? Colors.white12 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: s.isFocused ? Theme.of(context).primaryColor : Colors.transparent, width: 2),
                ),
                child: const Icon(Icons.arrow_downward, color: Colors.white54, size: 20),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TvParentalPanel extends StatefulWidget {
  const _TvParentalPanel();
  @override
  State<_TvParentalPanel> createState() => _TvParentalPanelState();
}

class _TvParentalPanelState extends State<_TvParentalPanel> {
  final _service = ParentalControlService();
  bool _hasPin = false;
  bool _enabled = false;
  List<String> _keywords = [];
  bool _loaded = false;
  final _kwController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _kwController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _hasPin = await _service.hasPin();
    _enabled = await _service.isEnabled;
    _keywords = await _service.getKeywords();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _toggleEnabled(bool v) async {
    if (v && !_hasPin) {
      // Need to set up a PIN first - navigate to full screen
      await Navigator.push(context, fadeRoute(builder: (c) => const ParentalControlsScreen()));
      await _load();
      return;
    }
    await _service.setEnabled(v);
    await _load();
  }

  Future<void> _addKeyword() async {
    final kw = _kwController.text.trim();
    if (kw.isEmpty) return;
    await _service.addKeyword(kw);
    _kwController.clear();
    await _load();
  }

  Future<void> _removeKeyword(String kw) async {
    await _service.removeKeyword(kw);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      children: [
        const Text('Parental Controls', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text('Restrict content using a PIN and keyword filters.', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 24),
        _TvSwitchTile(icon: Icons.shield_rounded, title: 'Enable Parental Controls', subtitle: _hasPin ? 'PIN is set' : 'Set a PIN to enable', value: _enabled, onChanged: _toggleEnabled),
        _TvTile(leading: const Icon(Icons.pin_rounded, color: Colors.white70), title: 'PIN Code', subtitle: _hasPin ? '••••  (tap to manage)' : 'Not set',
          onTap: () async {
            await Navigator.push(context, fadeRoute(builder: (c) => const ParentalControlsScreen()));
            await _load();
          }),
        _TvSectionTitle(title: 'Keyword Filters'),
        for (var kw in _keywords)
          _TvTile(leading: const Icon(Icons.filter_alt_rounded, color: Colors.white70), title: kw,
            onTap: () => _removeKeyword(kw)),
        if (_keywords.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No keywords added yet. Use the full Parental Controls screen to manage keywords.', style: TextStyle(color: Colors.white38))),
        const SizedBox(height: 16),
        _TvTile(leading: const Icon(Icons.open_in_new, color: Colors.white70), title: 'Open Full Parental Controls',
          onTap: () async {
            await Navigator.push(context, fadeRoute(builder: (c) => const ParentalControlsScreen()));
            await _load();
          }),
      ],
    );
  }
}

class _TvAccountPanel extends StatefulWidget {
  const _TvAccountPanel();
  @override
  State<_TvAccountPanel> createState() => _TvAccountPanelState();
}

class _TvAccountPanelState extends State<_TvAccountPanel> {
  final _serverUrl = TextEditingController(text: 'http://');
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = SyncService.instance.isLoggedIn;
  Map<String, dynamic> _user = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _user = await UserPreferences.getSyncUser();
    final srv = await UserPreferences.getSyncServerUrl();
    if (srv != null) _serverUrl.text = srv;
    if (mounted) setState(() {});
  }

  Future<void> _login() async {
    if (_serverUrl.text.isEmpty || _email.text.isEmpty || _password.text.isEmpty) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      await SyncService.instance.login(_serverUrl.text.trim(), _email.text.trim(), _password.text);
      await SyncApplier.pullAndApply();
      _user = await UserPreferences.getSyncUser();
      setState(() { _isLoggedIn = true; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _pushAll() async {
     setState(() => _isLoading = true);
     try {
       final db = getIt<AppDatabase>();
       final playlists = await PlaylistService.getPlaylists();
       final playlistsJson = playlists.map((p) => p.toJson()).toList();
       final favorites = await db.getAllFavorites();
       final favoritesJson = favorites.map((f) => {
         'id': f.id, 'playlistId': f.playlistId, 'contentType': f.contentType.toString(),
         'streamId': f.streamId, 'episodeId': f.episodeId, 'name': f.name,
         'imagePath': f.imagePath, 'sortOrder': f.sortOrder,
       }).toList();
       final settings = await UserPreferences.buildSettingsSnapshot();
       
       await SyncService.instance.pushAll({
         'playlists': playlistsJson,
         'favorites': favoritesJson,
         'settings': settings,
       });
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync completed successfully')));
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out and clear all local data?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign Out', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final db = getIt<AppDatabase>();
      await db.deleteAllPlaylists();
      await db.deleteAllFavorites();
      await db.deleteAllWatchLater();
      await db.deleteAllWatchHistories();
      await UserPreferences.removeLastPlaylist();
      await AppConfig.setTmdbApiKey('');
      await UserPreferences.clearSyncedSettings();
      await UserPreferences.setHasSeenWelcome(false);
      await SyncService.instance.logout();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(fadeRoute(builder: (_) => const WelcomeScreen()), (_) => false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) return _buildProfile();
    return _buildLoginForm();
  }

  Widget _buildProfile() {
    final name = _user['display_name'] ?? _user['email'] ?? 'User';
    final email = _user['email'] ?? '';
    return _TvPanelScaffold(
      title: 'Account',
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 40, 
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(name.substring(0,1).toUpperCase(), style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(email, style: const TextStyle(fontSize: 16, color: Colors.white54)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 40),
        _TvTile(
          leading: const Icon(Icons.sync, color: Colors.blueAccent),
          title: 'Sync Now',
          subtitle: 'Push all local data to cloud',
          onTap: _isLoading ? null : _pushAll,
        ),
        _TvTile(
          leading: const Icon(Icons.download, color: Colors.greenAccent),
          title: 'Pull from Server',
          subtitle: 'Overwrite local data with cloud data',
          onTap: _isLoading ? null : () async {
            setState(() => _isLoading = true);
            await SyncApplier.pullAndApply();
            _user = await UserPreferences.getSyncUser();
            if (mounted) setState(() => _isLoading = false);
          },
        ),
        const Divider(height: 40, color: Colors.white12),
        _TvTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: 'Sign Out',
          subtitle: 'Log out and remove all local playlists',
          onTap: _isLoading ? null : _logout,
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return _TvPanelScaffold(
      title: 'Sign In',
      children: [
        const Text('Connect to your self-hosted sync server to keep your playlists and favorites in sync across devices.', style: TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 32),
        _TvTextField(controller: _serverUrl, label: 'Server URL', icon: Icons.dns, hint: 'http://your-server:7000'),
        const SizedBox(height: 16),
        _TvTextField(controller: _email, label: 'Email', icon: Icons.email, hint: 'you@example.com'),
        const SizedBox(height: 16),
        _TvTextField(controller: _password, label: 'Password', icon: Icons.lock, obscure: true),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FocusableControlBuilder(
            onPressed: _isLoading ? null : _login,
            builder: (context, state) => Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: state.isFocused ? Theme.of(context).primaryColor : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _isLoading 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                    : const Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TV COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _TvPanelScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _TvPanelScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _TvSectionTitle extends StatelessWidget {
  final String title;
  const _TvSectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, letterSpacing: 1.2)),
    );
  }
}

class _TvTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _TvTile({required this.leading, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          final moved = FocusScope.of(context).focusInDirection(TraversalDirection.left);
          if (!moved) {
             FocusScope.of(context).requestFocus(context.findAncestorStateOfType<_TvSettingsScreenState>()!._sidebarNodes[context.findAncestorStateOfType<_TvSettingsScreenState>()!._selectedIndex]);
             return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: FocusableControlBuilder(
        onPressed: onTap,
        builder: (context, state) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: state.isFocused ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: state.isFocused ? Theme.of(context).primaryColor : Colors.transparent, width: 2),
          ),
          child: ListTile(
            leading: leading,
            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(color: Colors.white54, fontSize: 14)) : null,
            trailing: onTap != null ? const Icon(Icons.chevron_right, color: Colors.white24) : null,
          ),
        );
      },
    ),
   );
  }
}

class _TvSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _TvSwitchTile({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          final moved = FocusScope.of(context).focusInDirection(TraversalDirection.left);
          if (!moved) {
             FocusScope.of(context).requestFocus(context.findAncestorStateOfType<_TvSettingsScreenState>()!._sidebarNodes[context.findAncestorStateOfType<_TvSettingsScreenState>()!._selectedIndex]);
             return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: FocusableControlBuilder(
        onPressed: () => onChanged(!value),
        builder: (context, state) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: state.isFocused ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: state.isFocused ? Theme.of(context).primaryColor : Colors.transparent, width: 2),
          ),
          child: SwitchListTile(
            secondary: Icon(icon, color: Colors.white70),
            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            value: value,
            onChanged: onChanged,
          ),
        );
      },
    ),
   );
  }
}

class _TvRadioTile<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;
  const _TvRadioTile({required this.title, required this.subtitle, required this.value, required this.groupValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          final moved = FocusScope.of(context).focusInDirection(TraversalDirection.left);
          if (!moved) {
             FocusScope.of(context).requestFocus(context.findAncestorStateOfType<_TvSettingsScreenState>()!._sidebarNodes[context.findAncestorStateOfType<_TvSettingsScreenState>()!._selectedIndex]);
             return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: FocusableControlBuilder(
        onPressed: () => onChanged(value),
        builder: (context, state) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: state.isFocused ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: state.isFocused ? Theme.of(context).primaryColor : Colors.transparent, width: 2),
          ),
          child: RadioListTile<T>(
            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            value: value,
            groupValue: groupValue,
            onChanged: (v) => onChanged(v as T),
          ),
        );
      },
    ),
   );
  }
}

class _TvTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final bool obscure;

  const _TvTextField({required this.controller, required this.label, required this.icon, this.hint, this.obscure = false});

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            // Only move to sidebar if cursor is at the beginning
            if (controller.selection.baseOffset <= 0) {
               FocusScope.of(context).requestFocus(context.findAncestorStateOfType<_TvSettingsScreenState>()!._sidebarNodes[context.findAncestorStateOfType<_TvSettingsScreenState>()!._selectedIndex]);
               return KeyEventResult.handled;
            }
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            FocusScope.of(context).focusInDirection(TraversalDirection.up);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            FocusScope.of(context).focusInDirection(TraversalDirection.down);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: FocusableControlBuilder(
        builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: state.isFocused ? Theme.of(context).primaryColor : Colors.transparent, width: 2),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: Icon(icon, color: Colors.white54),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              labelStyle: const TextStyle(color: Colors.white54),
              hintStyle: const TextStyle(color: Colors.white24),
            ),
          ),
        );
      },
     ),
    );
  }
}

class _TvPickerTile<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final T value;
  final List<MapEntry<T, String>> items;
  final ValueChanged<T> onChanged;

  const _TvPickerTile({required this.icon, required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final currentLabel = items.firstWhere((e) => e.key == value, orElse: () => items.first).value;
    return _TvTile(
      leading: Icon(icon, color: Colors.white70),
      title: label,
      subtitle: currentLabel,
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: const Color(0xFF1A1A1A),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (context) {
            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSelected = item.key == value;
                        return FocusableControlBuilder(
                          autoFocus: isSelected,
                          onPressed: () {
                            onChanged(item.key);
                            Navigator.pop(context);
                          },
                          builder: (context, state) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: state.isFocused ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                title: Text(item.value, style: TextStyle(color: isSelected ? Theme.of(context).primaryColor : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TvSliderTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  const _TvSliderTile({required this.icon, required this.label, required this.value, required this.min, required this.max, required this.divisions, required this.onChanged});

  @override
  State<_TvSliderTile> createState() => _TvSliderTileState();
}

class _TvSliderTileState extends State<_TvSliderTile> {
  late FocusNode _node;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node = FocusNode();
    _node.addListener(() {
      if (mounted) setState(() => _focused = _node.hasFocus);
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final step = (widget.max - widget.min) / widget.divisions;
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            final nv = (widget.value + step).clamp(widget.min, widget.max);
            widget.onChanged(nv);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            final nv = (widget.value - step).clamp(widget.min, widget.max);
            widget.onChanged(nv);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            node.focusInDirection(TraversalDirection.up);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            node.focusInDirection(TraversalDirection.down);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _focused ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _focused ? Theme.of(context).primaryColor : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            SizedBox(width: 130, child: Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 16))),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                ),
                child: Slider(
                  value: widget.value,
                  min: widget.min,
                  max: widget.max,
                  divisions: widget.divisions,
                  onChanged: widget.onChanged,
                ),
              ),
            ),
            SizedBox(width: 50, child: Text(widget.value.toStringAsFixed(1), style: const TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.right)),
          ],
        ),
      ),
    );
  }
}
