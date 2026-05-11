package com.metaxperts.order_booking_app

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.*
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.*
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class FloatingBubbleService : Service() {

    companion object {
        private const val TAG = "FloatingBubble"
        private const val NOTIFICATION_ID = 9999
        private const val CHANNEL_ID = "floating_bubble_channel"

        private var instance: FloatingBubbleService? = null

        fun start(context: Context) {
            android.util.Log.d(TAG, "start() called")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
                android.util.Log.e(TAG, "Cannot start - overlay permission denied")
                return
            }
            val intent = Intent(context, FloatingBubbleService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            android.util.Log.d(TAG, "stop() called")
            instance?.stopSelf()
            context.stopService(Intent(context, FloatingBubbleService::class.java))
        }

        fun isRunning(): Boolean = instance != null
    }

    private lateinit var windowManager: WindowManager
    private lateinit var bubbleContainer: LinearLayout
    private lateinit var appIcon: ImageView
    private lateinit var timeText: TextView

    private var layoutParams: WindowManager.LayoutParams? = null
    private var isDragging = false
    private var startX = 0
    private var startY = 0
    private val handler = Handler(Looper.getMainLooper())
    private var isDestroyed = false

    override fun onCreate() {
        super.onCreate()
        android.util.Log.d(TAG, "✅ onCreate() called")
        instance = this
        isDestroyed = false
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        createBubbleWithLogo()
        registerReceivers()
        startTimeUpdater()
        checkAndStartLocationService()
        android.util.Log.d(TAG, "✅ onCreate() completed")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d(TAG, "✅ onStartCommand() called")
        handler.postDelayed({
            showBubble()
        }, 500)
        return START_STICKY
    }

    private fun checkAndStartLocationService() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
            if (!isClockedIn) return

            val userId = prefs.getString("flutter.userId", "") ?: return
            LocationMonitorService.start(
                this,
                userId = userId,
                bookerName = prefs.getString("flutter.userName", "") ?: "",
                designation = prefs.getString("flutter.userDesignation", "") ?: "",
                companyCode = prefs.getString("flutter.companyCode", "") ?: ""
            )
        } catch (e: Exception) {}
    }

    private fun createBubbleWithLogo() {
        try {
            android.util.Log.d(TAG, "createBubbleWithLogo() started")

            // Create container layout
            bubbleContainer = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(dpToPx(8), dpToPx(8), dpToPx(8), dpToPx(8))

                // Circle background
                background = object : android.graphics.drawable.Drawable() {
                    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = Color.parseColor("#2196F3")
                        style = Paint.Style.FILL
                    }

                    override fun draw(canvas: Canvas) {
                        val cx = bounds.width() / 2f
                        val cy = bounds.height() / 2f
                        val radius = Math.min(cx, cy)
                        canvas.drawCircle(cx, cy, radius, paint)
                    }

                    override fun setAlpha(alpha: Int) {}
                    override fun setColorFilter(colorFilter: ColorFilter?) {}
                    override fun getOpacity(): Int = PixelFormat.OPAQUE
                }
            }

            // App Logo Icon
            appIcon = ImageView(this).apply {
                layoutParams = LinearLayout.LayoutParams(dpToPx(32), dpToPx(32))
                setImageResource(R.mipmap.ic_launcher)  // Your app logo
                scaleType = ImageView.ScaleType.CENTER_CROP
            }

            // Time Text (hidden initially)
            timeText = TextView(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = dpToPx(2) }
                text = "00:00"
                textSize = 10f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                visibility = View.GONE
            }

            bubbleContainer.addView(appIcon)
            bubbleContainer.addView(timeText)

            // Touch listener for drag and click
            bubbleContainer.setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        startX = event.rawX.toInt()
                        startY = event.rawY.toInt()
                        isDragging = false
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val deltaX = event.rawX.toInt() - startX
                        val deltaY = event.rawY.toInt() - startY
                        if (Math.abs(deltaX) > 10 || Math.abs(deltaY) > 10) {
                            isDragging = true
                            layoutParams?.let { params ->
                                params.x = (params.x + deltaX).coerceIn(0, getScreenWidth() - params.width)
                                params.y = (params.y + deltaY).coerceIn(0, getScreenHeight() - params.height)
                                try {
                                    windowManager.updateViewLayout(bubbleContainer, params)
                                } catch (e: Exception) {}
                                startX = event.rawX.toInt()
                                startY = event.rawY.toInt()
                            }
                        }
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!isDragging) {
                            reopenApp()
                        }
                        false
                    }
                    else -> false
                }
            }

            // Window parameters
            layoutParams = WindowManager.LayoutParams().apply {
                type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    WindowManager.LayoutParams.TYPE_PHONE
                }
                flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
                format = PixelFormat.TRANSLUCENT
                width = dpToPx(56)
                height = dpToPx(56)
                gravity = Gravity.TOP or Gravity.START
                x = 20
                y = dpToPx(100)
            }

            windowManager.addView(bubbleContainer, layoutParams)
            android.util.Log.d(TAG, "✅ Bubble with logo added")

        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error creating bubble: ${e.message}")
        }
    }

    private fun reopenApp() {
        try {
            android.util.Log.d(TAG, "Bubble tapped - Reopening app")
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("from_bubble", true)
            }
            launchIntent?.let { startActivity(it) }
        } catch (e: Exception) {}
    }

    fun showBubble() {
        try {
            android.util.Log.d(TAG, "showBubble() called")
            if (!isDestroyed && bubbleContainer != null) {
                bubbleContainer.visibility = View.VISIBLE
                android.util.Log.d(TAG, "✅ Bubble shown")
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "showBubble failed: ${e.message}")
        }
    }

    fun hideBubble() {
        try {
            android.util.Log.d(TAG, "hideBubble() called")
            if (!isDestroyed && bubbleContainer != null) {
                bubbleContainer.visibility = View.GONE
                android.util.Log.d(TAG, "✅ Bubble hidden")
            }
        } catch (e: Exception) {}
    }

    // ✅ CLOSE BUBBLE COMPLETELY - Called on ClockOut
    fun closeBubble() {
        try {
            android.util.Log.d(TAG, "closeBubble() called - Stopping service completely")
            isDestroyed = true
            if (bubbleContainer != null && bubbleContainer.isAttachedToWindow) {
                windowManager.removeViewImmediate(bubbleContainer)
            }
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        } catch (e: Exception) {
            android.util.Log.e(TAG, "closeBubble failed: ${e.message}")
        }
    }

    private fun updateTimeDisplay() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
            val elapsedTime = prefs.getString("flutter.elapsed_time", "00:00:00") ?: "00:00:00"

            if (!isDestroyed && timeText != null && bubbleContainer != null) {
                if (isClockedIn) {
                    // Show time, hide icon (or keep icon small)
                    var displayTime = elapsedTime
                    val secondColon = elapsedTime.indexOf(":", elapsedTime.indexOf(":") + 1)
                    if (secondColon > 0) {
                        displayTime = elapsedTime.substring(0, secondColon)
                    }
                    timeText.text = displayTime
                    timeText.visibility = View.VISIBLE
                    appIcon.visibility = View.VISIBLE

                    // Green color when active
                    (bubbleContainer.background as? android.graphics.drawable.Drawable)?.let {
                        // Update color to green
                        val paint = Paint().apply { color = Color.parseColor("#4CAF50") }
                    }
                } else {
                    // Show only icon, no time
                    timeText.visibility = View.GONE
                    appIcon.visibility = View.VISIBLE
                }
            }
        } catch (e: Exception) {}
    }

    private fun startTimeUpdater() {
        handler.post(object : Runnable {
            override fun run() {
                if (!isDestroyed) {
                    updateTimeDisplay()
                    handler.postDelayed(this, 1000)
                }
            }
        })
    }

    private fun registerReceivers() {
        try {
            val filter = IntentFilter().apply {
                addAction("com.metaxperts.SHOW_BUBBLE")
                addAction("com.metaxperts.HIDE_BUBBLE")
                addAction("com.metaxperts.CLOSE_BUBBLE")  // ✅ NEW: Close bubble action
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, RECEIVER_EXPORTED)
            } else {
                registerReceiver(receiver, filter)
            }
            android.util.Log.d(TAG, "✅ Receivers registered")
        } catch (e: Exception) {}
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.metaxperts.SHOW_BUBBLE" -> showBubble()
                "com.metaxperts.HIDE_BUBBLE" -> hideBubble()
                "com.metaxperts.CLOSE_BUBBLE" -> closeBubble()  // ✅ NEW
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "BookIT",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("BookIT")
            .setContentText("Tracking active")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun dpToPx(dp: Int): Int = (dp * resources.displayMetrics.density).toInt()
    private fun getScreenWidth(): Int = resources.displayMetrics.widthPixels
    private fun getScreenHeight(): Int = resources.displayMetrics.heightPixels

    override fun onDestroy() {
        super.onDestroy()
        android.util.Log.d(TAG, "onDestroy() called")
        isDestroyed = true
        try {
            if (bubbleContainer != null && bubbleContainer.isAttachedToWindow) {
                windowManager.removeViewImmediate(bubbleContainer)
            }
        } catch (e: Exception) {}
        try {
            unregisterReceiver(receiver)
        } catch (e: Exception) {}
        instance = null
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        android.util.Log.d(TAG, "onTaskRemoved() - App removed from recents")
        showBubble()
        checkAndStartLocationService()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}