import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/screens/settings/subtitle_settings_section.dart';
import 'package:another_iptv_player/widgets/common/hover_scale_wrapper.dart';
import 'package:another_iptv_player/screens/settings/parental_controls_screen.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:another_iptv_player/utils/get_playlist_type.dart';
import 'package:another_iptv_player/utils/show_loading_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/locale_provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../controllers/theme_provider.dart';
import '../../l10n/supported_languages.dart';
import '../../models/m3u_item.dart';
import '../../repositories/user_preferences.dart';
import '../../services/app_state.dart';
import '../../services/m3u_parser.dart';
import '../../widgets/dropdown_tile_widget.dart';
import '../../widgets/section_title_widget.dart';
import '../m3u/m3u_data_loader_screen.dart';
import '../playlist_screen.dart';
import '../xtream-codes/xtream_code_data_loader_screen.dart';
import 'category_settings_section.dart';
import 'home_customization_section.dart';
import '../../utils/app_config.dart';
import '../../services/upscale_service.dart';
import '../../services/player_state.dart';
import '../../services/sync_service.dart';
import '../account/account_screen.dart';



class GeneralSettingsWidget extends StatefulWidget {
  const GeneralSettingsWidget({super.key});

  @override
  State<GeneralSettingsWidget> createState() => _GeneralSettingsWidgetState();
}

class _GeneralSettingsWidgetState extends State<GeneralSettingsWidget>
    with SingleTickerProviderStateMixin {
  final AppDatabase database = getIt<AppDatabase>();

  bool _backgroundPlayEnabled = false;
  bool _isLoading = true;
  String? _selectedFilePath;
  String _selectedTheme = 'system';
  bool _brightnessGesture = false;
  bool _volumeGesture = false;
  bool _seekGesture = false;
  bool _speedUpOnLongPress = true;
  bool _seekOnDoubleTap = true;
  String _appVersion = '';
  final TextEditingController _tmdbKeyController = TextEditingController();
  bool _obscureTmdbKey = true;
  String _upscalePreset = 'standard';
  bool _streamEnhancement = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final backgroundPlay = await UserPreferences.getBackgroundPlay();
      final themeName = await UserPreferences.getThemeName();
      final brightnessGesture = await UserPreferences.getBrightnessGesture();
      final volumeGesture = await UserPreferences.getVolumeGesture();
      final seekGesture = await UserPreferences.getSeekGesture();
      final speedUpOnLongPress = await UserPreferences.getSpeedUpOnLongPress();
      final seekOnDoubleTap = await UserPreferences.getSeekOnDoubleTap();
      final packageInfo = await PackageInfo.fromPlatform();
      final upscalePreset = await UserPreferences.getUpscalePreset();
      final streamEnhancement = await UserPreferences.getStreamEnhancement();
      setState(() {
        _backgroundPlayEnabled = backgroundPlay;
        _selectedTheme = themeName;
        _brightnessGesture = brightnessGesture;
        _volumeGesture = volumeGesture;
        _seekGesture = seekGesture;
        _speedUpOnLongPress = speedUpOnLongPress;
        _seekOnDoubleTap = seekOnDoubleTap;
        _appVersion = packageInfo.version;
        _tmdbKeyController.text = AppConfig.tmdbApiKey;
        _upscalePreset = upscalePreset;
        _streamEnhancement = streamEnhancement;
        _isLoading = false;
      });
      _fadeController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tmdbKeyController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _saveBackgroundPlaySetting(bool value) async {
    try {
      await UserPreferences.setBackgroundPlay(value);
      setState(() {
        _backgroundPlayEnabled = value;
      });
    } catch (e) {
      setState(() {
        _backgroundPlayEnabled = !value;
      });
    }
  }

  Widget _buildUpscalerSection(ThemeData theme) {
    final presets = availableUpscalePresets;
    // Hide entirely on unsupported platforms (iOS, web)
    if (presets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header — match the style of other section headers in this file
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Video Upscaling',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...presets.map((preset) => RadioListTile<String>(
          title: Text(upscalePresetLabel(preset)),
          subtitle: Text(
            upscalePresetDescription(preset),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          value: preset,
          groupValue: _upscalePreset,
          onChanged: (value) async {
            if (value == null) return;
            setState(() => _upscalePreset = value);
            await UserPreferences.setUpscalePreset(value);
            final player = PlayerState.activePlayer;
            if (player != null) {
              await applyUpscalePreset(player, value);
            }
          },
        )),
        const Divider(),
      ],
    );
  }

  Widget _buildStreamEnhancementSection(ThemeData theme) {
    // Only show on MPV-supported platforms
    if (!isMpvSupported) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Stream Enhancement'),
          subtitle: Text(
            'Reduces banding, blocking, and compression blur in IPTV streams. '
            'Most effective on SD and low-bitrate channels.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          value: _streamEnhancement,
          onChanged: (value) async {
            setState(() => _streamEnhancement = value);
            await UserPreferences.setStreamEnhancement(value);
            final player = PlayerState.activePlayer;
            if (player != null) {
              await applyStreamEnhancement(player, value);
            }
          },
        ),
        const Divider(),
      ],
    );
  }

  void _pushAnimated(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  Widget _buildPlaylistCard(BuildContext context) {
    return Card(
      child: HoverScaleWrapper(
        hoverScale: 1.02,
        child: ListTile(
          leading: const Icon(Icons.home),
          title: Text(context.loc.playlist_list),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await UserPreferences.removeLastPlaylist();
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => PlaylistScreen(),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildGeneralCard(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Card(
      child: Column(
        children: [
          HoverScaleWrapper(
            hoverScale: 1.02,
            child: ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(context.loc.refresh_contents),
              trailing: const Icon(Icons.cloud_download),
              onTap: () async {
                if (isXtreamCode) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => XtreamCodeDataLoaderScreen(
                        playlist: AppState.currentPlaylist!,
                        refreshAll: true,
                      ),
                    ),
                  );
                }

                if (isM3u) {
                  refreshM3uPlaylist();
                }
              },
            ),
          ),
          if (isXtreamCode) const Divider(height: 1),
          if (isXtreamCode)
            HoverScaleWrapper(
              hoverScale: 1.02,
              child: ListTile(
                leading: const Icon(Icons.subtitles_outlined),
                title: Text(context.loc.hide_category),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  XtreamCodeHomeController? ctrl;
                  try {
                    ctrl = Provider.of<XtreamCodeHomeController>(
                      context, listen: false);
                  } catch (_) {}

                  final result = await Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => CategorySettingsScreen(
                        controller: ctrl ?? XtreamCodeHomeController(false),
                      ),
                      transitionsBuilder: (_, animation, __, child) {
                        return FadeTransition(
                          opacity: CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            )),
                            child: child,
                          ),
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 280),
                    ),
                  );

                    if (isXtreamCode) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => XtreamCodeDataLoaderScreen(
                            playlist: AppState.currentPlaylist!,
                            refreshAll: true,
                          ),
                        ),
                      );
                    }
                },
              ),
            ),
          const Divider(height: 1),
          DropdownTileWidget<Locale>(
            icon: Icons.language,
            label: context.loc.app_language,
            value: Localizations.localeOf(context),
            items: [
              ...supportedLanguages.map(
                (language) => DropdownMenuItem(
                  value: Locale(language['code']),
                  child: Text(language['name']),
                ),
              ),
            ],
            onChanged: (v) {
              Provider.of<LocaleProvider>(
                context,
                listen: false,
              ).setLocale(v!);
            },
          ),
          const Divider(height: 1),
          DropdownTileWidget<String>(
            icon: Icons.color_lens_outlined,
            label: context.loc.theme,
            value: _selectedTheme,
            items: [
              DropdownMenuItem(
                value: 'light',
                child: Text(context.loc.light),
              ),
              DropdownMenuItem(
                value: 'dark',
                child: Text(context.loc.dark),
              ),
              const DropdownMenuItem(
                value: 'skyBlue',
                child: Text('Sky Blue'),
              ),
            ],
            onChanged: (value) async {
              if (value != null) {
                await themeProvider.setTheme(value);
                setState(() {
                  _selectedTheme = value;
                });
              }
            },
          ),
          const Divider(height: 1),
          HoverScaleWrapper(
            hoverScale: 1.02,
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Parental Controls'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _pushAnimated(context, const ParentalControlsScreen());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.play_circle_outline),
            title: Text(context.loc.continue_on_background),
            subtitle: Text(
              context.loc.continue_on_background_description,
            ),
            value: _backgroundPlayEnabled,
            onChanged: _saveBackgroundPlaySetting,
          ),
          const Divider(height: 1),
          HoverScaleWrapper(
            hoverScale: 1.02,
            child: ListTile(
              leading: const Icon(Icons.subtitles_outlined),
              title: Text(context.loc.subtitle_settings),
              subtitle: Text(context.loc.subtitle_settings_description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _pushAnimated(context, const SubtitleSettingsScreen());
              },
            ),
          ),
          _buildUpscalerSection(Theme.of(context)),
          _buildStreamEnhancementSection(Theme.of(context)),
          // Player gesture settings - Only show on mobile platforms (Android & iOS)
          if (Theme.of(context).platform == TargetPlatform.android ||
              Theme.of(context).platform == TargetPlatform.iOS) ...[
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.brightness_6),
              title: Text(context.loc.brightness_gesture),
              subtitle: Text(
                context.loc.brightness_gesture_description,
              ),
              value: _brightnessGesture,
              onChanged: (value) async {
                await UserPreferences.setBrightnessGesture(value);
                setState(() {
                  _brightnessGesture = value;
                });
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up),
              title: Text(context.loc.volume_gesture),
              subtitle: Text(context.loc.volume_gesture_description),
              value: _volumeGesture,
              onChanged: (value) async {
                await UserPreferences.setVolumeGesture(value);
                setState(() {
                  _volumeGesture = value;
                });
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.swipe),
              title: Text(context.loc.seek_gesture),
              subtitle: Text(context.loc.seek_gesture_description),
              value: _seekGesture,
              onChanged: (value) async {
                await UserPreferences.setSeekGesture(value);
                setState(() {
                  _seekGesture = value;
                });
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.fast_forward),
              title: Text(context.loc.speed_up_on_long_press),
              subtitle: Text(
                context.loc.speed_up_on_long_press_description,
              ),
              value: _speedUpOnLongPress,
              onChanged: (value) async {
                await UserPreferences.setSpeedUpOnLongPress(value);
                setState(() {
                  _speedUpOnLongPress = value;
                });
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.touch_app),
              title: Text(context.loc.seek_on_double_tap),
              subtitle: Text(
                context.loc.seek_on_double_tap_description,
              ),
              value: _seekOnDoubleTap,
              onChanged: (value) async {
                await UserPreferences.setSeekOnDoubleTap(value);
                setState(() {
                  _seekOnDoubleTap = value;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntegrationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: _tmdbKeyController,
          obscureText: _obscureTmdbKey,
          decoration: InputDecoration(
            labelText: context.loc.tmdb_api_key,
            hintText: context.loc.enter_tmdb_api_key,
            icon: const Icon(Icons.api_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureTmdbKey ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() => _obscureTmdbKey = !_obscureTmdbKey);
              },
            ),
            border: InputBorder.none,
          ),
          onChanged: (value) async {
            await AppConfig.setTmdbApiKey(value);
          },
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.loc.app_version),
            subtitle: Text(
              _appVersion.isNotEmpty ? _appVersion : 'Loading...',
            ),
            dense: true,
          ),
          const Divider(height: 1),
          HoverScaleWrapper(
            hoverScale: 1.02,
            child: ListTile(
              leading: const Icon(Icons.code),
              title: Text(context.loc.support_on_github),
              subtitle: Text(context.loc.support_on_github_description),
              trailing: const Icon(Icons.open_in_new, size: 18),
              dense: true,
              onTap: () async {
                final url = Uri.parse(
                  'https://github.com/bsogulcan/another-iptv-player',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : FadeTransition(
            opacity: _fadeAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final theme = Theme.of(context);

                // Account entry tile
                final accountTile = Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                      child: Icon(
                        SyncService.instance.isLoggedIn ? Icons.account_circle_rounded : Icons.person_outline_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      SyncService.instance.isLoggedIn ? 'Account & Sync' : 'Sign In / Register',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      SyncService.instance.isLoggedIn ? 'Manage your account and cloud sync' : 'Connect to your sync server',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
                  ),
                );

                // All section widgets in order
                final playlist       = _buildPlaylistCard(context);
                final generalTitle   = SectionTitleWidget(title: context.loc.general_settings);
                final generalCard    = _buildGeneralCard(context);
                final playerTitle    = SectionTitleWidget(title: context.loc.player_settings);
                final playerCard     = _buildPlayerCard(context);
                final integrationTitle = SectionTitleWidget(title: context.loc.integration);
                final integrationCard  = _buildIntegrationCard(context);
                final homeTitle      = SectionTitleWidget(title: context.loc.home_customization);
                final homeSection    = const HomeCustomizationSection();
                final aboutTitle     = SectionTitleWidget(title: context.loc.about);
                final aboutCard      = _buildAboutCard(context);

                if (!isWide) {
                  // Single column — original layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      accountTile,
                      const SizedBox(height: 10),
                      playlist,
                      const SizedBox(height: 10),
                      generalTitle, generalCard,
                      const SizedBox(height: 10),
                      playerTitle, playerCard,
                      const SizedBox(height: 10),
                      integrationTitle, integrationCard,
                      const SizedBox(height: 10),
                      homeTitle, homeSection,
                      const SizedBox(height: 10),
                      aboutTitle, aboutCard,
                    ],
                  );
                }

                // Two-column layout
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Account tile spans full width
                    accountTile,
                    const SizedBox(height: 10),
                    // Playlist card spans full width
                    playlist,
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left column: General + Player
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              generalTitle, generalCard,
                              const SizedBox(height: 10),
                              playerTitle, playerCard,
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Right column: Integration + Home Customization + About
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              integrationTitle, integrationCard,
                              const SizedBox(height: 10),
                              homeTitle, homeSection,
                              const SizedBox(height: 10),
                              aboutTitle, aboutCard,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
  }

  refreshM3uPlaylist() async {
    List<M3uItem> oldM3uItems = AppState.m3uItems!;
    List<M3uItem> newM3uItems = [];

    if (AppState.currentPlaylist!.url!.startsWith('http')) {
      showLoadingDialog(context, context.loc.loading_m3u);
      final params = {
        'id': AppState.currentPlaylist!.id,
        'url': AppState.currentPlaylist!.url!,
      };
      newM3uItems = await compute(M3uParser.parseM3uUrl, params);
    } else {
      await _pickFile();
      if (_selectedFilePath == null) return;

      showLoadingDialog(context, context.loc.loading_m3u);
      final params = {
        'id': AppState.currentPlaylist!.id,
        'filePath': _selectedFilePath!,
      };
      newM3uItems = await compute(M3uParser.parseM3uFile, params);
    }

    newM3uItems = updateM3UItemIdsByPosition(
      oldItems: oldM3uItems,
      newItems: newM3uItems,
    );

    await database.deleteAllM3uItems(AppState.currentPlaylist!.id);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => M3uDataLoaderScreen(
          playlist: AppState.currentPlaylist!,
          m3uItems: newM3uItems,
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    _selectedFilePath = null;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8'],
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.loc.file_selection_error)));
    }
  }

  List<M3uItem> updateM3UItemIdsByPosition({
    required List<M3uItem> oldItems,
    required List<M3uItem> newItems,
  }) {
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
