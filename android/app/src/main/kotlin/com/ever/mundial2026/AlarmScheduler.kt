package com.ever.mundial2026

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Programa, por partido, dos alarmas con AlarmManager:
 *  - Recordatorio (inexacto) a kickoff − 15 min → notificación "por comenzar".
 *  - Arranque del seguimiento en vivo (exacto si está permitido) a kickoff →
 *    inicia [LiveMatchService]. La alarma exacta es la excepción que permite
 *    arrancar un foreground service con la app cerrada en Android 12+.
 *
 * Idempotente: usar FLAG_UPDATE_CURRENT permite reprogramar sin duplicar.
 */
object AlarmScheduler {
    private const val REMINDER_LEAD_MS = 15 * 60 * 1000L
    private const val REMINDER_REQUEST_BASE = 700000
    private const val START_REQUEST_BASE = 800000

    fun scheduleAll(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val now = System.currentTimeMillis()
        val matches = try {
            LiveSyncCore.matchInfos(context)
        } catch (_: Exception) {
            return
        }

        for (match in matches) {
            val kickoff = match.dateMillis
            if (kickoff <= 0L) continue

            val reminderAt = kickoff - REMINDER_LEAD_MS
            if (reminderAt > now) {
                scheduleInexact(
                    context,
                    alarmManager,
                    reminderAt,
                    reminderPendingIntent(context, match.no),
                )
            }

            if (kickoff > now) {
                scheduleStart(
                    context,
                    alarmManager,
                    kickoff,
                    startPendingIntent(context, match.no),
                )
            }
        }
    }

    private fun scheduleInexact(
        context: Context,
        alarmManager: AlarmManager,
        triggerAt: Long,
        pendingIntent: PendingIntent,
    ) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        } catch (_: Exception) {
        }
    }

    private fun scheduleStart(
        context: Context,
        alarmManager: AlarmManager,
        triggerAt: Long,
        pendingIntent: PendingIntent,
    ) {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else if (canScheduleExact(alarmManager)) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else {
                // Sin permiso de alarma exacta: cae a inexacta (puede no arrancar
                // el servicio con la app cerrada, pero no rompe nada).
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        } catch (_: SecurityException) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        } catch (_: Exception) {
        }
    }

    fun canScheduleExact(alarmManager: AlarmManager): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    private fun reminderPendingIntent(context: Context, matchNo: Int): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_REMINDER
            putExtra(AlarmReceiver.EXTRA_MATCH_NO, matchNo)
        }
        return PendingIntent.getBroadcast(context, REMINDER_REQUEST_BASE + matchNo, intent, flags())
    }

    private fun startPendingIntent(context: Context, matchNo: Int): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_START_LIVE
            putExtra(AlarmReceiver.EXTRA_MATCH_NO, matchNo)
        }
        return PendingIntent.getBroadcast(context, START_REQUEST_BASE + matchNo, intent, flags())
    }

    private fun flags(): Int {
        return PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
    }
}
