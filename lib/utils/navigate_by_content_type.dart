import 'package:another_iptv_player/screens/m3u/series/m3u_series_screen.dart';
import 'package:another_iptv_player/utils/get_playlist_type.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/utils/platform_utils.dart';
import '../screens/live_stream/live_stream_screen.dart';
import '../screens/m3u/m3u_player_screen.dart';
import '../screens/movies/movie_screen.dart';
import '../screens/series/series_screen.dart';
import '../screens/desktop/desktop_movie_detail_screen.dart';
import '../screens/desktop/desktop_series_detail_screen.dart';
import '../screens/mobile/mobile_movie_detail_screen.dart';
import '../screens/mobile/mobile_series_detail_screen.dart';
import 'package:provider/provider.dart';
import '../controllers/xtream_code_home_controller.dart';

bool _isDesktop(BuildContext context) {
  if (PlatformUtils.isMobile) return false;
  return MediaQuery.of(context).size.width >= 900;
}

Future<void> navigateByContentType(BuildContext context, ContentItem content) async {
  XtreamCodeHomeController? xtreamHomeController;
  try {
    xtreamHomeController = context.read<XtreamCodeHomeController>();
  } catch (_) {
    xtreamHomeController = null;
  }

  Widget wrapWithProvider(Widget child) {
    if (xtreamHomeController != null) {
      return ChangeNotifierProvider.value(
        value: xtreamHomeController,
        child: child,
      );
    }
    return child;
  }

  if (isM3u &&
      content.m3uItem != null &&
      content.contentType != ContentType.series) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => M3uPlayerScreen(
          contentItem: ContentItem(
            content.m3uItem!.id,
            content.m3uItem!.name ?? '',
            content.m3uItem!.tvgLogo ?? '',
            content.m3uItem!.contentType,
            m3uItem: content.m3uItem!,
          ),
        ),
      ),
    );
    return;
  }

  final desktop = _isDesktop(context);
  final isMobile = PlatformUtils.isMobile;

  switch (content.contentType) {
    case ContentType.liveStream:
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => wrapWithProvider(LiveStreamScreen(content: content)),
        ),
      );
    case ContentType.vod:
      if (isMobile && isXtreamCode) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => wrapWithProvider(MobileMovieDetailScreen(contentItem: content)),
          ),
        );
      } else if (desktop && isXtreamCode) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                wrapWithProvider(DesktopMovieDetailScreen(contentItem: content)),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => wrapWithProvider(MovieScreen(contentItem: content)),
          ),
        );
      }
    case ContentType.series:
      if (isXtreamCode) {
        if (isMobile) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => wrapWithProvider(MobileSeriesDetailScreen(contentItem: content)),
            ),
          );
        } else if (desktop) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  wrapWithProvider(DesktopSeriesDetailScreen(contentItem: content)),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => wrapWithProvider(SeriesScreen(contentItem: content)),
            ),
          );
        }
      } else if (isM3u) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => wrapWithProvider(M3uSeriesScreen(contentItem: content)),
          ),
        );
      }
  }
}

