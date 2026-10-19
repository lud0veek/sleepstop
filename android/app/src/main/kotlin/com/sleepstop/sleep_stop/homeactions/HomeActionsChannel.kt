package com.sleepstop.sleep_stop.homeactions

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of the "When I fall asleep" actions.
 *
 * Step 2: broadcast intent for Tasker / Automate.
 * Later steps add: checkAvailability, requestPermissions, listLights,
 * executeLightsOff, cancelAndRestore (Google Home APIs).
 */
class HomeActionsChannel(private val context: Context) {

    companion object {
        const val CHANNEL = "com.sleepstop/home_actions"

        /** One controller per process (the SDK client is a singleton). */
        @Volatile
        private var lights: LightsController? = null

        fun lights(context: Context): LightsController =
            lights ?: synchronized(this) {
                lights ?: GoogleHomeLightsFactory.create(context.applicationContext).also { lights = it }
            }

        /** Called from MainActivity.onCreate (permission UI needs an Activity). */
        fun bindActivity(activity: Activity) {
            try {
                lights(activity).bindActivity(activity)
            } catch (_: Exception) {
            }
        }

        /** Public broadcast action; documented in the settings screen. */
        const val ACTION_SLEEP_DETECTED = "com.sleepstop.sleep_stop.SLEEP_DETECTED"
        const val EXTRA_TIMESTAMP = "timestamp"
        const val EXTRA_SOURCE = "source"
    }

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "sendSleepBroadcast" -> {
                            val ts = call.argument<Number>("timestamp")?.toLong()
                                ?: System.currentTimeMillis()
                            val source = call.argument<String>("source") ?: "session"
                            sendSleepBroadcast(ts, source)
                            result.success(true)
                        }

                        // ---- Google Home lights (callbacks may come from any thread) ----
                        "checkAvailability" -> lights(context).checkAvailability { status, detail ->
                            reply(result, mapOf("status" to status, "detail" to detail))
                        }

                        "permissionState" -> lights(context).permissionState { state, name ->
                            reply(result, mapOf("state" to state, "structureName" to name))
                        }

                        "requestPermissions" -> lights(context).requestPermissions { r, detail ->
                            reply(result, mapOf("result" to r, "detail" to detail))
                        }

                        "listLights" -> lights(context).listLights { structures, error ->
                            if (structures != null) reply(result, structures)
                            else replyError(result, error ?: "listFailed")
                        }

                        "executeLightsOff" -> {
                            val labels = call.argument<Map<String, String>>("labels") ?: emptyMap()
                            lights(context).executeLightsOff(
                                deviceIds = call.argument<List<String>>("deviceIds") ?: emptyList(),
                                roomIds = call.argument<List<String>>("roomIds") ?: emptyList(),
                                fadeSeconds = call.argument<Int>("fadeSeconds") ?: 0,
                                labels = LightsController.NotificationLabels(
                                    title = labels["title"] ?: "SleepStop",
                                    body = labels["body"] ?: "",
                                    cancelButton = labels["cancelButton"] ?: "Cancel",
                                    channelName = labels["channelName"] ?: "SleepStop lights"
                                )
                            ) { started, error ->
                                reply(result, mapOf("started" to started, "error" to error))
                            }
                        }

                        "cancelAndRestore" -> lights(context).cancelAndRestore { restored, error ->
                            reply(result, mapOf("restored" to restored, "error" to error))
                        }

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("HOME_ACTIONS_ERROR", e.javaClass.simpleName, null)
                }
            }
    }

    private val main = Handler(Looper.getMainLooper())
    private fun reply(result: MethodChannel.Result, value: Any?) {
        main.post { try { result.success(value) } catch (_: Exception) {} }
    }
    private fun replyError(result: MethodChannel.Result, code: String) {
        main.post { try { result.error(code, null, null) } catch (_: Exception) {} }
    }

    /**
     * Implicit broadcast: delivered to receivers registered at runtime
     * (Tasker "Intent Received", Automate "Broadcast receive"). Manifest
     * receivers of other apps don't get implicit broadcasts since Android 8,
     * which is the documented limitation.
     */
    private fun sendSleepBroadcast(timestampMs: Long, source: String) {
        val intent = Intent(ACTION_SLEEP_DETECTED).apply {
            putExtra(EXTRA_TIMESTAMP, timestampMs)
            putExtra(EXTRA_SOURCE, source)
            addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
        }
        context.applicationContext.sendBroadcast(intent)
    }
}
