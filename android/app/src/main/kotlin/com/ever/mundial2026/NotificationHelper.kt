package com.ever.mundial2026

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

object NotificationHelper {
    private const val CHANNEL_ID = "mundial_live"
    private const val TRACKING_CHANNEL_ID = "mundial_tracking"
    private const val PREFS_NAME = "MundialNotificationState"
    private const val SENT_KEYS = "sentKeys"
    private const val LANGUAGE = "language"
    private const val NOTIFICATION_PERMISSION_REQUEST = 2606

    fun requestNotificationPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            activity.requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
        }
    }

    fun setLanguage(context: Context, code: String) {
        prefs(context).edit().putString(LANGUAGE, if (code == "en") "en" else "es").apply()
    }

    fun language(context: Context): String = prefs(context).getString(LANGUAGE, "es") ?: "es"

    fun notifyOnce(context: Context, key: String, id: Int, title: String, body: String): Boolean {
        if (key.isNotBlank() && wasSent(context, key)) return false
        if (!canPostNotifications(context)) return false
        showNotification(context, id, title, body)
        if (key.isNotBlank()) markSent(context, key)
        return true
    }

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Mundial en vivo",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Goles, comienzos y finales de partidos"
            enableVibration(true)
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    /** Canal de baja importancia para la notificación persistente del servicio. */
    fun createTrackingChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val es = language(context) != "en"
        val channel = NotificationChannel(
            TRACKING_CHANNEL_ID,
            if (es) "Seguimiento en vivo" else "Live tracking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = if (es) "Activo mientras hay partidos en vivo" else "Active while matches are live"
            setShowBadge(false)
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    /** Notificación persistente (ongoing) del foreground service. */
    fun trackingNotification(context: Context): Notification {
        createTrackingChannel(context)
        val es = language(context) != "en"
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val pendingIntent = PendingIntent.getActivity(context, 990, intent, flags)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, TRACKING_CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }
        return builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(if (es) "Siguiendo partidos en vivo" else "Following live matches")
            .setContentText(if (es) "Te avisamos los goles al instante" else "We'll alert goals instantly")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(Notification.PRIORITY_LOW)
            .build()
    }

    private fun showNotification(context: Context, id: Int, title: String, body: String) {
        createNotificationChannel(context)
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val pendingIntent = PendingIntent.getActivity(context, id, intent, flags)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }

        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(Notification.PRIORITY_HIGH)

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(id, builder.build())
    }

    private fun canPostNotifications(context: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    private fun wasSent(context: Context, key: String): Boolean {
        return prefs(context).getStringSet(SENT_KEYS, emptySet())?.contains(key) == true
    }

    private fun markSent(context: Context, key: String) {
        val current = prefs(context).getStringSet(SENT_KEYS, emptySet())?.toMutableSet() ?: mutableSetOf()
        current.add(key)
        prefs(context).edit().putStringSet(SENT_KEYS, current).apply()
    }

    internal fun prefs(context: Context) = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
