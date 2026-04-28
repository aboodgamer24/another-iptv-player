import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
// --- FIX: ADD REQUIRED IMPORT ---
import '../models/playlist_content_model.dart';
// ---------------------------------

abstract class PlayerState {
  static List<VideoTrack> videos = [];
  static VideoTrack selectedVideo = VideoTrack.auto();

  static List<AudioTrack> audios = [];
  static AudioTrack selectedAudio = AudioTrack.auto();

  static List<SubtitleTrack> subtitles = [];
  static SubtitleTrack selectedSubtitle = SubtitleTrack.auto();

  // --- FIX: ADD GLOBAL CONTENT ITEM VARIABLE ---
  static ContentItem? currentContent;
  // ---------------------------------------------

  static List<ContentItem>? queue;
  static int currentIndex = 0;
  static bool showChannelList = false;
  static bool showVideoInfo = false;
  static bool showVideoSettings = false;
  static Duration? pendingTrackRestorePosition;
  static DateTime? pendingTrackRestoreTime;

  static String title = '';
  static bool backgroundPlay = true;
  static Player? activePlayer;
  static SubtitleViewConfiguration subtitleConfiguration =
      SubtitleViewConfiguration();

  /// Configures critical MPV streaming properties BEFORE media is opened.
  /// Properties set after open() are ignored on Windows/libmpv.
  static Future<void> configureMpvForStreaming(Player player) async {
    if (player.platform is! NativePlayer) return;
    final native = player.platform as NativePlayer;

    try {
      // ── HEVC fix: force keyframe-aligned decode on stream open ──────
      // This prevents "Could not find ref with POC" by skipping non-IDR
      // frames at the start of playback until the first clean keyframe
      await native.setProperty('hr-seek', 'absolute');
      await native.setProperty('hr-seek-framedrop', 'yes');

      // ── Demuxer buffering ───────────────────────────────────────────
      await native.setProperty('demuxer-readahead-secs', '15');
      await native.setProperty('demuxer-max-bytes', '200MiB');
      await native.setProperty('demuxer-max-back-bytes', '50MiB');

      // ── Probe settings so EAC3/AC4 audio is detected properly ───────
      await native.setProperty('demuxer-lavf-probesize', '10000000');
      await native.setProperty('demuxer-lavf-analyzeduration', '5000000');

      // ── Live stream cache ───────────────────────────────────────────
      await native.setProperty('cache', 'yes');
      await native.setProperty('cache-secs', '10');
      await native.setProperty(
        'stream-lavf-o',
        'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5',
      );

      // ── Suppress POC log spam (Windows debug only, harmless) ────────
      await native.setProperty('msg-level', 'hevc=no,ffmpeg=no');

      // ignore: avoid_print
      print('[Player] MPV streaming properties configured');
    } catch (e) {
      // ignore: avoid_print
      print('[Player] configureMpvForStreaming error: $e');
    }
  }
}
