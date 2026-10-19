package com.sleepstop.sleep_stop

import android.Manifest
import android.app.ActivityManager
import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.sleepstop.sleep_stop.homeactions.HomeActionsChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.sleepstop/media_control"
        private const val PERMISSION_REQUEST_CODE = 9001

        @Volatile
        private var activeChannel: MethodChannel? = null

        @Volatile
        private var pendingQuickTileToggle: Boolean = false

        /** Called by the night veil when the user taps it ("still awake"). */
        fun dispatchStillAwakeFromNative() {
            val channel = activeChannel ?: return
            Handler(Looper.getMainLooper()).post {
                try {
                    channel.invokeMethod("onStillAwake", null)
                } catch (_: Exception) {
                }
            }
        }

        fun dispatchQuickTileToggleFromService(): Boolean {
            val channel = activeChannel ?: return false
            Handler(Looper.getMainLooper()).post {
                try {
                    channel.invokeMethod("onQuickTileToggle", null)
                } catch (_: Exception) {
                }
            }
            return true
        }
    }

    private val audioManager: AudioManager by lazy {
        applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    private val activityManager: ActivityManager by lazy {
        applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Google Home permission UI must be registered before the activity is started.
        HomeActionsChannel.bindActivity(this)
        checkQuickTileIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkQuickTileIntent(intent)
    }

    override fun onDestroy() {
        activeChannel = null
        super.onDestroy()
    }

    private fun checkQuickTileIntent(incomingIntent: Intent?) {
        if (incomingIntent?.action == SleepStopTileService.ACTION_QUICK_TILE_TOGGLE) {
            incomingIntent.action = null
            val channel = activeChannel
            if (channel != null) {
                channel.invokeMethod("onQuickTileToggle", null)
            } else {
                pendingQuickTileToggle = true
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        HomeActionsChannel(this).register(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        activeChannel = channel

        channel.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "pauseMedia" -> {
                            pauseAllActiveSessionsAndDispatchKey()
                            result.success(true)
                        }

                        "resumeMedia" -> {
                            resumeAllActiveSessionsAndDispatchKey()
                            result.success(true)
                        }

                        "rewindMedia" -> {
                            dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_REWIND)
                            result.success(true)
                        }

                        "getCurrentVolume" -> {
                            val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                            result.success(currentVol)
                        }

                        "getMaxVolume" -> {
                            val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                            result.success(maxVol)
                        }

                        "setVolume" -> {
                            val index = call.argument<Int>("index")
                                ?: call.arguments as? Int
                            if (index == null) {
                                result.error("INVALID_ARGUMENT", "Volume index is required.", null)
                            } else {
                                val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                                val clampedIndex = index.coerceIn(0, maxVol)
                                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, clampedIndex, 0)
                                result.success(clampedIndex)
                            }
                        }

                        "isMusicActive" -> {
                            result.success(audioManager.isMusicActive)
                        }

                        "getActiveMediaInfo" -> {
                            result.success(getActiveMediaInfoMap())
                        }

                        "isNotificationListenerEnabled" -> {
                            result.success(isNotificationServiceEnabled())
                        }

                        "openNotificationListenerSettings" -> {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        }

                        "getInstalledApps" -> {
                            result.success(getInstalledLaunchableApps())
                        }

                        "closeTargetApps" -> {
                            val packages = call.argument<List<String>>("packages") ?: emptyList()
                            val goHome = call.argument<Boolean>("goHome") ?: true
                            val closedAppNames = closeAppsAndReturnHome(packages, goHome)
                            result.success(closedAppNames)
                        }

                        "canDrawOverlays" -> {
                            result.success(NightOverlay.canDraw(this))
                        }

                        "openOverlayPermissionSettings" -> {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                            startActivity(intent)
                            result.success(true)
                        }

                        "showNightOverlay" -> {
                            NightOverlay.show(
                                this,
                                title = call.argument<String>("title") ?: "",
                                hint = call.argument<String>("hint") ?: "",
                                countdown = call.argument<String>("countdown") ?: ""
                            ) { dispatchStillAwakeFromNative() }
                            result.success(NightOverlay.isShowing() || NightOverlay.canDraw(this))
                        }

                        "updateNightOverlay" -> {
                            NightOverlay.update(
                                countdown = call.argument<String>("countdown"),
                                title = call.argument<String>("title"),
                                hint = call.argument<String>("hint")
                            )
                            result.success(true)
                        }

                        "finalizeNightOverlay" -> {
                            NightOverlay.setFinal(
                                title = call.argument<String>("title") ?: "",
                                hint = call.argument<String>("hint") ?: ""
                            )
                            result.success(true)
                        }

                        "hideNightOverlay" -> {
                            NightOverlay.hide(this)
                            result.success(true)
                        }

                        "requestRuntimePermissions" -> {
                            requestRequiredAndroidPermissions()
                            result.success(true)
                        }

                        "updateQuickTileState" -> {
                            val isActive = call.argument<Boolean>("isActive") ?: false
                            val subtitle = call.argument<String>("subtitle")
                                ?: getString(if (isActive) R.string.tile_active else R.string.tile_ready)
                            SleepStopTileService.updateTileState(applicationContext, isActive, subtitle)
                            result.success(true)
                        }

                        "consumeQuickTileLaunchTrigger" -> {
                            val triggered = pendingQuickTileToggle
                            pendingQuickTileToggle = false
                            result.success(triggered)
                        }

                        "requestAddQuickSettingsTile" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                val statusBarManager = getSystemService(StatusBarManager::class.java)
                                if (statusBarManager != null) {
                                    statusBarManager.requestAddTileService(
                                        ComponentName(this, SleepStopTileService::class.java),
                                        "SleepStop",
                                        Icon.createWithResource(this, R.drawable.ic_qs_sleepstop),
                                        ContextCompat.getMainExecutor(this)
                                    ) { statusCode ->
                                        val statusLabel = when (statusCode) {
                                            StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "ADDED"
                                            StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "ALREADY_ADDED"
                                            else -> "DISMISSED"
                                        }
                                        try {
                                            result.success(statusLabel)
                                        } catch (_: Exception) {
                                        }
                                    }
                                } else {
                                    result.success("UNSUPPORTED")
                                }
                            } else {
                                result.success("MANUAL_REQUIRED")
                            }
                        }

                        else -> {
                            result.notImplemented()
                        }
                    }
                } catch (e: Exception) {
                    result.error("MEDIA_CONTROL_ERROR", e.message, null)
                }
            }
    }

    private fun pauseAllActiveSessionsAndDispatchKey() {
        try {
            if (isNotificationServiceEnabled()) {
                val msm = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
                val component = ComponentName(this, SleepStopMediaListenerService::class.java)
                val controllers = msm.getActiveSessions(component)
                for (controller in controllers) {
                    controller.transportControls.pause()
                }
            }
        } catch (_: Exception) {
        }
        dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_PAUSE)
    }

    private fun resumeAllActiveSessionsAndDispatchKey() {
        try {
            if (isNotificationServiceEnabled()) {
                val msm = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
                val component = ComponentName(this, SleepStopMediaListenerService::class.java)
                val controllers = msm.getActiveSessions(component)
                for (controller in controllers) {
                    controller.transportControls.play()
                }
            }
        } catch (_: Exception) {
        }
        dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_PLAY)
    }

    private fun getActiveMediaInfoMap(): Map<String, String?> {
        val info = mutableMapOf<String, String?>(
            "appName" to null,
            "packageName" to null,
            "mediaTitle" to null,
            "mediaArtist" to null
        )

        try {
            if (isNotificationServiceEnabled()) {
                val msm = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
                val component = ComponentName(this, SleepStopMediaListenerService::class.java)
                val controllers = msm.getActiveSessions(component)
                val chosen = controllers.firstOrNull {
                    val state = it.playbackState?.state
                    state == PlaybackState.STATE_PLAYING ||
                        state == PlaybackState.STATE_BUFFERING ||
                        state == PlaybackState.STATE_FAST_FORWARDING
                } ?: controllers.firstOrNull()

                if (chosen != null) {
                    val pkg = chosen.packageName
                    info["packageName"] = pkg
                    info["appName"] = resolveAppName(pkg)
                    val meta = chosen.metadata
                    if (meta != null) {
                        info["mediaTitle"] = meta.getString(MediaMetadata.METADATA_KEY_TITLE)
                            ?: meta.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
                        info["mediaArtist"] = meta.getString(MediaMetadata.METADATA_KEY_ARTIST)
                            ?: meta.getString(MediaMetadata.METADATA_KEY_ALBUM)
                            ?: meta.getString(MediaMetadata.METADATA_KEY_AUTHOR)
                    }
                }
            }
        } catch (_: Exception) {
        }

        return info
    }

    private fun closeAppsAndReturnHome(packages: List<String>, goHome: Boolean): List<String> {
        val closedLabels = mutableListOf<String>()

        // 1. Stop any active MediaSessions belonging to target packages or active players
        try {
            if (isNotificationServiceEnabled()) {
                val msm = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
                val component = ComponentName(this, SleepStopMediaListenerService::class.java)
                val controllers = msm.getActiveSessions(component)
                for (controller in controllers) {
                    val pkg = controller.packageName
                    if (packages.isEmpty() || packages.contains(pkg)) {
                        controller.transportControls.pause()
                        controller.transportControls.stop()
                        val label = resolveAppName(pkg)
                        if (!closedLabels.contains(label)) {
                            closedLabels.add(label)
                        }
                    }
                }
            }
        } catch (_: Exception) {
        }

        // 2. Return to Home Screen so foreground video apps (YouTube, Netflix, Twitch, TikTok)
        // release their screen wake-lock and allow the phone display to turn off!
        if (goHome) {
            try {
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(homeIntent)
            } catch (_: Exception) {
            }
        }

        // 3. Kill background processes for all selected target packages
        for (pkg in packages) {
            if (pkg.isBlank() || pkg == packageName) continue
            try {
                activityManager.killBackgroundProcesses(pkg)
                val label = resolveAppName(pkg)
                if (!closedLabels.contains(label)) {
                    closedLabels.add(label)
                }
            } catch (_: Exception) {
            }
        }

        return closedLabels
    }

    private fun getInstalledLaunchableApps(): List<Map<String, Any>> {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = pm.queryIntentActivities(mainIntent, 0)
        val mediaKeywords = listOf(
            "audible", "youtube", "spotify", "netflix", "twitch", "tiktok",
            "deezer", "podcast", "pocketcasts", "primevideo", "amazon.avod",
            "disney", "vlc", "plex", "soundcloud", "tidal", "apple.android.music",
            "molotov", "arte", "france.tv", "mycanal", "crunchyroll", "smarttube",
            "newpipe", "revanced", "book", "music", "audio", "video", "radio"
        )

        val seenPackages = mutableSetOf<String>()
        val resultList = mutableListOf<Map<String, Any>>()

        for (ri in resolveInfos) {
            val pkg = ri.activityInfo?.packageName ?: continue
            if (pkg == packageName || !seenPackages.add(pkg)) continue

            val label = ri.loadLabel(pm)?.toString()?.trim() ?: pkg
            val lowerPkg = pkg.lowercase()
            val lowerLabel = label.lowercase()
            val isMediaCandidate = mediaKeywords.any {
                lowerPkg.contains(it) || lowerLabel.contains(it)
            }
            val isSystemApp = (ri.activityInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            // Include all user-installed apps plus known system media apps (like YouTube / Music)
            if (!isSystemApp || isMediaCandidate) {
                resultList.add(
                    mapOf(
                        "packageName" to pkg,
                        "appName" to label,
                        "isMediaCandidate" to isMediaCandidate
                    )
                )
            }
        }

        resultList.sortWith(
            compareByDescending<Map<String, Any>> { it["isMediaCandidate"] as Boolean }
                .thenBy { (it["appName"] as String).lowercase() }
        )
        return resultList
    }

    private fun resolveAppName(pkg: String): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            pkg.substringAfterLast('.')
                .replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(packageName)
    }

    private fun requestRequiredAndroidPermissions() {
        val needed = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN)
                != PackageManager.PERMISSION_GRANTED
            ) {
                needed.add(Manifest.permission.BLUETOOTH_SCAN)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT)
                != PackageManager.PERMISSION_GRANTED
            ) {
                needed.add(Manifest.permission.BLUETOOTH_CONNECT)
            }
        }

        // Below Android 12 a BLE scan legally requires location; from API 31 on
        // BLUETOOTH_SCAN (neverForLocation) replaces it entirely.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            needed.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                needed.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }

        if (needed.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                needed.toTypedArray(),
                PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun dispatchMediaKey(keyCode: Int) {
        val eventTime = SystemClock.uptimeMillis()
        val downEvent = KeyEvent(
            eventTime,
            eventTime,
            KeyEvent.ACTION_DOWN,
            keyCode,
            0
        )
        val upEvent = KeyEvent(
            eventTime,
            SystemClock.uptimeMillis(),
            KeyEvent.ACTION_UP,
            keyCode,
            0
        )
        audioManager.dispatchMediaKeyEvent(downEvent)
        audioManager.dispatchMediaKeyEvent(upEvent)
    }
}
