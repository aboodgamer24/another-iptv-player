import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../controllers/home_rails_controller.dart';
import '../../models/api_configuration_model.dart';
import '../../models/playlist_model.dart';
import '../../repositories/iptv_repository.dart';
import '../../services/app_state.dart';
import 'xtream_code_home_screen.dart';

class XtreamCodeHomeScreenProvider extends StatefulWidget {
  final Playlist playlist;
  const XtreamCodeHomeScreenProvider({super.key, required this.playlist});

  @override
  State<XtreamCodeHomeScreenProvider> createState() => _XtreamCodeHomeScreenProviderState();
}

class _XtreamCodeHomeScreenProviderState extends State<XtreamCodeHomeScreenProvider> {
  late final XtreamCodeHomeController _controller;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    final repository = IptvRepository(
      ApiConfig(
        baseUrl: widget.playlist.url!,
        username: widget.playlist.username!,
        password: widget.playlist.password!,
      ),
      widget.playlist.id,
    );
    AppState.xtreamCodeRepository = repository;
    _controller = XtreamCodeHomeController(false);
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
        ChangeNotifierProvider.value(value: _controller),
        ChangeNotifierProvider(create: (_) => HomeRailsController()),
      ],
      child: XtreamCodeHomeScreen(playlist: widget.playlist),
    );
  }
}
