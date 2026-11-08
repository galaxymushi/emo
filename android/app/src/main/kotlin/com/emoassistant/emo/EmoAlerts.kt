package com.emoassistant.emo

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build

object EmoAlerts {
    private const val REPLIES_CHANNEL = "emo_replies"
    private const val UPDATES_CHANNEL = "emo_updates"
    private const val REPLY_ID = 7301
    private const val UPDATE_ID = 7302

    fun ensureChannels(context: Context) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(REPLIES_CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    REPLIES_CHANNEL,
                    "Emo replies",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "Answers that arrive while Emo is in the background" }
            )
        }
        if (nm.getNotificationChannel(UPDATES_CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    UPDATES_CHANNEL,
                    "Emo updates",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "New Emo APK releases from GitHub" }
            )
        }
    }

    fun postReply(context: Context, title: String, body: String): Boolean {
        if (body.isBlank() || !canPost(context)) return false
        ensureChannels(context)
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            } ?: return false
        val contentIntent = PendingIntent.getActivity(
            context,
            101,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = Notification.Builder(context, REPLIES_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle(title.ifBlank { "Emo" })
            .setContentText(body.take(160))
            .setStyle(Notification.BigTextStyle().bigText(body.take(500)))
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
        return post(context, REPLY_ID, builder)
    }

    fun postUpdate(context: Context, version: String, url: String, notes: String): Boolean {
        if (url.isBlank() || !canPost(context)) return false
        ensureChannels(context)
        val open = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            102,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = Notification.Builder(context, UPDATES_CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Emo ${version.ifBlank { "update" }} is available")
            .setContentText("Tap to download the latest APK")
            .setStyle(
                Notification.BigTextStyle().bigText(
                    if (notes.isBlank()) "Tap to download the latest APK."
                    else notes.take(500)
                )
            )
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
        return post(context, UPDATE_ID, builder)
    }

    private fun post(context: Context, id: Int, builder: Notification.Builder): Boolean = try {
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(id, builder.build())
        true
    } catch (e: SecurityException) {
        false
    }

    private fun canPost(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
}
