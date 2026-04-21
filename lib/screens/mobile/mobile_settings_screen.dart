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
import '../account/account_screen.dart';

class MobileSettingsScreen extends StatefulWidget {
  const MobileSettingsScreen({super.key});

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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListView(
      cacheExtent: 500,
      children: [
        _buildSectionHeader(context.loc.account),
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(SyncService.instance.isLoggedIn ? 'Account & Sync' : 'Sign In / Register'),
          subtitle: Text(SyncService.instance.isLoggedIn ? 'Manage your account' : 'Connect to your sync server'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
        ),
        
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
