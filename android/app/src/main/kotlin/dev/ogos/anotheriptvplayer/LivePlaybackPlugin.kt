package dev.ogos.anotheriptvplayer

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class LivePlaybackPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.aboodgamer24.iptv/live_playback")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Returns live-specific ExoPlayer DefaultLoadControl parameters
            // that should be applied BEFORE playing a live stream.
            // Flutter side reads these and posts them back to the native
            // video_player texture ID via a second channel call.
            "getLiveLoadControlParams" -> {
                // Conservative live buffer: 1s min, 5s max, 2s target offset
                result.success(mapOf(
                    "minBufferMs"      to 1_000,
                    "maxBufferMs"      to 5_000,
                    "bufferForPlaybackMs" to 1_000,
                    "bufferForPlaybackAfterRebufferMs" to 2_000,
                    "targetLiveOffsetMs" to 2_000,
                    "minPlaybackSpeed" to 0.97f,
                    "maxPlaybackSpeed" to 1.03f
                ))
            }
            else -> result.notImplemented()
        }
    }
}
