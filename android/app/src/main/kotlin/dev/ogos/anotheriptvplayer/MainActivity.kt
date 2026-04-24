package dev.ogos.anotheriptvplayer

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "dev.ogos.anotheriptvplayer/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTV" -> {
                        val isLeanback = packageManager.hasSystemFeature(
                            PackageManager.FEATURE_LEANBACK
                        )
                        result.success(isLeanback)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

