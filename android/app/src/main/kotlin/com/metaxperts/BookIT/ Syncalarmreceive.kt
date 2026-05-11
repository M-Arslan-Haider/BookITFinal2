package com.metaxperts.order_booking_app

// ══════════════════════════════════════════════════════════════════════════════
// SyncAlarmReceiver.kt
//
// Yeh file android/app/src/main/kotlin/com/metaxperts/order_booking_app/ mein
// rakho — MainActivity.kt ke saath wali directory mein
//
// Kya karta hai:
//   - AlarmManager se EXACTLY har 15 minute baad fire hota hai
//   - App kill ho / background mein ho — dono cases mein kaam karta hai
//   - SharedPreferences se isClockedIn check karta hai
//   - Agar clocked in hai → Full Screen popup + normal notification dono show karta hai
//   - Full Screen notification = phone screen par popup aata hai "App kholain"
//   - "App Kholain" button click karne se app directly open ho jata hai
//
// IMPORTANT: AndroidManifest.xml mein yeh add karna zaroori hai (neeche guide hai)
// ══════════════════════════════════════════════════════════════════════════════

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class SyncAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID_NORMAL      = "sync_reminder_channel"
        private const val CHANNEL_ID_FULLSCREEN  = "sync_fullscreen_channel"
        private const val CHANNEL_NAME_NORMAL     = "Data Sync Reminder"
        private const val CHANNEL_NAME_FULLSCREEN = "Sync Popup Alert"
        private const val NOTIF_ID_NORMAL         = 8877
        private const val NOTIF_ID_FULLSCREEN     = 8878
        private const val ALARM_REQUEST_CODE      = 9001
        private const val INTERVAL_MS             = 15 * 60 * 1000L // 15 minutes

        // ── SharedPreferences key (Flutter stores with "flutter." prefix) ──
        private const val PREFS_NAME    = "FlutterSharedPreferences"
        private const val KEY_CLOCKED   = "flutter.isClockedIn"

        // ── Start 15-minute repeating alarm ──────────────────────────────
        fun startAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent       = Intent(context, SyncAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val triggerAt = System.currentTimeMillis() + INTERVAL_MS

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent
                    )
                } else {
                    // Fallback: inexact but still works
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent
                    )
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent
                )
            }

            android.util.Log.d("SyncAlarm", "✅ Next alarm set for 15 minutes")
        }

        // ── Stop / cancel alarm ───────────────────────────────────────────
        fun stopAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent       = Intent(context, SyncAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)

            // Also cancel notifications
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIF_ID_NORMAL)
            nm.cancel(NOTIF_ID_FULLSCREEN)

            android.util.Log.d("SyncAlarm", "🛑 Alarm cancelled")
        }
    }

    // ── Called every 15 minutes by AlarmManager ───────────────────────────
    override fun onReceive(context: Context, intent: Intent) {
        android.util.Log.d("SyncAlarm", "⏰ Alarm fired!")

        // Wake lock — phone screen off ho tab bhi kaam kare
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wl = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SyncAlarm::WakeLock"
        )
        wl.acquire(10_000L) // 10 seconds max

        try {
            val prefs: SharedPreferences = context.getSharedPreferences(
                PREFS_NAME, Context.MODE_PRIVATE
            )
            val isClockedIn = prefs.getBoolean(KEY_CLOCKED, false)

            android.util.Log.d("SyncAlarm", "isClockedIn=$isClockedIn")

            if (isClockedIn) {
                createNotificationChannels(context)
                showFullScreenPopup(context)    // ← Phone screen par popup
                showNormalNotification(context) // ← Notification bar mein bhi
                // ✅ Schedule next alarm (chain karta rahe)
                startAlarm(context)
            } else {
                android.util.Log.d("SyncAlarm", "⏸️ Not clocked in — alarm stopped")
                // User clocked out — alarm cancel
                stopAlarm(context)
            }
        } finally {
            wl.release()
        }
    }

    // ── Create notification channels ──────────────────────────────────────
    private fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Normal channel
        if (nm.getNotificationChannel(CHANNEL_ID_NORMAL) == null) {
            val ch = NotificationChannel(
                CHANNEL_ID_NORMAL,
                CHANNEL_NAME_NORMAL,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description    = "15 minute sync reminder"
                enableVibration(true)
                enableLights(true)
            }
            nm.createNotificationChannel(ch)
        }

        // Full screen channel — IMPORTANCE_HIGH zaroori hai popup ke liye
        if (nm.getNotificationChannel(CHANNEL_ID_FULLSCREEN) == null) {
            val ch = NotificationChannel(
                CHANNEL_ID_FULLSCREEN,
                CHANNEL_NAME_FULLSCREEN,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Sync popup when app is killed"
                enableVibration(true)
                enableLights(true)
            }
            nm.createNotificationChannel(ch)
        }
    }

    // ── Full Screen Intent — phone screen par popup ───────────────────────
    private fun showFullScreenPopup(context: Context) {
        // Intent to open MainActivity when button tapped
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("from_sync_notification", true)
        }

        val openAppPendingIntent = PendingIntent.getActivity(
            context,
            9002,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID_FULLSCREEN)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("⏰ ڈیٹا سنک کریں - BookIT")
            .setContentText("15 منٹ ہوگئے — ابھی ڈیٹا سنک کریں")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("آپ کا ڈیٹا سنک نہیں ہوا۔\nایپلیکیشن کھولیں اور ڈیٹا سنک کریں تاکہ آپ کا کام محفوظ رہے۔")
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            // ✅ "App Kholain" action button
            .addAction(
                android.R.drawable.ic_menu_send,
                "📱 ایپ کھولیں",
                openAppPendingIntent
            )
            // ✅ Full screen intent — screen lock par bhi popup aata hai
            .setFullScreenIntent(openAppPendingIntent, true)
            .setContentIntent(openAppPendingIntent)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(NOTIF_ID_FULLSCREEN, notification)
            android.util.Log.d("SyncAlarm", "✅ Full screen popup shown")
        } catch (e: SecurityException) {
            android.util.Log.e("SyncAlarm", "❌ Notification permission missing: ${e.message}")
        }
    }

    // ── Normal notification bar notification ──────────────────────────────
    private fun showNormalNotification(context: Context) {
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(
            context, 9003, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID_NORMAL)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle("⏰ ڈیٹا سنک کریں")
            .setContentText("BookIT ایپ کھولیں اور ڈیٹا سنک کریں")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .addAction(android.R.drawable.ic_menu_send, "ایپ کھولیں", pi)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(NOTIF_ID_NORMAL, notification)
        } catch (e: SecurityException) {
            android.util.Log.e("SyncAlarm", "❌ ${e.message}")
        }
    }
}