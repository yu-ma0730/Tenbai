package com.tenbai.futureclock

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object AlarmHelper {

    private const val REQUEST_CODE = 1001

    fun schedule(
        context: Context,
        triggerAtMs: Long,
        threshold: Int,
        targetDate: String,
        daysLeft: Int
    ) {
        val intent = Intent(context, AlertReceiver::class.java).apply {
            putExtra(AlertReceiver.EXTRA_THRESHOLD, threshold)
            putExtra(AlertReceiver.EXTRA_TARGET_DATE, targetDate)
            putExtra(AlertReceiver.EXTRA_DAYS_LEFT, daysLeft)
        }
        val pi = PendingIntent.getBroadcast(
            context, REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
        } else {
            am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
        }
    }

    fun cancel(context: Context) {
        val intent = Intent(context, AlertReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            context, REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pi)
    }
}
