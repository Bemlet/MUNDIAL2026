package com.ever.mundial2026

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationsChannel = "mundial2026/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationsChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    NotificationHelper.createNotificationChannel(this)
                    LiveSyncWorker.schedule(this)
                    result.success(null)
                }
                "requestPermission" -> {
                    NotificationHelper.requestNotificationPermission(this)
                    result.success(null)
                }
                "setLanguage" -> {
                    val code = call.argument<String>("code") ?: "es"
                    NotificationHelper.setLanguage(this, code)
                    result.success(null)
                }
                "show" -> {
                    val key = call.argument<String>("key") ?: ""
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: "Mundial 2026"
                    val body = call.argument<String>("body") ?: ""
                    result.success(NotificationHelper.notifyOnce(this, key, id, title, body))
                }
                else -> result.notImplemented()
            }
        }
    }
}
