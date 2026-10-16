package com.ytget.ytget

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = YtDlpBridge(applicationContext)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.ytget/ytdlp"
        ).setMethodCallHandler(bridge)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.ytget/ytdlp_events"
        ).setStreamHandler(bridge)
    }
}
