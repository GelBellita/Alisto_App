package com.example.alisto_app

import android.content.Intent
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/// Native FCM receiver, completely independent of the Flutter engine --
/// this is what makes EmergencyAlarmService start reliably even when the
/// app is fully killed (no Dart isolate running at all, so a MethodChannel
/// call from a Dart background handler has nothing on the native side
/// scoped to reach). The firebase_messaging plugin's own service still
/// runs separately alongside this one and keeps onMessage/
/// onBackgroundMessage working as before for anything else the Dart side
/// wants to do with a push -- the Android FCM SDK supports multiple
/// FirebaseMessagingService subclasses coexisting, each independently
/// receiving every message, so this doesn't replace or interfere with it.
///
/// firestore_backend.py's send_emergency_push() sends DATA-ONLY messages
/// (no top-level `notification` field) specifically so this always fires
/// -- a `notification` payload would make Android auto-display a system
/// tray entry itself whenever backgrounded/killed and never hand the
/// message to app code at all.
class AlistoMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        if (message.data["type"] != "emergency") return

        val intent = Intent(this, EmergencyAlarmService::class.java).apply {
            putExtra(EmergencyAlarmService.EXTRA_TITLE, message.data["title"] ?: "ALISTO Emergency Alert")
            putExtra(EmergencyAlarmService.EXTRA_BODY, message.data["body"] ?: "Please check immediately.")
        }
        ContextCompat.startForegroundService(this, intent)
    }
}
