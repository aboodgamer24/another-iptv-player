package dev.ogos.anotheriptvplayer

import android.media.MediaExtractor
import android.media.MediaFormat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class VideoStatsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.aboodgamer24.iptv/video_stats")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getVideoStats" -> {
                val url = call.argument<String>("url")
                if (url == null) {
                    result.error("MISSING_ARG", "url is required", null)
                    return
                }
                Thread {
                    try {
                        val extractor = MediaExtractor()
                        extractor.setDataSource(url)
                        var width = 0; var height = 0; var codec = ""; var fps = 0f
                        for (i in 0 until extractor.trackCount) {
                            val fmt = extractor.getTrackFormat(i)
                            val mime = fmt.getString(MediaFormat.KEY_MIME) ?: ""
                            if (mime.startsWith("video/")) {
                                width  = runCatching { fmt.getInteger(MediaFormat.KEY_WIDTH) }.getOrDefault(0)
                                height = runCatching { fmt.getInteger(MediaFormat.KEY_HEIGHT) }.getOrDefault(0)
                                fps    = runCatching { fmt.getInteger(MediaFormat.KEY_FRAME_RATE).toFloat() }.getOrDefault(0f)
                                codec  = mime
                                break
                            }
                        }
                        extractor.release()
                        result.success(mapOf("width" to width, "height" to height, "codec" to codec, "frameRate" to fps))
                    } catch (e: Exception) {
                        result.error("EXTRACT_ERROR", e.message, null)
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }
}
