package dev.ogos.anotheriptvplayer

import android.content.pm.PackageManager
import android.os.Bundle
import android.os.StrictMode
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "dev.ogos.anotheriptvplayer/platform"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (BuildConfig.DEBUG) {
            StrictMode.setThreadPolicy(
                StrictMode.ThreadPolicy.Builder()
                    .detectAll()
                    .penaltyLog()
                    .build()
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(VideoStatsPlugin())
        flutterEngine.plugins.add(LivePlaybackPlugin())
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

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        return super.onKeyDown(keyCode, event)
    }

    override fun onBackPressed() {
        // Do not call super here — let Flutter's PopScope/Navigator handle it
        // This prevents Android from finishing the Activity before Flutter responds
    }
}

