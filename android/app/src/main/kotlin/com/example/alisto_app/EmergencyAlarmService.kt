package com.example.alisto_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat

/// Runs a real "keep buzzing until someone notices" alarm -- continuous
/// vibration + looping alarm tone, capped at DURATION_MS -- REGARDLESS of
/// whether the app is open, backgrounded, or fully killed. A plain
/// notification-channel vibration/sound (what MainActivity.kt's channel
/// setup alone provides) only ever fires ONCE per notification and can't
/// do this; a genuine foreground Service is Android's only way to keep
/// something running and unmissable across all three app states, the
/// same mechanism incoming-call and alarm-clock apps use.
///
/// Started from two places: MainActivity's MethodChannel (when a push
/// arrives while the app is in the foreground -- see
/// AlarmService.startForegroundAlarm() on the Dart side) and directly
/// from AlistoMessagingService's FCM receiver (background/killed states,
/// where there is no running Flutter engine to call a MethodChannel on
/// at all). Both paths converge here so the behavior is identical either
/// way.
class EmergencyAlarmService : Service() {

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val ACTION_STOP = "com.example.alisto_app.STOP_ALARM"
        const val DURATION_MS = 3 * 60 * 1000L // 3 minutes
        const val NOTIFICATION_ID = 4771
    }

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private val stopHandler = Handler(Looper.getMainLooper())
    private val stopRunnable = Runnable { stopSelf() }

    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "ALISTO Emergency Alert"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: "Please check immediately."

        // Idempotent against being started more than once for the same
        // alert -- real testing showed FCM can deliver a message to more
        // than one native/Dart receiver in the same app process (see
        // AlistoMessagingService.kt's doc comment), each independently
        // calling startForegroundService() here. Without stopping any
        // previous sound/vibration first, the second call's MediaPlayer
        // silently overwrote the field reference, orphaning the first
        // one still playing -- which "OK, I saw this" (stopping only the
        // current reference) could never reach again.
        stopEverything()

        ensureNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification(title, body))
        startVibration()
        startAlarmSound()

        // Never buzz forever -- if genuinely nobody acknowledges it within
        // 3 minutes, stop on its own rather than draining the battery or
        // annoying the household indefinitely. A real "still not seen"
        // alert stays visible/queryable through the alert doc itself
        // (acknowledged: false), independent of this alarm's lifetime.
        stopHandler.removeCallbacks(stopRunnable)
        stopHandler.postDelayed(stopRunnable, DURATION_MS)

        return START_NOT_STICKY
    }

    /// This service can be the very first thing that runs after Android
    /// spawns a fresh process for a killed app (via AlistoMessagingService's
    /// FCM receiver) -- MainActivity.onCreate(), which normally creates the
    /// "emergency_alerts" channel, may never have run yet in that case.
    /// startForeground() posting to a channel that doesn't exist yet would
    /// otherwise fail/behave unpredictably. Check-then-create only (not
    /// MainActivity's delete-then-recreate, which is for forcing settings
    /// changes after an app update) -- this runs on every alarm trigger,
    /// so it must be cheap and never disturb an already-correct channel.
    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel("emergency_alerts") != null) return

        val alarmUri = RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val channel = NotificationChannel(
            "emergency_alerts",
            "Emergency Alerts",
            NotificationManager.IMPORTANCE_HIGH
        )
        channel.description = "Alerts from your Alisto device"
        channel.setSound(alarmUri, audioAttributes)
        channel.enableVibration(true)
        channel.vibrationPattern = longArrayOf(0, 500, 250, 500, 250, 500)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(title: String, body: String): Notification {
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val openAppPending = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, EmergencyAlarmService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, "emergency_alerts")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setContentIntent(openAppPending)
            .addAction(0, "I'm OK / Stop", stopPending)
            .build()
    }

    private fun startVibration() {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Buzz 800ms, pause 400ms, repeat from index 0 -- loops
            // indefinitely until cancel() is called (see stopEverything()).
            val pattern = longArrayOf(0, 800, 400)
            val effect = VibrationEffect.createWaveform(pattern, 0)
            vibrator?.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(longArrayOf(0, 800, 400), 0)
        }
    }

    private fun startAlarmSound() {
        try {
            val alarmUri = RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(this@EmergencyAlarmService, alarmUri)
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            // Best-effort -- vibration alone still gets attention even if
            // the sound fails to start for some reason.
        }
    }

    private fun stopEverything() {
        stopHandler.removeCallbacks(stopRunnable)
        vibrator?.cancel()
        vibrator = null
        mediaPlayer?.let {
            try {
                if (it.isPlaying) it.stop()
                it.release()
            } catch (e: Exception) {
            }
        }
        mediaPlayer = null
    }

    override fun onDestroy() {
        stopEverything()
        super.onDestroy()
    }
}
