import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist_model.dart';
import '../controllers/xtream_code_home_controller.dart';
import '../controllers/m3u_home_controller.dart';
import '../controllers/watch_history_controller.dart';
import 'main_navigation_screen.dart';

class MainNavigationScreenProvider extends StatefulWidget {
  final Playlist playlist;
  const MainNavigationScreenProvider({super.key, required this.playlist});

  @override
  State<MainNavigationScreenProvider> createState() => _MainNavigationScreenProviderState();
}

class _MainNavigationScreenProviderState extends State<MainNavigationScreenProvider> {
  late dynamic _controller; // XtreamCodeHomeController or M3UHomeController

  @override
  void initState() {
    super.initState();
    if (widget.playlist.type == PlaylistType.xtream) {
      _controller = XtreamCodeHomeController(false);
    } else {
      _controller = M3UHomeController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (widget.playlist.type == PlaylistType.xtream)
          ChangeNotifierProvider<XtreamCodeHomeController>.value(
            value: _controller as XtreamCodeHomeController,
          )
        else
          ChangeNotifierProvider<M3UHomeController>.value(
            value: _controller as M3UHomeController,
          ),
        ChangeNotifierProvider(create: (_) => WatchHistoryController()),
      ],
      child: MainNavigationScreen(playlist: widget.playlist),
    );
  }
}
