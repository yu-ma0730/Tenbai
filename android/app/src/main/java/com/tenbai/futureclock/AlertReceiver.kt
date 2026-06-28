package com.tenbai.futureclock

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat

class AlertReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "absence_alert"
        const val EXTRA_DAYS_LEFT = "days_left"
        const val EXTRA_THRESHOLD = "threshold"
        const val EXTRA_TARGET_DATE = "target_date"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val daysLeft = intent.getIntExtra(EXTRA_DAYS_LEFT, 0)
        val threshold = intent.getIntExtra(EXTRA_THRESHOLD, 10)
        val targetDate = intent.getStringExtra(EXTRA_TARGET_DATE) ?: ""

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(nm)

        val openIntent = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val (title, body) = if (daysLeft >= threshold) {
            "📋 欠勤登録の締切が近づいています" to
                    "${targetDate}の欠勤登録締切まであと${daysLeft - threshold + 1}日です。早めに登録してください。"
        } else {
            "⚠️ 欠勤登録期限切れ" to
                    "${targetDate}の欠勤は当日欠勤扱いになります（登録期限超過）。"
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(openIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        nm.notify(System.currentTimeMillis().toInt(), notification)
    }

    private fun ensureChannel(nm: NotificationManager) {
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "欠勤アラート", NotificationManager.IMPORTANCE_HIGH)
            )
        }
    }
}
