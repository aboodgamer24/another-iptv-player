import 'package:flutter/material.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/widgets/dropdown_tile_widget.dart';
import 'package:another_iptv_player/widgets/section_title_widget.dart';

class LiveTvSettingsSection extends StatefulWidget {
  const LiveTvSettingsSection({super.key});

  @override
  State<LiveTvSettingsSection> createState() => _LiveTvSettingsSectionState();
}

class _LiveTvSettingsSectionState extends State<LiveTvSettingsSection> {
  bool _isLoading = true;
  String _listStyle = 'grid';
  bool _showLogos = true;
  bool _rememberChannel = true;
  int _gridColumns = 0; // 0 = Auto
  String _sortOrder = 'default';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final listStyle = await UserPreferences.getLiveTvListStyle();
    final showLogos = await UserPreferences.getLiveTvShowLogos();
    final rememberChannel = await UserPreferences.getLiveTvRememberChannel();
    final gridColumns = await UserPreferences.getLiveTvGridColumns();
    final sortOrder = await UserPreferences.getLiveTvSortOrder();

    setState(() {
      _listStyle = listStyle;
      _showLogos = showLogos;
      _rememberChannel = rememberChannel;
      _gridColumns = gridColumns;
      _sortOrder = sortOrder;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitleWidget(title: context.loc.live_streams),

        DropdownTileWidget(
          label: 'Desktop List Style', // Fallback, will be localized
          icon: Icons.view_list_rounded,
          value: _listStyle,
          items: const [
            DropdownMenuItem(value: 'grid', child: Text('Grid View')),
            DropdownMenuItem(value: 'list', child: Text('List View')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _listStyle = value);
              UserPreferences.setLiveTvListStyle(value);
            }
          },
        ),

        SwitchListTile(
          title: const Text('Show Channel Logos'),
          subtitle: const Text('Display logos in the channel list'),
          secondary: const Icon(Icons.image_rounded),
          value: _showLogos,
          onChanged: (value) {
            setState(() => _showLogos = value);
            UserPreferences.setLiveTvShowLogos(value);
          },
        ),

        SwitchListTile(
          title: const Text('Remember Last Channel'),
          subtitle: const Text(
            'Resume the last watched channel when starting Live TV',
          ),
          secondary: const Icon(Icons.history_rounded),
          value: _rememberChannel,
          onChanged: (value) {
            setState(() => _rememberChannel = value);
            UserPreferences.setLiveTvRememberChannel(value);
          },
        ),

        if (_listStyle == 'grid')
          ListTile(
            leading: const Icon(Icons.grid_view_rounded),
            title: const Text('Grid Columns (Desktop)'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_gridColumns == 0 ? 'Auto' : '$_gridColumns columns'),
                Slider(
                  value: _gridColumns.toDouble(),
                  min: 0,
                  max: 8,
                  divisions: 8,
                  label: _gridColumns == 0 ? 'Auto' : _gridColumns.toString(),
                  onChanged: (value) {
                    setState(() => _gridColumns = value.toInt());
                    UserPreferences.setLiveTvGridColumns(value.toInt());
                  },
                ),
              ],
            ),
          ),

        DropdownTileWidget(
          label: 'Sort Order',
          icon: Icons.sort_rounded,
          value: _sortOrder,
          items: const [
            DropdownMenuItem(
              value: 'default',
              child: Text('Default (Playlist order)'),
            ),
            DropdownMenuItem(value: 'asc', child: Text('A to Z')),
            DropdownMenuItem(value: 'desc', child: Text('Z to A')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _sortOrder = value);
              UserPreferences.setLiveTvSortOrder(value);
            }
          },
        ),
      ],
    );
  }
}
