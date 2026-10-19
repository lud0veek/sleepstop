package com.sleepstop.sleep_stop.homeactions

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import androidx.activity.result.ActivityResultCaller
import androidx.core.app.NotificationCompat
import com.google.home.ConnectivityState
import com.google.home.FactoryRegistry
import com.google.home.Home
import com.google.home.HomeClient
import com.google.home.HomeConfig
import com.google.home.HomeDevice
import com.google.home.HomeException
import com.google.home.PermissionsResultStatus
import com.google.home.PermissionsState
import com.google.home.Structure
import com.google.home.matter.standard.ColorTemperatureLightDevice
import com.google.home.matter.standard.DimmableLightDevice
import com.google.home.matter.standard.ExtendedColorLightDevice
import com.google.home.matter.standard.LevelControl
import com.google.home.matter.standard.LevelControlTrait
import com.google.home.matter.standard.OnOff
import com.google.home.matter.standard.OnOffLightDevice
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import com.sleepstop.sleep_stop.R

/**
 * Google Home APIs implementation. Compiled only with the SDK AARs present.
 *
 * Written against the Home APIs 1.11 documentation
 * (developers.home.google.com/apis/android). Identifiers to double-check
 * against the downloaded SDK before the first build:
 *   - HomeDevice.id / Id.id, HomeDevice.roomId, Structure.name
 *   - LevelControlCommands.moveToLevelWithOnOff(level, transitionTime, optionsMask, optionsOverride)
 *     and the unit of transitionTime (Matter: tenths of a second).
 */
class GoogleHomeLightsController(private val context: Context) : LightsController {

    companion object {
        private const val NOTIF_CHANNEL = "sleepstop_lights"
        private const val NOTIF_ID = 1003
        private const val ACTION_CANCEL = "com.sleepstop.sleep_stop.LIGHTS_CANCEL"
        private const val COMMAND_TIMEOUT_MS = 8_000L

        /** Singleton, as required by the SDK. */
        @Volatile
        private var client: HomeClient? = null

        private fun homeClient(context: Context): HomeClient {
            return client ?: synchronized(this) {
                client ?: Home.getClient(
                    context.applicationContext,
                    HomeConfig(
                        coroutineContext = Dispatchers.IO,
                        factoryRegistry = FactoryRegistry(
                            traits = listOf(OnOff, LevelControl),
                            types = listOf(
                                OnOffLightDevice,
                                DimmableLightDevice,
                                ColorTemperatureLightDevice,
                                ExtendedColorLightDevice
                            )
                        )
                    )
                ).also { client = it }
            }
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val home: HomeClient get() = homeClient(context)

    private data class LightSnapshot(
        val device: HomeDevice,
        val wasOn: Boolean,
        val level: UByte?,
        val hasLevel: Boolean
    )

    private var fadeJob: Job? = null
    private var snapshots: List<LightSnapshot> = emptyList()
    private var cancelReceiver: BroadcastReceiver? = null

    // ------------------------------------------------------------------ status

    override fun checkAvailability(callback: (String, String?) -> Unit) = callback("available", null)

    override fun bindActivity(activity: Activity) {
        if (activity is ActivityResultCaller) {
            try {
                home.registerActivityResultCallerForPermissions(activity)
            } catch (_: Exception) {
            }
        }
    }

    override fun permissionState(callback: (String, String?) -> Unit) {
        scope.launch {
            try {
                val state = withTimeout(COMMAND_TIMEOUT_MS) {
                    home.hasPermissions().first { it != PermissionsState.PERMISSIONS_STATE_UNINITIALIZED }
                }
                when (state) {
                    PermissionsState.GRANTED -> {
                        val structure = runCatching {
                            withTimeout(COMMAND_TIMEOUT_MS) { home.structures().list().firstOrNull() }
                        }.getOrNull()
                        // Granted but no structure = access revoked in the Google Home app.
                        if (structure == null) callback("notGranted", null)
                        else callback("granted", structure.name)
                    }
                    PermissionsState.NOT_GRANTED -> callback("notGranted", null)
                    PermissionsState.PERMISSIONS_STATE_UNAVAILABLE -> callback("unavailable", null)
                    else -> callback("uninitialized", null)
                }
            } catch (e: Exception) {
                callback("error", e.javaClass.simpleName)
            }
        }
    }

    override fun requestPermissions(callback: (String, String?) -> Unit) {
        scope.launch {
            try {
                val result = home.requestPermissions()
                when (result.status) {
                    PermissionsResultStatus.SUCCESS -> callback("granted", null)
                    PermissionsResultStatus.CANCELLED -> callback("cancelled", null)
                    else -> callback("error", result.status.name)
                }
            } catch (e: HomeException) {
                callback("error", e.javaClass.simpleName)
            } catch (e: Exception) {
                callback("error", e.javaClass.simpleName)
            }
        }
    }

    // ---------------------------------------------------------------- listing

    override fun listLights(callback: (List<Map<String, Any?>>?, String?) -> Unit) {
        scope.launch {
            try {
                val structures = withTimeout(COMMAND_TIMEOUT_MS) { home.structures().list() }
                val devices = withTimeout(COMMAND_TIMEOUT_MS) { home.devices().list() }
                    .filter { it.has(OnOff) }
                val out = structures.map { structure ->
                    val rooms = withTimeout(COMMAND_TIMEOUT_MS) { structure.rooms().list() }
                    val roomMaps = rooms.map { room ->
                        mapOf(
                            "id" to room.id.id,
                            "name" to room.name,
                            "devices" to devices
                                .filter { it.roomId == room.id }
                                .map { deviceMap(it) }
                        )
                    }
                    val orphans = devices
                        .filter { d -> d.structureId == structure.id && rooms.none { it.id == d.roomId } }
                        .map { deviceMap(it) }
                    mapOf(
                        "id" to structure.id.id,
                        "name" to structure.name,
                        "rooms" to roomMaps,
                        "unassigned" to orphans
                    )
                }
                callback(out, null)
            } catch (e: Exception) {
                callback(null, e.javaClass.simpleName)
            }
        }
    }

    private fun deviceMap(d: HomeDevice): Map<String, Any?> = mapOf(
        "id" to d.id.id,
        "name" to d.name,
        "hasLevel" to d.has(LevelControl),
        "online" to (d.metadata.sourceConnectivity.connectivityState != ConnectivityState.OFFLINE)
    )

    // --------------------------------------------------------------- execute

    override fun executeLightsOff(
        deviceIds: List<String>,
        roomIds: List<String>,
        fadeSeconds: Int,
        labels: LightsController.NotificationLabels,
        callback: (Boolean, String?) -> Unit
    ) {
        if (fadeJob?.isActive == true) {
            callback(false, "alreadyRunning")
            return
        }
        fadeJob = scope.launch {
            try {
                val all = withTimeout(COMMAND_TIMEOUT_MS) { home.devices().list() }
                val targets = all.filter { d ->
                    d.has(OnOff) && (deviceIds.contains(d.id.id) || roomIds.contains(d.roomId?.id))
                }
                if (targets.isEmpty()) {
                    callback(false, "noDevice")
                    return@launch
                }
                snapshots = targets.map { snapshot(it) }
                callback(true, null)
                if (fadeSeconds > 0) showCancelNotification(labels)
                runFade(fadeSeconds)
            } catch (e: Exception) {
                callback(false, e.javaClass.simpleName)
            } finally {
                hideCancelNotification()
            }
        }
    }

    private suspend fun snapshot(d: HomeDevice): LightSnapshot {
        val onOff = runCatching {
            withTimeout(COMMAND_TIMEOUT_MS) {
                d.type(OnOffLightDevice).map { it.standardTraits.onOff }.firstOrNull()
            }
        }.getOrNull()
        val level = if (d.has(LevelControl)) runCatching {
            withTimeout(COMMAND_TIMEOUT_MS) {
                d.type(DimmableLightDevice).map { it.standardTraits.levelControl }.firstOrNull()
            }
        }.getOrNull() else null
        return LightSnapshot(
            device = d,
            wasOn = onOff?.onOff ?: true,
            level = level?.currentLevel,
            hasLevel = level != null
        )
    }

    private suspend fun runFade(fadeSeconds: Int) {
        val dimmable = snapshots.filter { it.hasLevel && it.wasOn }
        val others = snapshots.filter { !(it.hasLevel && it.wasOn) }

        // Native transition where supported (Matter transitionTime in 1/10 s).
        val tenths = (fadeSeconds * 10).coerceIn(0, 65_534)
        dimmable.map { snap ->
            scope.async {
                runCatching {
                    val lc = withTimeout(COMMAND_TIMEOUT_MS) {
                        snap.device.type(DimmableLightDevice)
                            .map { it.standardTraits.levelControl }.firstOrNull()
                    } ?: return@async
                    withTimeout(COMMAND_TIMEOUT_MS) {
                        lc.moveToLevelWithOnOff(
                            level = 0u.toUByte(),
                            transitionTime = if (fadeSeconds > 0) tenths.toUShort() else null,
                            optionsMask = LevelControlTrait.OptionsBitmap(),
                            optionsOverride = LevelControlTrait.OptionsBitmap()
                        )
                    }
                }
            }
        }.awaitAll()

        // Wait for the transition to end (cancellable), then make sure of OFF.
        if (fadeSeconds > 0) delay(fadeSeconds * 1000L)

        (dimmable + others).map { snap ->
            scope.async {
                runCatching {
                    val onOff = withTimeout(COMMAND_TIMEOUT_MS) {
                        snap.device.type(OnOffLightDevice)
                            .map { it.standardTraits.onOff }.firstOrNull()
                    } ?: return@async
                    withTimeout(COMMAND_TIMEOUT_MS) { onOff.off() }
                }
            }
        }.awaitAll()
    }

    override fun cancelAndRestore(callback: (Boolean, String?) -> Unit) {
        val job = fadeJob
        fadeJob = null
        job?.cancel()
        hideCancelNotification()
        val toRestore = snapshots
        snapshots = emptyList()
        if (toRestore.isEmpty()) {
            callback(false, "nothingToRestore")
            return
        }
        scope.launch {
            var ok = true
            toRestore.map { snap ->
                scope.async {
                    runCatching {
                        if (snap.hasLevel && snap.level != null) {
                            val lc = withTimeout(COMMAND_TIMEOUT_MS) {
                                snap.device.type(DimmableLightDevice)
                                    .map { it.standardTraits.levelControl }.firstOrNull()
                            }
                            lc?.let {
                                withTimeout(COMMAND_TIMEOUT_MS) {
                                    it.moveToLevelWithOnOff(
                                        level = snap.level,
                                        transitionTime = 5u.toUShort(),
                                        optionsMask = LevelControlTrait.OptionsBitmap(),
                                        optionsOverride = LevelControlTrait.OptionsBitmap()
                                    )
                                }
                            }
                        }
                        val onOff = withTimeout(COMMAND_TIMEOUT_MS) {
                            snap.device.type(OnOffLightDevice)
                                .map { it.standardTraits.onOff }.firstOrNull()
                        }
                        onOff?.let { withTimeout(COMMAND_TIMEOUT_MS) { if (snap.wasOn) it.on() else it.off() } }
                    }.onFailure { ok = false }
                }
            }.awaitAll()
            callback(ok, if (ok) null else "partialRestore")
        }
    }

    // ---------------------------------------------------------- notification

    private fun showCancelNotification(labels: LightsController.NotificationLabels) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(NOTIF_CHANNEL, labels.channelName, NotificationManager.IMPORTANCE_LOW)
            )
        }
        if (cancelReceiver == null) {
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(ctx: Context, intent: Intent) {
                    if (intent.action == ACTION_CANCEL) cancelAndRestore { _, _ -> }
                }
            }
            cancelReceiver = receiver
            val filter = IntentFilter(ACTION_CANCEL)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                context.registerReceiver(receiver, filter)
            }
        }
        val cancelIntent = PendingIntent.getBroadcast(
            context, 1003,
            Intent(ACTION_CANCEL).setPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(context, NOTIF_CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(labels.title)
            .setContentText(labels.body)
            .setOngoing(true)
            .setSilent(true)
            .addAction(0, labels.cancelButton, cancelIntent)
            .build()
        nm.notify(NOTIF_ID, notification)
    }

    private fun hideCancelNotification() {
        try {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIF_ID)
        } catch (_: Exception) {
        }
        cancelReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        cancelReceiver = null
    }
}
