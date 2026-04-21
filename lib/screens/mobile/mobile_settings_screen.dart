import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../controllers/theme_provider.dart';
import '../../controllers/locale_provider.dart';
import '../../repositories/user_preferences.dart';
import '../../services/sync_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final info = await PackageInfo.fromPlatform();
    final bgPlay = await UserPreferences.getBackgroundPlay();
    final theme = await UserPreferences.getThemeName();
    setState(() {
      _appVersion = info.version;
      _backgroundPlay = bgPlay;
      _theme = theme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _buildSectionHeader('Account'),
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(SyncService.instance.isLoggedIn ? 'Account & Sync' : 'Sign In / Register'),
          subtitle: Text(SyncService.instance.isLoggedIn ? 'Manage your account' : 'Connect to your sync server'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
        ),
        const Divider(),
        _buildSectionHeader('Playback'),
        SwitchListTile(
          secondary: const Icon(Icons.play_circle_outline),
          title: const Text('Background Play'),
          subtitle: const Text('Continue playing when app is in background'),
          value: _backgroundPlay,
          onChanged: (v) async {
            await UserPreferences.setBackgroundPlay(v);
            setState(() => _backgroundPlay = v);
          },
        ),
        const Divider(),
        _buildSectionHeader('Appearance'),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Theme'),
          subtitle: Text(_theme.capitalize()),
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
          onTap: () {}, // Link to GitHub
        ),
      ],
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
            _themeOption('System', 'system'),
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
              return ListTile(
                title: Text(lang['name']!),
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
