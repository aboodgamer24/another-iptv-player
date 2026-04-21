import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../controllers/theme_provider.dart';
import '../../controllers/locale_provider.dart';
import '../../repositories/user_preferences.dart';
import '../../services/sync_service.dart';
import '../../services/upscale_service.dart';
import '../../l10n/localization_extension.dart';
import '../../l10n/supported_languages.dart';
import '../../utils/app_config.dart';
import '../account/account_screen.dart';
import '../../screens/playlist_screen.dart';
import '../../screens/settings/subtitle_settings_section.dart';
import '../../screens/settings/parental_controls_screen.dart';
import '../../screens/settings/home_customization_section.dart';
import '../../services/app_state.dart';
import '../../utils/get_playlist_type.dart';
import '../../screens/xtream-codes/xtream_code_data_loader_screen.dart';
import '../../screens/settings/category_settings_section.dart';
import '../../controllers/xtream_code_home_controller.dart';

import '../../models/playlist_model.dart';

class MobileSettingsScreen extends StatefulWidget {
  final Playlist? playlist;
  const MobileSettingsScreen({super.key, this.playlist});

  @override
  State<MobileSettingsScreen> createState() => _MobileSettingsScreenState();
}

class _MobileSettingsScreenState extends State<MobileSettingsScreen> {
  String _appVersion = '';
  bool _backgroundPlay = false;
  String _theme = 'system';
  
  // Gestures
  bool _brightnessGesture = true;
  bool _volumeGesture = true;
  bool _seekGesture = true;
  bool _doubleTapSeek = true;
  bool _playbackSpeed = true;
  
  // Video Quality
  String _upscalePreset = 'standard';

  final TextEditingController _tmdbKeyController = TextEditingController();
  bool _obscureTmdbKey = true;
  bool _streamEnhancement = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final info = await PackageInfo.fromPlatform();
    final bgPlay = await UserPreferences.getBackgroundPlay();
    final theme = await UserPreferences.getThemeName();
    
    final bright = await UserPreferences.getBrightnessGesture();
    final vol = await UserPreferences.getVolumeGesture();
    final seek = await UserPreferences.getSeekGesture();
    final dtap = await UserPreferences.getSeekOnDoubleTap();
    final speed = await UserPreferences.getSpeedUpOnLongPress();
    final preset = await UserPreferences.getUpscalePreset();

    setState(() {
      _appVersion = info.version;
      _backgroundPlay = bgPlay;
      _theme = theme;
      
      _brightnessGesture = bright;
      _volumeGesture = vol;
      _seekGesture = seek;
      _doubleTapSeek = dtap;
      _playbackSpeed = speed;
      _upscalePreset = preset;
    });

    final streamEnh = await UserPreferences.getStreamEnhancement();
    setState(() {
      _streamEnhancement = streamEnh;
    });

    _tmdbKeyController.text = AppConfig.tmdbApiKey;
  }

  @override
  void dispose() {
    _tmdbKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListView(
      cacheExtent: 500,
      children: [
        // ── ACCOUNT ──────────────────────────────────────────
        _buildSectionHeader(context.loc.account),
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(SyncService.instance.isLoggedIn ? 'Account & Sync' : 'Sign In / Register'),
          subtitle: Text(SyncService.instance.isLoggedIn ? 'Manage your account' : 'Connect to your sync server'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
        ),

        // ── PLAYLIST ─────────────────────────────────────────
        const Divider(),
        _buildSectionHeader('Playlist'),
        ListTile(
          leading: const Icon(Icons.list_alt_outlined),
          title: const Text('Change Playlist'),
          subtitle: const Text('Switch to a different playlist'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await UserPreferences.removeLastPlaylist();
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => PlaylistScreen()),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Refresh Content'),
          subtitle: const Text('Re-download all channels and content'),
          trailing: const Icon(Icons.cloud_download_outlined),
          onTap: () {
            if (isXtreamCode) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => XtreamCodeDataLoaderScreen(
                    playlist: widget.playlist ?? AppState.currentPlaylist!,
                    refreshAll: true,
                  ),
                ),
              );
            }
          },
        ),
        if (isXtreamCode)
          ListTile(
            leading: const Icon(Icons.subtitles_outlined),
            title: const Text('Hidden Categories'),
            subtitle: const Text('Show or hide content categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              XtreamCodeHomeController? ctrl;
              try { ctrl = context.read<XtreamCodeHomeController>(); } catch (_) {}
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategorySettingsScreen(
                    controller: ctrl ?? XtreamCodeHomeController(false),
                  ),
                ),
              );
            },
          ),

        // ── PLAYER GESTURES ───────────────────────────────────
        const Divider(),
        _buildSectionHeader('Player Gestures'),
        _buildSwitchTile(
          icon: Icons.brightness_medium_outlined,
          title: 'Brightness Control',
          subtitle: 'Swipe on left side of player',
          value: _brightnessGesture,
          onChanged: (v) => _updateSetting(() => _brightnessGesture = v, UserPreferences.setBrightnessGesture(v)),
        ),
        _buildSwitchTile(
          icon: Icons.volume_up_outlined,
          title: 'Volume Control',
          subtitle: 'Swipe on right side of player',
          value: _volumeGesture,
          onChanged: (v) => _updateSetting(() => _volumeGesture = v, UserPreferences.setVolumeGesture(v)),
        ),
        _buildSwitchTile(
          icon: Icons.fast_forward_outlined,
          title: 'Horizontal Seek',
          subtitle: 'Swipe horizontally to seek',
          value: _seekGesture,
          onChanged: (v) => _updateSetting(() => _seekGesture = v, UserPreferences.setSeekGesture(v)),
        ),
        _buildSwitchTile(
          icon: Icons.touch_app_outlined,
          title: 'Double-Tap to Seek',
          subtitle: 'Double tap sides to skip 10s',
          value: _doubleTapSeek,
          onChanged: (v) => _updateSetting(() => _doubleTapSeek = v, UserPreferences.setSeekOnDoubleTap(v)),
        ),
        _buildSwitchTile(
          icon: Icons.speed_outlined,
          title: 'Long-Press Speed',
          subtitle: 'Hold to play at 2x speed',
          value: _playbackSpeed,
          onChanged: (v) => _updateSetting(() => _playbackSpeed = v, UserPreferences.setSpeedUpOnLongPress(v)),
        ),

        // ── VIDEO QUALITY ─────────────────────────────────────
        const Divider(),
        _buildSectionHeader('Video Quality'),
        ListTile(
          leading: const Icon(Icons.high_quality_outlined),
          title: const Text('Upscaler Preset'),
          subtitle: Text(upscalePresetLabel(_upscalePreset)),
          onTap: _showUpscalerDialog,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.play_circle_outline),
          title: const Text('Background Play'),
          subtitle: const Text('Continue playing when app is in background'),
          value: _backgroundPlay,
          onChanged: (v) => _updateSetting(() => _backgroundPlay = v, UserPreferences.setBackgroundPlay(v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.auto_fix_high_outlined),
          title: const Text('Stream Enhancement'),
          subtitle: const Text('Apply post-processing filters to video'),
          value: _streamEnhancement,
          onChanged: (v) => _updateSetting(() => _streamEnhancement = v, UserPreferences.setStreamEnhancement(v)),
        ),

        // ── PLAYER ────────────────────────────────────────────
        const Divider(),
        _buildSectionHeader('Player'),
        ListTile(
          leading: const Icon(Icons.subtitles_outlined),
          title: const Text('Subtitle Settings'),
          subtitle: const Text('Font, size, color and position'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubtitleSettingsScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Parental Controls'),
          subtitle: const Text('Set PIN and content restrictions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentalControlsScreen())),
        ),

        // ── APPEARANCE ────────────────────────────────────────
        const Divider(),
        _buildSectionHeader('Appearance'),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Theme'),
          subtitle: Text(_theme == 'system' ? 'System Default' : _theme.capitalize()),
          onTap: _showThemeDialog,
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('Language'),
          subtitle: Text(_getCurrentLanguageName()),
          onTap: _showLanguageDialog,
        ),

        // ── HOME CUSTOMIZATION ────────────────────────────────
        const Divider(),
        _buildSectionHeader('Home Customization'),
        const HomeCustomizationSection(),

        // ── INTEGRATIONS ──────────────────────────────────────
        const Divider(),
        _buildSectionHeader('Integrations'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _tmdbKeyController,
            obscureText: _obscureTmdbKey,
            decoration: InputDecoration(
              labelText: 'TMDB API Key',
              hintText: 'Enter your TMDB API key',
              prefixIcon: const Icon(Icons.api_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureTmdbKey ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscureTmdbKey = !_obscureTmdbKey),
              ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) async {
              await AppConfig.setTmdbApiKey(value);
            },
          ),
        ),

        // ── ABOUT ─────────────────────────────────────────────
        const Divider(),
        _buildSectionHeader('About'),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Version'),
          subtitle: Text(_appVersion),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('Source Code'),
          subtitle: const Text('View on GitHub'),
          onTap: () {},
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _updateSetting(VoidCallback stateUpdate, Future<void> prefUpdate) async {
    await prefUpdate;
    setState(stateUpdate);
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showUpscalerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Upscaler'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableUpscalePresets.map((preset) {
            return RadioListTile<String>(
              title: Text(upscalePresetLabel(preset)),
              subtitle: Text(upscalePresetDescription(preset)),
              value: preset,
              groupValue: _upscalePreset,
              onChanged: (v) async {
                if (v != null) {
                  await UserPreferences.setUpscalePreset(v);
                  setState(() => _upscalePreset = v);
                  if (mounted) Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _themeOption('Light', 'light'),
            _themeOption('Dark', 'dark'),
            _themeOption('Sky Blue', 'skyBlue'),
            _themeOption('System Default', 'system'),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(String label, String value) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: _theme,
      onChanged: (v) async {
        if (v != null) {
          await context.read<ThemeProvider>().setTheme(v);
          setState(() => _theme = v);
          if (mounted) Navigator.pop(context);
        }
      },
    );
  }

  String _getCurrentLanguageName() {
    final locale = Localizations.localeOf(context);
    final lang = supportedLanguages.firstWhere(
      (l) => l['code'] == locale.languageCode,
      orElse: () => {'name': 'English'},
    );
    return lang['name']!;
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: supportedLanguages.length,
            itemBuilder: (context, index) {
              final lang = supportedLanguages[index];
              final isSelected = Localizations.localeOf(context).languageCode == lang['code'];
              return ListTile(
                title: Text(lang['name']!),
                trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
                onTap: () {
                  context.read<LocaleProvider>().setLocale(Locale(lang['code']!));
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
