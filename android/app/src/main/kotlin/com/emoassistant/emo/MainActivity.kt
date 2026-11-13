package com.emoassistant.emo

import android.Manifest
import android.app.NotificationManager
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.provider.ContactsContract
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {

    private lateinit var channel: MethodChannel
    private var torchOn = false
    private val pendingPermissions = mutableMapOf<Int, Pair<String, MethodChannel.Result>>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "emo/device")
        channel.setMethodCallHandler { call, result ->
            try {
                handle(call, result)
            } catch (t: Throwable) {
                result.error("emo_error", t.message ?: "Something went wrong", null)
            }
        }
        RoutineScheduler.ensureChannel(this)
        EmoAlerts.ensureChannels(this)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getState" -> result.success(snapshot())
            "setTorch" -> result.success(setTorch(call.argument<Boolean>("on") ?: false))
            "setWifi" -> result.success(setWifi(call.argument<Boolean>("on") ?: false))
            "setBluetooth" -> result.success(setBluetooth(call.argument<Boolean>("on") ?: false))
            "setDnd" -> result.success(setDnd(call.argument<String>("mode") ?: "off"))
            "setBrightness" -> result.success(
                setBrightness((call.argument<Double>("value") ?: 0.5).toFloat())
            )
            "setVolume" -> result.success(
                setVolume(
                    call.argument<String>("stream") ?: "music",
                    (call.argument<Double>("value") ?: 0.5).toFloat()
                )
            )
            "openPanel" -> result.success(openPanel(call.argument<String>("kind") ?: "settings"))
            "openApp" -> result.success(openApp(call.argument<String>("query") ?: ""))
            "openUrl" -> result.success(openUrl(call.argument<String>("url") ?: ""))
            "dial" -> result.success(dial(call.argument<String>("number") ?: ""))
            "composeSms" -> result.success(
                composeSms(
                    call.argument<String>("number") ?: "",
                    call.argument<String>("body") ?: ""
                )
            )
            "findContact" -> result.success(findContact(call.argument<String>("name") ?: ""))
            "globalAction" -> result.success(globalAction(call.argument<String>("action") ?: ""))
            "swipe" -> result.success(swipe(call.argument<String>("direction") ?: "up"))
            "getInstalledApps" -> result.success(installedApps())
            "getNotifications" -> result.success(recentNotifications())
            "dismissNotifications" -> result.success(dismissNotifications())
            "requestPermission" -> requestPermission(
                call.argument<String>("name") ?: "", result
            )
            "notifyReply" -> result.success(
                EmoAlerts.postReply(
                    this,
                    call.argument<String>("title") ?: "Emo",
                    call.argument<String>("body") ?: ""
                )
            )
            "notifyUpdate" -> result.success(
                EmoAlerts.postUpdate(
                    this,
                    call.argument<String>("version") ?: "",
                    call.argument<String>("url") ?: "",
                    call.argument<String>("notes") ?: ""
                )
            )
            "appVersion" -> result.success(appVersion())
            "filesDir" -> result.success(filesDir.absolutePath)
            "playAudio" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes != null && bytes.isNotEmpty()) {
                    result.success(playAudioBytes(bytes))
                } else {
                    result.success(false)
                }
            }
            "stopAudio" -> {
                stopAudio()
                result.success(true)
            }
            "syncRoutines" -> {
                RoutineStore.save(this, call.argument<String>("json") ?: "[]")
                result.success(mapOf("ok" to true))
            }
            "consumeRoutineEvents" -> result.success(consumeRoutineEvents())
            else -> result.notImplemented()
        }
    }

    private fun ok(message: String? = null): Map<String, Any?> =
        mapOf("ok" to true, "message" to message)


    private fun fail(message: String, needs: String? = null): Map<String, Any?> =
        mapOf("ok" to false, "message" to message, "needs" to needs)

    private fun snapshot(): Map<String, Any?> {
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val caps = connectivity.getNetworkCapabilities(connectivity.activeNetwork)
        val wifiConnected = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true

        val bluetoothAllowed = Build.VERSION.SDK_INT < 31 || checkSelfPermission(
            Manifest.permission.BLUETOOTH_CONNECT
        ) == PackageManager.PERMISSION_GRANTED
        val btAdapter = (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
        val bluetoothSupported = btAdapter != null
        var bluetoothOn = false
        if (bluetoothAllowed && btAdapter != null) {
            bluetoothOn = try {
                btAdapter.isEnabled
            } catch (e: SecurityException) {
                false
            }
        }

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val policyAccess = nm.isNotificationPolicyAccessGranted
        var dndFilter = 0
        if (policyAccess) {
            try {
                dndFilter = nm.currentInterruptionFilter
            } catch (e: SecurityException) {
                dndFilter = 0
            }
        }

        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val batteryPct = if (level >= 0 && scale > 0) level * 100 / scale else -1
        val status = batteryIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL

        val systemBrightness = Settings.System.getInt(
            contentResolver, Settings.System.SCREEN_BRIGHTNESS, 128
        ) / 255f
        val windowBrightness = window?.attributes?.screenBrightness ?: -1f

        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "androidSdk" to Build.VERSION.SDK_INT,
            "wifiConnected" to wifiConnected,
            "wifiEnabled" to (wifiConnected || wifi.isWifiEnabled),
            "bluetoothSupported" to bluetoothSupported,
            "bluetoothOn" to bluetoothOn,
            "dndFilter" to dndFilter,
            "dndAccess" to policyAccess,
            "torchOn" to torchOn,
            "hasFlash" to hasFlash(),
            "battery" to batteryPct,
            "charging" to charging,
            "brightness" to systemBrightness.coerceIn(0.02f, 1f),
            "windowBrightness" to windowBrightness,
            "canWriteSettings" to Settings.System.canWrite(this),
            "volumeMusic" to am.getStreamVolume(AudioManager.STREAM_MUSIC).toFloat() /
                am.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1),
            "volumeRing" to am.getStreamVolume(AudioManager.STREAM_RING).toFloat() /
                am.getStreamMaxVolume(AudioManager.STREAM_RING).coerceAtLeast(1),
            "volumeAlarm" to am.getStreamVolume(AudioManager.STREAM_ALARM).toFloat() /
                am.getStreamMaxVolume(AudioManager.STREAM_ALARM).coerceAtLeast(1),
            "accessibility" to EmoAccessibilityService.isEnabled(this),
            "notificationAccess" to EmoNotificationStore.isEnabled(this),
            "notificationCount" to EmoNotificationStore.all().size,
            "shizukuInstalled" to isPackageInstalled("moe.shizuku.privileged.api"),
            "cameraPermission" to granted(Manifest.permission.CAMERA),
            "contactsPermission" to granted(Manifest.permission.READ_CONTACTS),
            "microphonePermission" to granted(Manifest.permission.RECORD_AUDIO),
            "notificationPermission" to (Build.VERSION.SDK_INT < 33 ||
                granted(Manifest.permission.POST_NOTIFICATIONS)),
            "bluetoothPermission" to (Build.VERSION.SDK_INT < 31 ||
                granted(Manifest.permission.BLUETOOTH_CONNECT))
        )
    }

    private fun granted(permission: String): Boolean =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun appVersion(): String = try {
        packageManager.getPackageInfo(packageName, 0).versionName ?: ""
    } catch (e: Exception) {
        ""
    }

    private fun isPackageInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private fun hasFlash(): Boolean = try {
        val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        cm.cameraIdList.any {
            cm.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        }
    } catch (e: Exception) {
        false
    }

    private fun setTorch(on: Boolean): Map<String, Any?> {
        if (!hasFlash()) return fail("This device doesn't have a flash")
        if (!granted(Manifest.permission.CAMERA)) {
            return fail("Camera permission is needed for the torch", "camera")
        }
        return try {
            val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val id = cm.cameraIdList.firstOrNull {
                cm.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            } ?: return fail("This device doesn't have a flash")
            cm.setTorchMode(id, on)
            torchOn = on
            ok(if (on) "Torch on" else "Torch off")
        } catch (e: Exception) {
            fail("The camera is busy, so the torch can't be used right now")
        }
    }

    private fun setWifi(on: Boolean): Map<String, Any?> {
        if (Build.VERSION.SDK_INT >= 29) {
            return fail("Android keeps Wi-Fi switching in the system panel", "wifi_panel")
        }
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        return try {
            wifi.isWifiEnabled = on
            ok(if (on) "Wi-Fi turned on" else "Wi-Fi turned off")
        } catch (e: SecurityException) {
            fail("Android keeps Wi-Fi switching in the system panel", "wifi_panel")
        }
    }

    private fun setBluetooth(on: Boolean): Map<String, Any?> {
        val adapter = (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
            ?: return fail("This phone doesn't support Bluetooth")
        if (Build.VERSION.SDK_INT >= 33) {
            return fail("Android keeps Bluetooth switching in the system panel", "bluetooth_panel")
        }
        if (Build.VERSION.SDK_INT >= 31 &&
            !granted(Manifest.permission.BLUETOOTH_CONNECT)
        ) {
            return fail("Bluetooth permission is needed", "bluetooth")
        }
        return try {
            if (on) adapter.enable() else adapter.disable()
            ok(if (on) "Bluetooth turned on" else "Bluetooth turned off")
        } catch (e: Exception) {
            fail("Bluetooth couldn't be changed", "bluetooth_panel")
        }
    }

    private fun setDnd(mode: String): Map<String, Any?> {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!nm.isNotificationPolicyAccessGranted) {
            return fail("Allow Do Not Disturb access for Emo first", "policy")
        }
        val filter = when (mode) {
            "priority" -> NotificationManager.INTERRUPTION_FILTER_PRIORITY
            "none" -> NotificationManager.INTERRUPTION_FILTER_NONE
            else -> NotificationManager.INTERRUPTION_FILTER_ALL
        }
        return try {
            nm.setInterruptionFilter(filter)
            ok(
                when (mode) {
                    "priority" -> "Only priority alerts will come through"
                    "none" -> "Do Not Disturb is on"
                    else -> "Do Not Disturb is off"
                }
            )
        } catch (e: SecurityException) {
            fail("Do Not Disturb access was revoked", "policy")
        }
    }

    private fun setBrightness(value: Float): Map<String, Any?> {
        val clamped = value.coerceIn(0.02f, 1f)
        val lp = window.attributes
        lp.screenBrightness = clamped
        window.attributes = lp
        if (Settings.System.canWrite(this)) {
            return try {
                Settings.System.putInt(
                    contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS,
                    (clamped * 255).roundToInt()
                )
                ok("Screen brightness set to ${(clamped * 100).roundToInt()}%")
            } catch (e: Exception) {
                ok("Brightness adjusted for Emo")
            }
        }
        return ok("Brightness adjusted while Emo is open")
    }

    private fun setVolume(streamName: String, value: Float): Map<String, Any?> {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val stream = when (streamName) {
            "ring" -> AudioManager.STREAM_RING
            "alarm" -> AudioManager.STREAM_ALARM
            "notification" -> AudioManager.STREAM_NOTIFICATION
            else -> AudioManager.STREAM_MUSIC
        }
        return try {
            val max = am.getStreamMaxVolume(stream)
            am.setStreamVolume(stream, (value.coerceIn(0f, 1f) * max).roundToInt(), 0)
            ok("${streamName.replaceFirstChar { it.uppercase() }} volume set to ${(value * 100).roundToInt()}%")
        } catch (e: SecurityException) {
            fail("That volume stream can't be changed right now")
        }
    }

    private fun openPanel(kind: String): Map<String, Any?> {
        val intent = when (kind) {
            "wifi" ->
                if (Build.VERSION.SDK_INT >= 29)
                    Intent(Settings.Panel.ACTION_INTERNET_CONNECTIVITY)
                else Intent(Settings.ACTION_WIFI_SETTINGS)
            "bluetooth" -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
            "volume" ->
                if (Build.VERSION.SDK_INT >= 29) Intent(Settings.Panel.ACTION_VOLUME)
                else Intent(Settings.ACTION_SOUND_SETTINGS)
            "dnd" ->
                if ((getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                        .isNotificationPolicyAccessGranted
                ) Intent(Settings.ACTION_ZEN_MODE_PRIORITY_SETTINGS)
                else Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            "airplane" -> Intent(Settings.ACTION_AIRPLANE_MODE_SETTINGS)
            "location" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            "display" -> Intent(Settings.ACTION_DISPLAY_SETTINGS)
            "sound" -> Intent(Settings.ACTION_SOUND_SETTINGS)
            "battery" -> Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
            "data" -> Intent(Settings.ACTION_WIRELESS_SETTINGS)
            "apps" -> Intent(Settings.ACTION_APPLICATION_SETTINGS)
            "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            "notification_access" -> Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            "policy_access" -> Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            "write_settings" -> Intent(
                Settings.ACTION_MANAGE_WRITE_SETTINGS,
                Uri.parse("package:$packageName")
            )
            "app_info" -> Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName")
            )
            "developer" -> Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
            else -> Intent(Settings.ACTION_SETTINGS)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(intent)
            ok()
        } catch (e: Exception) {
            fail("This device doesn't expose that settings panel")
        }
    }

    private fun launchableApps(): List<Pair<String, String>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(intent, 0)
            .map { it.loadLabel(packageManager).toString() to (it.activityInfo?.packageName ?: "") }
            .filter { it.second.isNotEmpty() }
            .distinctBy { it.second }
            .sortedBy { it.first.lowercase() }
    }

    private fun installedApps(): List<Map<String, String>> =
        launchableApps().take(240).map { mapOf("label" to it.first, "package" to it.second) }

    private fun openApp(query: String): Map<String, Any?> {
        if (query.isBlank()) return fail("Tell me which app to open")
        val q = query.trim().lowercase()
        val apps = launchableApps()
        val match = apps.firstOrNull { it.first.lowercase() == q }
            ?: apps.firstOrNull { it.first.lowercase().contains(q) }
            ?: apps.firstOrNull { q.contains(it.first.lowercase()) }
            ?: return fail("I couldn't find an app called \"$query\"")
        val launch = packageManager.getLaunchIntentForPackage(match.second)
            ?: return fail("${match.first} can't be opened from Emo")
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(launch)
            ok("Opened ${match.first}")
        } catch (e: Exception) {
            fail("${match.first} didn't open")
        }
    }

    private fun openUrl(url: String): Map<String, Any?> {
        val parsed = try {
            Uri.parse(url)
        } catch (e: Exception) {
            return fail("That link isn't valid")
        }
        val scheme = parsed.scheme?.lowercase()
        if (scheme != "http" && scheme != "https") return fail("Only web links can be opened")
        val intent = Intent(Intent.ACTION_VIEW, parsed).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(intent)
            ok("Opened in your browser")
        } catch (e: Exception) {
            fail("No browser could open that link")
        }
    }

    private fun cleanNumber(raw: String): String =
        raw.filter { it.isDigit() || it == '+' || it == '#' || it == '*' }

    private fun dial(number: String): Map<String, Any?> {
        val cleaned = cleanNumber(number)
        if (cleaned.isBlank()) return fail("I need a number to dial")
        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${Uri.encode(cleaned)}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(intent)
            ok("Dialer opened with $cleaned")
        } catch (e: Exception) {
            fail("This device can't open the dialer")
        }
    }

    private fun composeSms(number: String, body: String): Map<String, Any?> {
        val cleaned = cleanNumber(number)
        if (cleaned.isBlank()) return fail("I need a number to message")
        val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:${Uri.encode(cleaned)}"))
            .putExtra("sms_body", body)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(intent)
            ok("Message ready to send")
        } catch (e: Exception) {
            fail("This device can't open the message composer")
        }
    }

    private fun findContact(name: String): Map<String, Any?> {
        if (name.isBlank()) return fail("Tell me who to find")
        if (!granted(Manifest.permission.READ_CONTACTS)) {
            return fail("Contact access is needed to find that person", "contacts")
        }
        val results = mutableListOf<Map<String, String>>()
        try {
            contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                ),
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?",
                arrayOf("%$name%"),
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
            )?.use { cursor ->
                while (cursor.moveToNext() && results.size < 8) {
                    val display = cursor.getString(0) ?: continue
                    val number = cursor.getString(1) ?: continue
                    if (number.isBlank()) continue
                    results.add(mapOf("name" to display, "number" to number))
                }
            }
        } catch (e: Exception) {
            return fail("Contacts couldn't be read")
        }
        if (results.isEmpty()) return fail("No contact matched \"$name\"")
        return mapOf("ok" to true, "contacts" to results)
    }

    private fun globalAction(action: String): Map<String, Any?> {
        if (!EmoAccessibilityService.isEnabled(this)) {
            return fail("Emo's accessibility service is off", "accessibility")
        }
        val done = EmoAccessibilityService.globalAction(action)
        return if (done) ok() else fail("That system action isn't available on this phone")
    }

    private fun swipe(direction: String): Map<String, Any?> {
        if (!EmoAccessibilityService.isEnabled(this)) {
            return fail("Emo's accessibility service is off", "accessibility")
        }
        val done = EmoAccessibilityService.swipe(direction)
        return if (done) ok() else fail("Emo couldn't perform that gesture")
    }

    private fun recentNotifications(): List<Map<String, Any?>> =
        if (!EmoNotificationStore.isEnabled(this)) emptyList()
        else EmoNotificationStore.all().map {
            mapOf(
                "app" to it.app,
                "title" to it.title,
                "text" to it.text,
                "time" to it.time
            )
        }

    private fun dismissNotifications(): Map<String, Any?> {
        if (!EmoNotificationStore.isEnabled(this)) {
            return fail("Notification access is needed to clear notifications", "notification_access")
        }
        return try {
            EmoNotificationListener.instance?.cancelAllNotifications()
            EmoNotificationStore.clear()
            ok("Notifications cleared")
        } catch (e: Exception) {
            fail("Notifications couldn't be cleared")
        }
    }

    private fun requestPermission(name: String, result: MethodChannel.Result) {
        val permission = when (name) {
            "camera" -> Manifest.permission.CAMERA
            "contacts" -> Manifest.permission.READ_CONTACTS
            "microphone" -> Manifest.permission.RECORD_AUDIO
            "notifications" -> if (Build.VERSION.SDK_INT >= 33)
                Manifest.permission.POST_NOTIFICATIONS else null
            "bluetooth" -> if (Build.VERSION.SDK_INT >= 31)
                Manifest.permission.BLUETOOTH_CONNECT else null
            else -> null
        }
        if (permission == null) {
            result.success(true)
            return
        }
        if (granted(permission)) {
            result.success(true)
            return
        }
        val code = 4100 + pendingPermissions.size
        pendingPermissions[code] = name to result
        requestPermissions(arrayOf(permission), code)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val entry = pendingPermissions.remove(requestCode) ?: return
        val grantedNow = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        entry.second.success(grantedNow)
        if (::channel.isInitialized) {
            channel.invokeMethod(
                "permissionResult",
                mapOf("name" to entry.first, "granted" to grantedNow)
            )
        }
    }

    private fun consumeRoutineEvents(): List<Map<String, Any?>> {
        val raw = RoutineStore.consumeEvents(this)
        val list = mutableListOf<Map<String, Any?>>()
        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                list.add(
                    mapOf(
                        "routine" to obj.optString("routine"),
                        "time" to obj.optLong("time"),
                        "ok" to obj.optBoolean("ok"),
                        "summary" to obj.optString("summary")
                    )
                )
            }
        } catch (e: Exception) {
            // Ignore malformed event payloads.
        }
        return list
    }

    private var mediaPlayer: android.media.MediaPlayer? = null

    private fun playAudioBytes(bytes: ByteArray): Boolean {
        stopAudio()
        return try {
            val temp = java.io.File(cacheDir, "speech.mp3")
            temp.writeBytes(bytes)
            mediaPlayer = android.media.MediaPlayer().apply {
                setDataSource(temp.absolutePath)
                prepare()
                start()
                setOnCompletionListener {
                    try {
                        it.release()
                    } catch (_: Throwable) {}
                    mediaPlayer = null
                    try {
                        temp.delete()
                    } catch (_: Throwable) {}
                }
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun stopAudio() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Throwable) {}
        mediaPlayer = null
    }

    override fun onDestroy() {
        stopAudio()
        super.onDestroy()
    }
}
