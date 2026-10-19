package com.sleepstop.sleep_stop.homeactions

import android.app.Activity

/**
 * Contract between the Flutter bridge and the Google Home implementation.
 * Two implementations exist:
 *  - [UnavailableLightsController] (always compiled): the SDK is not present
 *    or the device cannot use it;
 *  - GoogleHomeLightsController (compiled only when the Home APIs AARs are
 *    dropped in android/app/libs/homeapis, see build.gradle.kts).
 *
 * Everything is callback based so the stub needs no coroutines.
 */
interface LightsController {

    /** `available`, `unsupportedAndroid`, `playServicesMissing`,
     *  `playServicesOutdated`, `sdkMissing`, `sdkError`. */
    fun checkAvailability(callback: (status: String, detail: String?) -> Unit)

    /** `granted`, `notGranted`, `unavailable`, `uninitialized`, `error`. */
    fun permissionState(callback: (state: String, structureName: String?) -> Unit)

    /** Must be called from the Activity's onCreate (ActivityResultCaller). */
    fun bindActivity(activity: Activity)

    /** `granted`, `cancelled`, `error`. */
    fun requestPermissions(callback: (result: String, detail: String?) -> Unit)

    /**
     * Structures → rooms → devices exposing OnOff (and optionally LevelControl).
     * Serialised as plain maps so the bridge can pass them to Dart as is.
     */
    fun listLights(callback: (structures: List<Map<String, Any?>>?, error: String?) -> Unit)

    /**
     * Snapshots the selected lights, fades them over [fadeSeconds] (0 =
     * instant) then switches them off. Returns as soon as the fade is
     * running; progress and the "cancel" notification are handled natively.
     */
    fun executeLightsOff(
        deviceIds: List<String>,
        roomIds: List<String>,
        fadeSeconds: Int,
        labels: NotificationLabels,
        callback: (started: Boolean, error: String?) -> Unit
    )

    /** Stops a running fade and restores the snapshot (on/off + level). */
    fun cancelAndRestore(callback: (restored: Boolean, error: String?) -> Unit)

    data class NotificationLabels(
        val title: String,
        val body: String,
        val cancelButton: String,
        val channelName: String
    )
}

/** Used when the Home APIs SDK is not bundled or cannot run on this device. */
class UnavailableLightsController(private val status: String, private val detail: String?) :
    LightsController {

    override fun checkAvailability(callback: (String, String?) -> Unit) = callback(status, detail)
    override fun permissionState(callback: (String, String?) -> Unit) = callback("unavailable", null)
    override fun bindActivity(activity: Activity) {}
    override fun requestPermissions(callback: (String, String?) -> Unit) = callback("error", status)
    override fun listLights(callback: (List<Map<String, Any?>>?, String?) -> Unit) = callback(null, status)
    override fun executeLightsOff(
        deviceIds: List<String>,
        roomIds: List<String>,
        fadeSeconds: Int,
        labels: LightsController.NotificationLabels,
        callback: (Boolean, String?) -> Unit
    ) = callback(false, status)

    override fun cancelAndRestore(callback: (Boolean, String?) -> Unit) = callback(false, status)
}
