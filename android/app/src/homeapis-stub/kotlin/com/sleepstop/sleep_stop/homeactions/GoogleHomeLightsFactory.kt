package com.sleepstop.sleep_stop.homeactions

import android.content.Context

/**
 * Compiled when android/app/libs/homeapis contains no Home APIs AAR.
 * The real factory lives in src/homeapis/kotlin and is selected by Gradle
 * when the SDK is present.
 */
object GoogleHomeLightsFactory {
    const val SDK_BUNDLED = false

    fun create(context: Context): LightsController =
        UnavailableLightsController("sdkMissing", "Home APIs SDK not bundled in this build")
}
