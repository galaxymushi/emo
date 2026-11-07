package com.emoassistant.emo

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.ComponentName
import android.content.Context
import android.graphics.Path
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent

class EmoAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        private var instance: EmoAccessibilityService? = null

        fun isEnabled(context: Context): Boolean {
            val expected = ComponentName(context, EmoAccessibilityService::class.java)
                .flattenToString()
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            return enabled.split(':').any { it.equals(expected, true) }
        }

        fun globalAction(action: String): Boolean {
            val service = instance ?: return false
            val id = when (action) {
                "back" -> GLOBAL_ACTION_BACK
                "home" -> GLOBAL_ACTION_HOME
                "recents" -> GLOBAL_ACTION_RECENTS
                "notifications" -> GLOBAL_ACTION_NOTIFICATIONS
                "quick_settings" -> GLOBAL_ACTION_QUICK_SETTINGS
                "lock" -> if (android.os.Build.VERSION.SDK_INT >= 28) GLOBAL_ACTION_LOCK_SCREEN else -1
                "screenshot" -> if (android.os.Build.VERSION.SDK_INT >= 30) GLOBAL_ACTION_TAKE_SCREENSHOT else -1
                else -> -1
            }
            if (id == -1) return false
            return service.performGlobalAction(id)
        }

        fun swipe(direction: String): Boolean {
            val service = instance ?: return false
            val display = service.resources.displayMetrics
            val w = display.widthPixels.toFloat()
            val h = display.heightPixels.toFloat()
            val path = Path()
            when (direction) {
                "up" -> {
                    path.moveTo(w / 2f, h * 0.72f)
                    path.lineTo(w / 2f, h * 0.28f)
                }
                "down" -> {
                    path.moveTo(w / 2f, h * 0.30f)
                    path.lineTo(w / 2f, h * 0.74f)
                }
                "left" -> {
                    path.moveTo(w * 0.82f, h / 2f)
                    path.lineTo(w * 0.18f, h / 2f)
                }
                else -> {
                    path.moveTo(w * 0.18f, h / 2f)
                    path.lineTo(w * 0.82f, h / 2f)
                }
            }
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 280))
                .build()
            return service.dispatchGesture(gesture, null, null)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }
}
