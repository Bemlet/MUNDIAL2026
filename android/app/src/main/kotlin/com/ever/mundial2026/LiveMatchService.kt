package com.ever.mundial2026

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Foreground service que sondea el scoreboard cada ~45 s mientras haya algún
 * partido en vivo, posteando goles/finales casi en tiempo real. Se autodetiene
 * cuando no hay partidos en vivo durante un margen de gracia, o tras un límite
 * de seguridad. Lo arranca [AlarmReceiver] al kickoff.
 */
class LiveMatchService : Service() {
    @Volatile
    private var running = false
    private var worker: Thread? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()
        if (!running) {
            running = true
            worker = Thread { loop() }.also { it.start() }
        }
        return START_STICKY
    }

    private fun startAsForeground() {
        val notification = NotificationHelper.trackingNotification(this)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(FGS_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(FGS_ID, notification)
            }
        } catch (_: Exception) {
            // Si el sistema rechaza el FGS, abortamos sin crashear.
            running = false
            stopSelf()
        }
    }

    private fun loop() {
        val startedAt = System.currentTimeMillis()
        var emptyChecks = 0
        while (running) {
            val anyLive = try {
                LiveSyncCore.run(applicationContext)
            } catch (_: Exception) {
                true // ante error de red no cortamos: reintentamos
            }

            if (anyLive) {
                emptyChecks = 0
            } else {
                emptyChecks++
                if (emptyChecks >= MAX_EMPTY_CHECKS) break
            }

            if (System.currentTimeMillis() - startedAt > MAX_LIFETIME_MS) break

            var slept = 0L
            while (running && slept < POLL_INTERVAL_MS) {
                try {
                    Thread.sleep(SLEEP_STEP_MS)
                } catch (_: InterruptedException) {
                    break
                }
                slept += SLEEP_STEP_MS
            }
        }
        running = false
        stopForegroundCompat()
        stopSelf()
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    override fun onDestroy() {
        running = false
        worker?.interrupt()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val FGS_ID = 990001
        private const val POLL_INTERVAL_MS = 45_000L
        private const val SLEEP_STEP_MS = 1_000L

        // ~4 min de gracia sin partidos en vivo antes de cortar (evita cortar
        // justo en el kickoff antes de que ESPN marque el partido como "in").
        private const val MAX_EMPTY_CHECKS = 5

        // Tope de seguridad: nunca correr más de 4 h seguidas.
        private const val MAX_LIFETIME_MS = 4 * 60 * 60 * 1000L
    }
}
