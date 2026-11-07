package com.emoassistant.emo

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

object RoutineStore {
    private const val PREFS = "emo_routines"
    private const val KEY = "routines"
    private const val EVENTS = "pending_events"

    fun save(context: Context, json: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY, json).apply()
        RoutineScheduler.reschedule(context)
    }

    fun routines(context: Context): JSONArray {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, "[]") ?: "[]"
        return try {
            JSONArray(raw)
        } catch (e: Exception) {
            JSONArray()
        }
    }

    fun actionsFor(context: Context, id: String): JSONArray {
        val all = routines(context)
        for (i in 0 until all.length()) {
            val r = all.optJSONObject(i) ?: continue
            if (r.optString("id") == id) return r.optJSONArray("actions") ?: JSONArray()
        }
        return JSONArray()
    }

    fun pushEvent(context: Context, event: JSONObject) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = try {
            JSONArray(prefs.getString(EVENTS, "[]") ?: "[]")
        } catch (e: Exception) {
            JSONArray()
        }
        arr.put(event)
        prefs.edit().putString(EVENTS, arr.toString()).apply()
    }

    fun consumeEvents(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(EVENTS, "[]") ?: "[]"
        prefs.edit().putString(EVENTS, "[]").apply()
        return raw
    }
}

object RoutineExecutor {

    fun run(context: Context, action: JSONObject): String? {
        val type = action.optString("type")
        return try {
            when (type) {
                "torch" -> setTorch(context, action.optBoolean("value", true))
                "dnd" -> setDnd(context, action.optString("value", "off"))
                "volume" -> {
                    val streamName = action.optString("stream", "music")
                    val value = action.optDouble("value", 0.5).toFloat()
                    setVolume(context, streamName, value)
                }
                "brightness" -> {
                    if (!Settings.System.canWrite(context)) return null
                    val value = action.optDouble("value", 0.5).coerceIn(0.0, 1.0)
                    Settings.System.putInt(
                        context.contentResolver,
                        Settings.System.SCREEN_BRIGHTNESS,
                        (value * 255).toInt()
                    )
                    "Screen brightness set to ${(value * 100).toInt()}%"
                }
                else -> null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun setTorch(context: Context, on: Boolean): String? {
        val cm = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val id = cm.cameraIdList.firstOrNull {
            cm.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        } ?: return null
        cm.setTorchMode(id, on)
        return if (on) "Torch turned on" else "Torch turned off"
    }

    private fun setDnd(context: Context, mode: String): String? {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!nm.isNotificationPolicyAccessGranted) return null
        val filter = when (mode) {
            "priority" -> NotificationManager.INTERRUPTION_FILTER_PRIORITY
            "none" -> NotificationManager.INTERRUPTION_FILTER_NONE
            else -> NotificationManager.INTERRUPTION_FILTER_ALL
        }
        nm.setInterruptionFilter(filter)
        return when (mode) {
            "priority" -> "Do Not Disturb set to Priority"
            "none" -> "Do Not Disturb turned on"
            else -> "Do Not Disturb turned off"
        }
    }

    private fun setVolume(context: Context, streamName: String, value: Float): String {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val stream = when (streamName) {
            "ring" -> AudioManager.STREAM_RING
            "alarm" -> AudioManager.STREAM_ALARM
            "notification" -> AudioManager.STREAM_NOTIFICATION
            else -> AudioManager.STREAM_MUSIC
        }
        val max = am.getStreamMaxVolume(stream)
        am.setStreamVolume(stream, (value.coerceIn(0f, 1f) * max).toInt(), 0)
        return "Volume set to ${(value * 100).toInt()}%"
    }
}

object RoutineScheduler {
    private const val PREFS = "emo_routines"
    private const val CODES = "scheduled_codes"
    const val CHANNEL_ID = "emo_routines"
    private const val CHANNEL_NAME = "Routine runs"

    fun ensureChannel(context: Context) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
    }

    fun reschedule(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.getStringSet(CODES, emptySet())?.forEach { code ->
            code.toIntOrNull()?.let { am.cancel(pendingIntent(context, it, "", "")) }
        }

        val codes = mutableSetOf<String>()
        val routines = RoutineStore.routines(context)
        for (i in 0 until routines.length()) {
            val r = routines.optJSONObject(i) ?: continue
            if (!r.optBoolean("enabled", true)) continue
            if (r.optString("trigger") != "time") continue
            val id = r.optString("id", i.toString())
            val name = r.optString("name", "Routine")
            val time = r.optString("time", "08:00").split(":")
            val hour = time.getOrNull(0)?.toIntOrNull() ?: 8
            val minute = time.getOrNull(1)?.toIntOrNull() ?: 0
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
            }
            val code = ((id.hashCode() and 0x7fffffff) % 90000) + 1000
            am.setRepeating(
                AlarmManager.RTC_WAKEUP,
                cal.timeInMillis,
                AlarmManager.INTERVAL_DAY,
                pendingIntent(context, code, id, name)
            )
            codes.add(code.toString())
        }
        prefs.edit().putStringSet(CODES, codes).apply()
    }

    private fun pendingIntent(context: Context, code: Int, id: String, name: String): PendingIntent {
        val intent = Intent(context, EmoRoutineReceiver::class.java).apply {
            putExtra("routineId", id)
            putExtra("routineName", name)
        }
        return PendingIntent.getBroadcast(
            context,
            code,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}

class EmoRoutineReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("routineId") ?: return
        val name = intent.getStringExtra("routineName") ?: "Routine"
        if (id.isEmpty()) return

        val actions = RoutineStore.actionsFor(context, id)
        val executed = mutableListOf<String>()
        for (i in 0 until actions.length()) {
            val action = actions.optJSONObject(i) ?: continue
            RoutineExecutor.run(context, action)?.let { executed.add(it) }
        }

        RoutineStore.pushEvent(
            context,
            JSONObject().apply {
                put("routine", name)
                put("time", System.currentTimeMillis())
                put("ok", executed.isNotEmpty())
                put("summary", if (executed.isEmpty()) "No actions could run" else executed.joinToString(" · "))
            }
        )

        RoutineScheduler.ensureChannel(context)
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val contentIntent = launch?.let {
            PendingIntent.getActivity(
                context, 42, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        val summary = if (executed.isEmpty()) "Ran with no effect" else executed.joinToString(" · ")
        val builder = android.app.Notification.Builder(context, RoutineScheduler.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("$name ran")
            .setContentText(summary)
            .setAutoCancel(true)
        contentIntent?.let { builder.setContentIntent(it) }
        try {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(id.hashCode(), builder.build())
        } catch (e: SecurityException) {
            // Notification permission not granted; the routine still ran.
        }
    }
}

class EmoBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            RoutineScheduler.reschedule(context)
        }
    }
}
