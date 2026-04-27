package dev.ogos.anotheriptvplayer

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TvPlayerChannel : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "dev.ogos.anotheriptvplayer/tv_player")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "launch" -> {
                val act = activity ?: return result.error("NO_ACTIVITY", "Activity not available", null)
                val url         = call.argument<String>("url") ?: return result.error("MISSING", "url required", null)
                val title       = call.argument<String>("title") ?: ""
                val contentType = call.argument<String>("contentType") ?: "live"
                val subtitleUrl = call.argument<String>("subtitleUrl") ?: ""
                val queueJson   = call.argument<String>("queueJson") ?: "[]"
                val currentIdx  = call.argument<Int>("currentIndex") ?: 0
                val position    = call.argument<Long>("position") ?: 0L

                val intent = Intent(act, TvPlayerActivity::class.java).apply {
                    putExtra(TvPlayerActivity.EXTRA_URL, url)
                    putExtra(TvPlayerActivity.EXTRA_TITLE, title)
                    putExtra(TvPlayerActivity.EXTRA_CONTENT_TYPE, contentType)
                    putExtra(TvPlayerActivity.EXTRA_SUBTITLE_URL, subtitleUrl)
                    putExtra(TvPlayerActivity.EXTRA_QUEUE_JSON, queueJson)
                    putExtra(TvPlayerActivity.EXTRA_CURRENT_INDEX, currentIdx)
                    putExtra(TvPlayerActivity.EXTRA_POSITION, position)
                }
                act.startActivity(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
