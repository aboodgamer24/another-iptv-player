import 'package:flutter/material.dart';
import '../../database/database.dart';
import '../../services/playlist_service.dart';

import '../../services/service_locator.dart';
import '../../services/sync_applier.dart';
import '../../services/sync_service.dart';
import '../../repositories/user_preferences.dart';
import '../welcome_screen.dart';
import '../../utils/app_config.dart';
import '../../utils/app_transitions.dart';


class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _serverCtrl = TextEditingController(text: 'http://');
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  String? _error;
  Map<String, dynamic> _user = {};
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    _user = await UserPreferences.getSyncUser();
    final serverUrl = await UserPreferences.getSyncServerUrl();
    if (serverUrl != null) _serverCtrl.text = serverUrl;
    setState(() => _loggedIn = SyncService.instance.isLoggedIn);
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isRegister) {
        await SyncService.instance.register(
          _serverCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          _nameCtrl.text.trim(),
        );
      } else {
        await SyncService.instance.login(
          _serverCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
      }
      // Pull all synced data and apply locally
      await _pullAndApply();
      _user = await UserPreferences.getSyncUser();
      setState(() => _loggedIn = true);
    } on Exception catch (e) {
      setState(() => _error = e.toString().replaceAll('DioException', 'Connection error'));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pullAndApply() async {
    // Delegate entirely to SyncApplier which correctly writes to Drift DB
    final success = await SyncApplier.pullAndApply();
    debugPrint('[AccountScreen] _pullAndApply: success=$success');
  }

  Future<void> _logout() async {
    setState(() => _loading = true);
    try {
      // 1. Push everything before logging out (existing behaviour)
      await _pushAll();
      
      // 2. Wipe all local data
      final db = getIt<AppDatabase>();
      await db.deleteAllPlaylists();          // wipe all playlists
      await db.deleteAllFavorites();          // wipe all favorites (all playlists)
      await db.deleteAllWatchLater();         // wipe all watch later (all playlists)
      await db.deleteAllWatchHistories();      // wipe all continue watching (all playlists)
      await UserPreferences.removeLastPlaylist();
      await AppConfig.setTmdbApiKey('');
      await UserPreferences.clearSyncedSettings();
      await UserPreferences.setHasSeenWelcome(false);

      // 3. Clear auth session
      await SyncService.instance.logout();
      
      // 4. Navigate to Welcome screen, removing all routes
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          fadeRoute(builder: (_) => const WelcomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      debugPrint('[AccountScreen] logout error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pushAll() async {
    try {
      // Read playlists from Drift DB (the real source of truth)
      final playlists = await PlaylistService.getPlaylists();
      final playlistsJson = playlists.map((p) => p.toJson()).toList();

      // Read favorites from Drift DB
      final db = getIt<AppDatabase>();
      final favorites = await db.getAllFavorites();
      final favoritesJson = favorites.map((f) => {
        'id': f.id,
        'playlistId': f.playlistId,
        'contentType': f.contentType.toString(),
        'streamId': f.streamId,
        'episodeId': f.episodeId,
        'name': f.name,
        'imagePath': f.imagePath,
        'sortOrder': f.sortOrder,
      }).toList();

      // Read watch later from Drift DB
      final watchLaterItems = await db.getAllWatchLater();
      final watchLaterJson = watchLaterItems.map((w) => {
        'id': w.id,
        'playlistId': w.playlistId,
        'contentType': w.contentType.toString(),
        'streamId': w.streamId,
        'title': w.title,
        'imagePath': w.imagePath,
      }).toList();

      // Read watch history from Drift DB
      final watchHistories = await db.getAllWatchHistories();
      final watchHistoriesJson = watchHistories.map((w) => {
        'playlistId':    w.playlistId,
        'contentType':   w.contentType.toString(),
        'streamId':      w.streamId,
        'seriesId':      w.seriesId,
        'watchDuration': w.watchDuration,
        'totalDuration': w.totalDuration,
        'lastWatched':   w.lastWatched.toIso8601String(),
        'imagePath':     w.imagePath,
        'title':         w.title,
      }).toList();

      // Build settings snapshot
      final settings = await _buildSettings();

      await SyncService.instance.pushAll({
        'playlists': playlistsJson,
        'favorites': favoritesJson,
        'watch_later': watchLaterJson,
        'continue_watching': watchHistoriesJson,
        'settings': settings,
      });

      debugPrint('[AccountScreen] pushAll: pushed ${playlistsJson.length} playlists, ${favoritesJson.length} favorites, ${watchLaterJson.length} watch later items, ${watchHistoriesJson.length} watch histories');
    } catch (e) {
      debugPrint('[AccountScreen] _pushAll error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _buildSettings() async {
    return await UserPreferences.buildSettingsSnapshot();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _loggedIn ? _buildProfile(theme) : _buildLoginForm(theme),
      ),
    );
  }

  Widget _buildProfile(ThemeData theme) {
    final name = _user['display_name'] ?? _user['email'] ?? 'User';
    final email = _user['email'] ?? '';
    final color = Color(int.tryParse((_user['avatar_color'] ?? '#01696f').replaceAll('#', '0xFF')) ?? 0xFF01696f);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: color,
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(email, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        _SyncTile(
          icon: Icons.sync_rounded,
          title: 'Sync Now',
          subtitle: 'Push all local data to server',
          onTap: () async {
            await _pushAll();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Synced successfully')));
          },
        ),
        _SyncTile(
          icon: Icons.download_rounded,
          title: 'Pull from Server',
          subtitle: 'Overwrite local data with server data',
          onTap: () async {
            await _pullAndApply();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data pulled from server')));
          },
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isRegister ? 'Create Account' : 'Sign In',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Connect to your self-hosted sync server',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _serverCtrl,
          decoration: const InputDecoration(
            labelText: 'Server URL',
            hintText: 'http://192.168.1.100:7000',
            prefixIcon: Icon(Icons.dns_rounded),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        if (_isRegister) ...[
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              prefixIcon: Icon(Icons.person_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_rounded),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isRegister ? 'Create Account' : 'Sign In'),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() { _isRegister = !_isRegister; _error = null; }),
            child: Text(_isRegister ? 'Already have an account? Sign In' : 'No account? Register'),
          ),
        ),
      ],
    );
  }
}

class _SyncTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SyncTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
      onTap: onTap,
    );
  }
}
