import 'dart:convert';
import 'package:flutter/services.dart';

class TvPlayerItem {
  final String url;
  final String title;
  final String subtitleUrl;

  const TvPlayerItem({
    required this.url,
    required this.title,
    this.subtitleUrl = '',
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'subtitleUrl': subtitleUrl,
  };
}

class TvPlayerService {
  static const _channel = MethodChannel('dev.ogos.anotheriptvplayer/tv_player');

  /// Launch the native Compose TV player with a single item.
  static Future<void> launch({
    required String url,
    required String title,
    String contentType = 'live',
    String subtitleUrl = '',
    int position = 0,
  }) async {
    await _channel.invokeMethod('launch', {
      'url': url,
      'title': title,
      'contentType': contentType,
      'subtitleUrl': subtitleUrl,
      'queueJson': '[]',
      'currentIndex': 0,
      'position': position,
    });
  }

  /// Launch the native Compose TV player with a queue of items.
  static Future<void> launchQueue({
    required List<TvPlayerItem> queue,
    required int currentIndex,
    String contentType = 'live',
    int position = 0,
  }) async {
    if (queue.isEmpty) return;
    final current = queue[currentIndex.clamp(0, queue.length - 1)];
    await _channel.invokeMethod('launch', {
      'url': current.url,
      'title': current.title,
      'contentType': contentType,
      'subtitleUrl': current.subtitleUrl,
      'queueJson': jsonEncode(queue.map((e) => e.toJson()).toList()),
      'currentIndex': currentIndex.clamp(0, queue.length - 1),
      'position': position,
    });
  }
}
