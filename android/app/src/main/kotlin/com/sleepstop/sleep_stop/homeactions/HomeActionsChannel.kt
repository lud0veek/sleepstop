package com.sleepstop.sleep_stop.homeactions

import android.content.Context
import android.content.Intent
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

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("HOME_ACTIONS_ERROR", e.javaClass.simpleName, null)
                }
            }
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
