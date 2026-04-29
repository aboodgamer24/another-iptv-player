import 'package:c4tv_player/l10n/localization_extension.dart';
import 'package:c4tv_player/services/player_state.dart';
import 'package:c4tv_player/widgets/player-buttons/video_channel_selector_widget.dart';
import 'package:c4tv_player/widgets/player-buttons/video_info_widget.dart';
import 'package:c4tv_player/widgets/player-buttons/video_settings_widget.dart';
import 'package:flutter/material.dart';

class BackButtonWidget extends StatelessWidget {
  const BackButtonWidget({super.key});

  void _handleBackPress(BuildContext context) {
    if (PlayerState.showVideoInfo) {
      VideoInfoWidget.hideOverlay();
    }
    if (PlayerState.showChannelList) {
      VideoChannelSelectorWidget.hideOverlay();
    }
    if (PlayerState.showVideoSettings) {
      VideoSettingsWidget.hideOverlay();
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.loc.back,
      onPressed: () => _handleBackPress(context),
      icon: Icon(Icons.arrow_back_ios, color: Colors.white),
    );
  }
}
