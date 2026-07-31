package com.example.common_place_book

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var shareChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    // Dart asks once on startup whether this launch came from
                    // the share sheet (ACTION_SEND cold start).
                    "getInitialShare" -> result.success(consumeShare(intent))
                    else -> result.notImplemented()
                }
            }
        }
    }

    // Share delivered while the app is already running (launchMode singleTop).
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val share = consumeShare(intent) ?: return
        shareChannel?.invokeMethod("shareReceived", share)
    }

    /**
     * Extracts shared text/title from an ACTION_SEND intent, or null when the
     * intent is not a (non-empty) text share. Consuming clears the action so a
     * Dart hot restart or repeated getInitialShare cannot re-deliver the same
     * share.
     */
    private fun consumeShare(intent: Intent?): Map<String, String>? {
        if (intent?.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("text/") != true) return null
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim().orEmpty()
        val title = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim().orEmpty()
        if (text.isEmpty() && title.isEmpty()) return null
        intent.action = Intent.ACTION_MAIN
        return buildMap {
            if (text.isNotEmpty()) put("text", text)
            if (title.isNotEmpty()) put("title", title)
        }
    }

    private companion object {
        const val SHARE_CHANNEL = "com.example.common_place_book/share"
    }
}
