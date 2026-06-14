package com.ever.mundial2026

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Reprograma las alarmas y el worker periódico tras un reinicio del dispositivo
 * (las alarmas de AlarmManager se pierden al apagar).
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            NotificationHelper.createNotificationChannel(context)
            AlarmScheduler.scheduleAll(context)
            LiveSyncWorker.schedule(context)
        }
    }
}
