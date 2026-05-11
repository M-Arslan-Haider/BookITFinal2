package com.metaxperts.order_booking_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

class FloatingBubbleRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
            return
        }

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)

        if (isClockedIn && !FloatingBubbleService.isRunning()) {
            FloatingBubbleService.start(context)
        }
    }
}