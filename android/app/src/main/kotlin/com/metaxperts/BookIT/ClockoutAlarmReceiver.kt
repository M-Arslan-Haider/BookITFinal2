//package com.metaxperts.order_booking_app
//
//// ══════════════════════════════════════════════════════════════════════════════
//// ClockoutAlarmReceiver.kt  — ALL IN ONE FILE
////
//// FILE PATH: android/app/src/main/kotlin/com/metaxperts/order_booking_app/
////
//// Is file mein 2 classes hain:
////   1. ClockoutAlarmReceiver  — 8 PM par AlarmManager se fire hota hai
////   2. ClockoutRingtoneService — Foreground service, ringtone loop mein bajata hai
////
//// FLOW:
////   8 PM → ClockoutAlarmReceiver.onReceive()
////              → isClockedIn check
////              → ClockoutRingtoneService start (ringtone + notification)
////   ClockOut → stopEverything() → service band → ringtone band → notifications cancel
//// ══════════════════════════════════════════════════════════════════════════════
//
//import android.app.AlarmManager
//import android.app.Notification
//import android.app.NotificationChannel
//import android.app.NotificationManager
//import android.app.PendingIntent
//import android.app.Service
//import android.content.BroadcastReceiver
//import android.content.Context
//import android.content.Intent
//import android.content.SharedPreferences
//import android.media.AudioAttributes
//import android.media.AudioManager
//import android.media.MediaPlayer
//import android.content.pm.ServiceInfo
//import android.media.RingtoneManager
//import android.net.Uri
//import android.os.Build
//import android.os.Handler
//import android.os.IBinder
//import android.os.Looper
//import android.os.PowerManager
//import android.os.VibrationEffect
//import android.os.Vibrator
//import android.os.VibratorManager
//import android.util.Log
//import androidx.core.app.NotificationCompat
//import androidx.core.app.NotificationManagerCompat
//import java.util.Calendar
//
//// ══════════════════════════════════════════════════════════════════════════════
//// CLASS 1: ClockoutAlarmReceiver — AlarmManager se 8 PM par fire hota hai
//// ══════════════════════════════════════════════════════════════════════════════
//class ClockoutAlarmReceiver : BroadcastReceiver() {
//
//    companion object {
//        private const val TAG = "ClockoutAlarm"
//
//        private const val PREFS_NAME     = "FlutterSharedPreferences"
//        private const val KEY_CLOCKED    = "flutter.isClockedIn"
//        private const val ALARM_REQ_CODE = 7001
//
//        fun scheduleDaily8PMAlarm(context: Context) {
//            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
//            val pi = PendingIntent.getBroadcast(
//                context, ALARM_REQ_CODE,
//                Intent(context, ClockoutAlarmReceiver::class.java),
//                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//            )
//            val calendar = Calendar.getInstance().apply {
//                set(Calendar.HOUR_OF_DAY, 20)
//                set(Calendar.MINUTE, 0)
//                set(Calendar.SECOND, 0)
//                set(Calendar.MILLISECOND, 0)
//            }
//            if (calendar.timeInMillis <= System.currentTimeMillis())
//                calendar.add(Calendar.DAY_OF_YEAR, 1)
//
//            try {
//                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
//                    if (alarmManager.canScheduleExactAlarms())
//                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pi)
//                    else
//                        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pi)
//                } else {
//                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pi)
//                }
//                Log.d(TAG, "✅ 8PM alarm scheduled")
//            } catch (e: Exception) {
//                Log.e(TAG, "❌ Alarm set failed: ${e.message}")
//            }
//        }
//
//        fun cancelAlarm(context: Context) {
//            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
//            val pi = PendingIntent.getBroadcast(
//                context, ALARM_REQ_CODE,
//                Intent(context, ClockoutAlarmReceiver::class.java),
//                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//            )
//            alarmManager.cancel(pi)
//            Log.d(TAG, "🛑 Alarm cancelled")
//        }
//
//        fun startRingtoneService(context: Context) {
//            val intent = Intent(context, ClockoutRingtoneService::class.java).apply {
//                action = ClockoutRingtoneService.ACTION_START
//            }
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
//                context.startForegroundService(intent)
//            else
//                context.startService(intent)
//        }
//
//        fun stopRingtoneService(context: Context) {
//            context.startService(
//                Intent(context, ClockoutRingtoneService::class.java).apply {
//                    action = ClockoutRingtoneService.ACTION_STOP
//                }
//            )
//        }
//
//        // ← Flutter ClockOut par yeh call hoga (MainActivity via MethodChannel)
//        fun stopEverything(context: Context) {
//            cancelAlarm(context)
//            stopRingtoneService(context)
//            Log.d(TAG, "🛑 All clockout reminders stopped")
//        }
//    }
//
//    override fun onReceive(context: Context, intent: Intent) {
//        Log.d(TAG, "⏰ 8PM alarm fired!")
//
//        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
//        val wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ClockoutAlarm::WakeLock")
//        wl.acquire(15_000L)
//
//        try {
//            val prefs: SharedPreferences =
//                context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//            val isClockedIn = prefs.getBoolean(KEY_CLOCKED, false)
//            Log.d(TAG, "isClockedIn = $isClockedIn")
//
//            if (isClockedIn) {
//                startRingtoneService(context)
//                Log.d(TAG, "✅ Ringtone started")
//            } else {
//                Log.d(TAG, "⏸️ Not clocked in — skipped")
//            }
//            // Har case mein kal ka alarm set karo
//            scheduleDaily8PMAlarm(context)
//        } finally {
//            wl.release()
//        }
//    }
//}
//
//
//// ══════════════════════════════════════════════════════════════════════════════
//// CLASS 2: ClockoutRingtoneService — Foreground service, ringtone bajata rahe
//// ══════════════════════════════════════════════════════════════════════════════
//class ClockoutRingtoneService : Service() {
//
//    companion object {
//        private const val TAG = "ClockoutRingtone"
//
//        const val ACTION_START = "ACTION_CLOCKOUT_RINGTONE_START"
//        const val ACTION_STOP  = "ACTION_CLOCKOUT_RINGTONE_STOP"
//
//        private const val CHANNEL_ID   = "clockout_ringtone_channel"
//        private const val CHANNEL_NAME = "Clockout Bell"
//        private const val NOTIF_ID_FG  = 7767
//        private const val NOTIF_ID_RPT = 7768
//        private const val REPEAT_MS    = 2 * 60 * 1000L // har 2 min popup
//    }
//
//    private var mediaPlayer:    MediaPlayer? = null
//    private var wakeLock:       PowerManager.WakeLock? = null
//    private val handler       = Handler(Looper.getMainLooper())
//    private var repeatRunnable: Runnable? = null
//
//    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
//        return when (intent?.action) {
//            ACTION_START -> { boot(); START_STICKY }
//            ACTION_STOP  -> { stopEverything(); stopSelf(); START_NOT_STICKY }
//            else         -> { boot(); START_STICKY } // OS restart
//        }
//    }
//
//    private fun boot() {
//        createChannel()
//        startForegroundNotification()
//        acquireWakeLock()
//        startRingtone()
//        startRepeatReminder()
//    }
//
//    // ── Ongoing foreground notification ───────────────────────────────────────
//    private fun startForegroundNotification() {
//        val pi = openAppPI(7010)
//        val notif: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
//            .setSmallIcon(android.R.drawable.ic_dialog_alert)
//            .setContentTitle("⏰ Clock Out Karein!")
//            .setContentText("Sham ke 8 baj gaye — Abhi Clock Out Karein")
//            .setStyle(NotificationCompat.BigTextStyle().bigText(
//                "⚠️ Aap ne abhi tak Clock Out nahi kiya!\n\n" +
//                        "BookIT Application kholen aur Clock Out karein.\n" +
//                        "Ghanti tab tak bajti rahegi jab tak Clock Out na karein."
//            ))
//            .setPriority(NotificationCompat.PRIORITY_MAX)
//            .setCategory(NotificationCompat.CATEGORY_ALARM)
//            .setOngoing(true)
//            .setAutoCancel(false)
//            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
//            .setFullScreenIntent(pi, true)
//            .addAction(android.R.drawable.ic_menu_send, "📱 App Kholen aur Clock Out Karein", pi)
//            .setContentIntent(pi)
//            .build()
//        // Ab hai (API 29+ ke liye type specify karna zaroori hai):
//        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
//            startForeground(NOTIF_ID_FG, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
//        } else {
//            startForeground(NOTIF_ID_FG, notif)
//        }
//    }
//
//    // ── Default alarm ringtone — loop mein ────────────────────────────────────
//    private fun startRingtone() {
//        try {
//            stopRingtone()
//            val uri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
//                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
//            mediaPlayer = MediaPlayer().apply {
//                setAudioAttributes(
//                    AudioAttributes.Builder()
//                        .setUsage(AudioAttributes.USAGE_ALARM)
//                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
//                        .setLegacyStreamType(AudioManager.STREAM_ALARM)
//                        .build()
//                )
//                setDataSource(applicationContext, uri)
//                isLooping = true
//                prepare()
//                start()
//            }
//            Log.d(TAG, "✅ Ringtone looping")
//        } catch (e: Exception) {
//            Log.e(TAG, "❌ Ringtone error: ${e.message}")
//            vibrate()
//        }
//    }
//
//    private fun stopRingtone() {
//        try { mediaPlayer?.apply { if (isPlaying) stop(); release() }; mediaPlayer = null }
//        catch (e: Exception) { Log.e(TAG, "stopRingtone: ${e.message}") }
//    }
//
//    // ── Har 2 minute baad ek aur popup ────────────────────────────────────────
//    private fun startRepeatReminder() {
//        repeatRunnable?.let { handler.removeCallbacks(it) }
//        repeatRunnable = object : Runnable {
//            override fun run() {
//                vibrate()
//                showRepeatPopup()
//                handler.postDelayed(this, REPEAT_MS)
//            }
//        }
//        handler.postDelayed(repeatRunnable!!, REPEAT_MS)
//    }
//
//    private fun showRepeatPopup() {
//        val pi = openAppPI(7011)
//        try {
//            NotificationManagerCompat.from(this).notify(
//                NOTIF_ID_RPT,
//                NotificationCompat.Builder(this, CHANNEL_ID)
//                    .setSmallIcon(android.R.drawable.ic_dialog_alert)
//                    .setContentTitle("⚠️ Abhi Tak Clock Out Nahi Kiya!")
//                    .setContentText("Fori App Kholen aur Clock Out Karein")
//                    .setPriority(NotificationCompat.PRIORITY_MAX)
//                    .setCategory(NotificationCompat.CATEGORY_ALARM)
//                    .setAutoCancel(false)
//                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
//                    .setFullScreenIntent(pi, true)
//                    .addAction(android.R.drawable.ic_menu_send, "📱 Clock Out Karein", pi)
//                    .setContentIntent(pi)
//                    .build()
//            )
//        } catch (e: SecurityException) { Log.e(TAG, "❌ ${e.message}") }
//    }
//
//    private fun vibrate() {
//        try {
//            val pattern = longArrayOf(0, 500, 200, 500, 200, 500)
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
//                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
//                vm.defaultVibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
//            } else {
//                @Suppress("DEPRECATION")
//                val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
//                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
//                    v.vibrate(VibrationEffect.createWaveform(pattern, -1))
//                else
//                    @Suppress("DEPRECATION") v.vibrate(pattern, -1)
//            }
//        } catch (e: Exception) { Log.e(TAG, "Vibrate: ${e.message}") }
//    }
//
//    private fun acquireWakeLock() {
//        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
//            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ClockoutRingtone::WakeLock")
//            .apply { acquire(60 * 60 * 1000L) }
//    }
//
//    private fun stopEverything() {
//        repeatRunnable?.let { handler.removeCallbacks(it) }
//        repeatRunnable = null
//        stopRingtone()
//        wakeLock?.apply { if (isHeld) release() }
//        wakeLock = null
//        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIF_ID_RPT)
//        stopForeground(STOP_FOREGROUND_REMOVE)
//        Log.d(TAG, "🛑 Everything stopped")
//    }
//
//    private fun openAppPI(reqCode: Int): PendingIntent =
//        PendingIntent.getActivity(
//            this, reqCode,
//            Intent(this, MainActivity::class.java).apply {
//                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
//                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
//                        Intent.FLAG_ACTIVITY_SINGLE_TOP
//                putExtra("from_clockout_notification", true)
//            },
//            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//        )
//
//    private fun createChannel() {
//        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
//        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
//        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
//            nm.createNotificationChannel(
//                NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
//                    enableVibration(true); enableLights(true); setSound(null, null)
//                }
//            )
//        }
//    }
//
//    override fun onBind(intent: Intent?): IBinder? = null
//    override fun onDestroy() { super.onDestroy(); stopEverything() }
//}