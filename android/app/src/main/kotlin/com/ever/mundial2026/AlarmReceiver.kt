package com.ever.mundial2026

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Recibe las alarmas programadas por [AlarmScheduler]:
 *  - ACTION_REMINDER → postea la notificación "partido por comenzar".
 *  - ACTION_START_LIVE → arranca [LiveMatchService] (permitido porque viene de
 *    una alarma exacta, excepción válida para iniciar un FGS en background).
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val matchNo = intent.getIntExtra(EXTRA_MATCH_NO, -1)
        when (intent.action) {
            ACTION_REMINDER -> {
                if (matchNo < 0) return
                val strings = LiveSyncCore.strings(context)
                val body = LiveSyncCore.reminderBody(context, matchNo) ?: return
                NotificationHelper.notifyOnce(
                    context,
                    "start_$matchNo",
                    100000 + matchNo,
                    strings.matchStarting,
                    body,
                )
            }
            ACTION_START_LIVE -> {
                val serviceIntent = Intent(context, LiveMatchService::class.java)
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                } catch (_: Exception) {
                    // Si el sistema bloquea el arranque en background, el worker
                    // periódico sigue cubriendo las notificaciones.
                }
            }
        }
    }

    companion object {
        const val ACTION_REMINDER = "com.ever.mundial2026.action.REMINDER"
        const val ACTION_START_LIVE = "com.ever.mundial2026.action.START_LIVE"
        const val EXTRA_MATCH_NO = "match_no"
    }
}
