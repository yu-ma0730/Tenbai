package com.tenbai.futureclock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences("futureclock", Context.MODE_PRIVATE)
            val targetMs = prefs.getLong("alert_time_ms", -1L)
            val threshold = prefs.getInt("threshold", 10)
            val targetDate = prefs.getString("target_date", "") ?: ""
            val daysLeft = prefs.getInt("days_left", 0)

            if (targetMs > System.currentTimeMillis()) {
                AlarmHelper.schedule(context, targetMs, threshold, targetDate, daysLeft)
            }
        }
    }
}
