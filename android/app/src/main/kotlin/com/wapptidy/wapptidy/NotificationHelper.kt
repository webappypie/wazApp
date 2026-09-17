package com.wapptidy.wapptidy

/*
 * NotificationHelper.kt
 *
 * Manages notification channels, quiet hours suppression, and notification dispatch (REQ-SET-05).
 */

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.Calendar

object NotificationHelper {

    const val CHANNEL_STORAGE_ALERTS = wapptidy_storage_alerts
    const val CHANNEL_SCAN_REMINDERS = wapptidy_scan_reminders
    const val CHANNEL_WEEKLY_TIPS    = wapptidy_weekly_tips

    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val storageChannel = NotificationChannel(
                CHANNEL_STORAGE_ALERTS,
                Storage Alerts,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = Alerts when WhatsApp media consumes critical storage
            }

            val scanChannel = NotificationChannel(
                CHANNEL_SCAN_REMINDERS,
                Scan Reminders,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = Periodic reminders to review detected cleanup opportunities
            }

            val tipsChannel = NotificationChannel(
                CHANNEL_WEEKLY_TIPS,
                Weekly Hygiene Tips,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = Helpful tips to keep your device storage tidy
            }

            notificationManager.createNotificationChannels(listOf(storageChannel, scanChannel, tipsChannel))
        }
    }

    fun isQuietHours(
        calendar: Calendar = Calendar.getInstance(),
        startHour: Int = 22,
        endHour: Int = 8
    ): Boolean {
        val hour = calendar.get(Calendar.HOUR_OF_DAY)
        return if (startHour > endHour) {
            hour >= startHour || hour < endHour
        } else if (startHour < endHour) {
            hour in startHour until endHour
        } else {
            false
        }
    }

    fun showNotification(
        context: Context,
        id: Int,
        channelId: String,
        title: String,
        body: String,
        bypassQuietHours: Boolean = false
    ): Boolean {
        if (!bypassQuietHours && isQuietHours()) {
            return false
        }

        val notificationManager = NotificationManagerCompat.from(context)
        if (!notificationManager.areNotificationsEnabled()) {
            return false
        }

        createNotificationChannels(context)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(
                if (channelId == CHANNEL_STORAGE_ALERTS) NotificationCompat.PRIORITY_HIGH
                else NotificationCompat.PRIORITY_DEFAULT
            )
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        try {
            notificationManager.notify(id, builder.build())
            return true
        } catch (e: SecurityException) {
            return false
        }
    }
}
