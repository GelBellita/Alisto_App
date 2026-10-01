package com.example.alisto_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ALARM_CHANNEL = "alisto/alarm"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Emergency pushes (see the Pi's firestore_backend.py
        // send_emergency_push()) target this exact channel ID so they
        // arrive as a high-priority heads-up notification, instead of
        // Android's generic silent default channel. Must be created
        // before the first matching notification arrives, or Android
        // silently falls back to default behavior for it. Uses the
        // device's own ALARM tone (not the quiet default notification
        // sound) on the ALARM audio stream, so a background/killed-app
        // push still rings loud like a real emergency alert.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
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
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            // Notification channels are immutable once created -- an
            // earlier install of this app (before this file added a
            // custom sound) already created "emergency_alerts" with
            // Android's silent-by-default settings, and simply calling
            // createNotificationChannel() again would be a no-op against
            // that existing channel. Deleting it first forces a clean
            // recreate with the alarm sound below every launch.
            manager.deleteNotificationChannel("emergency_alerts")
            manager.createNotificationChannel(channel)
        }
    }

    // Lets the Dart side (see lib/services/alarm_service.dart) start/stop
    // the SAME EmergencyAlarmService (continuous vibration + looping
    // alarm tone, capped at 3 minutes) used for background/killed-state
    // pushes -- one implementation for every app state, instead of a
    // separate MediaPlayer-only loop that only covered the foreground
    // case and had no vibration.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val title = call.argument<String>("title") ?: "ALISTO Emergency Alert"
                    val body = call.argument<String>("body") ?: "Please check immediately."
                    val intent = Intent(this, EmergencyAlarmService::class.java).apply {
                        putExtra(EmergencyAlarmService.EXTRA_TITLE, title)
                        putExtra(EmergencyAlarmService.EXTRA_BODY, body)
                    }
                    ContextCompat.startForegroundService(this, intent)
                    result.success(null)
                }
                "stop" -> {
                    val stopIntent = Intent(this, EmergencyAlarmService::class.java).apply {
                        action = EmergencyAlarmService.ACTION_STOP
                    }
                    startService(stopIntent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
