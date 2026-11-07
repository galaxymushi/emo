package com.emoassistant.emo

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

data class EmoNotification(
    val app: String,
    val packageName: String,
    val title: String,
    val text: String,
    val time: Long
)

object EmoNotificationStore {
    private val items = LinkedHashMap<String, EmoNotification>()
    private const val MAX = 40

    @Synchronized
    fun put(key: String, item: EmoNotification) {
        items[key] = item
        while (items.size > MAX) {
            val oldest = items.entries.firstOrNull() ?: break
            items.remove(oldest.key)
        }
    }

    @Synchronized
    fun remove(key: String) {
        items.remove(key)
    }

    @Synchronized
    fun clear() {
        items.clear()
    }

    @Synchronized
    fun all(): List<EmoNotification> =
        items.values.sortedByDescending { it.time }

    fun isEnabled(context: Context): Boolean {
        val expected = ComponentName(context, EmoNotificationListener::class.java)
            .flattenToString()
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        return enabled.split(':').any { it.equals(expected, true) }
    }
}

class EmoNotificationListener : NotificationListenerService() {

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
    }

    override fun onListenerDisconnected() {
        if (instance === this) instance = null
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn?.notification ?: return
        val packageName = sbn.packageName ?: return
        if (packageName == applicationContext.packageName) return

        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT))?.toString().orEmpty()
        if (title.isBlank() && text.isBlank()) return
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        val app = try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            packageName
        }

        EmoNotificationStore.put(
            sbn.key ?: "$packageName:$title",
            EmoNotification(app, packageName, title, text, sbn.postTime)
        )
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        val key = sbn?.key ?: return
        EmoNotificationStore.remove(key)
    }

    companion object {
        @Volatile
        var instance: EmoNotificationListener? = null
    }
}
