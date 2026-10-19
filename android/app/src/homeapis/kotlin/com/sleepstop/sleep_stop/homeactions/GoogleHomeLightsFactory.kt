package com.sleepstop.sleep_stop.homeactions

import android.content.Context
import android.os.Build
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability

/**
 * Compiled only when the Home APIs AARs are present (see build.gradle.kts).
 * Decides at runtime whether this device can use the SDK, then hands out the
 * real controller.
 */
object GoogleHomeLightsFactory {
    const val SDK_BUNDLED = true

    /** Minimum Google Play services for Home APIs 1.11 (release notes). */
    private const val MIN_PLAY_SERVICES_VERSION_CODE = 263_625_000

    fun create(context: Context): LightsController {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return UnavailableLightsController("unsupportedAndroid", "Android 10+ required")
        }
        val availability = GoogleApiAvailability.getInstance()
        when (availability.isGooglePlayServicesAvailable(context)) {
            ConnectionResult.SUCCESS -> Unit
            ConnectionResult.SERVICE_VERSION_UPDATE_REQUIRED ->
                return UnavailableLightsController("playServicesOutdated", null)
            else -> return UnavailableLightsController("playServicesMissing", null)
        }
        val versionCode = try {
            val info = context.packageManager.getPackageInfo("com.google.android.gms", 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else {
                @Suppress("DEPRECATION") info.versionCode.toLong()
            }
        } catch (_: Exception) {
            0L
        }
        if (versionCode in 1 until MIN_PLAY_SERVICES_VERSION_CODE) {
            return UnavailableLightsController("playServicesOutdated", "Play services $versionCode")
        }
        return try {
            GoogleHomeLightsController(context.applicationContext)
        } catch (e: Throwable) {
            UnavailableLightsController("sdkError", e.javaClass.simpleName)
        }
    }
}
