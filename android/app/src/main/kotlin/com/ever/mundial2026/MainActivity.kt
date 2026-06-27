package com.ever.mundial2026

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationsChannel = "mundial2026/notifications"
    private var channel: MethodChannel? = null
    private var pendingRoute: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Ruta de lanzamiento (la app se abrió tocando una notificación).
        intent?.getStringExtra("route")?.let { pendingRoute = it }
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationsChannel)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    NotificationHelper.createNotificationChannel(this)
                    NotificationHelper.createTrackingChannel(this)
                    LiveSyncWorker.schedule(this)
                    AlarmScheduler.scheduleAll(this)
                    result.success(null)
                }
                "requestPermission" -> {
                    NotificationHelper.requestNotificationPermission(this)
                    result.success(null)
                }
                "canScheduleExactAlarms" -> {
                    val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    result.success(AlarmScheduler.canScheduleExact(am))
                }
                "requestExactAlarm" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        } catch (_: Exception) {
                        }
                    }
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
                    val route = call.argument<String>("route")
                    result.success(NotificationHelper.notifyOnce(this, key, id, title, body, route))
                }
                "consumeRoute" -> {
                    val r = pendingRoute
                    pendingRoute = null
                    result.success(r)
                }
                else -> result.notImplemented()
            }
        }
    }

    // App ya abierta y se toca una notificación con ruta: navegar directo.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra("route")?.let { route ->
            channel?.invokeMethod("navigate", route)
        }
    }
}
