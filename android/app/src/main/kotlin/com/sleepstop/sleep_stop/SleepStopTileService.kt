package com.sleepstop.sleep_stop

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Android Quick Settings Tile ("Tuile de lancement rapide") for SleepStop.
 * Allows the user to start or stop biometric sleep monitoring in 1 tap directly
 * from the Android notification shade while watching YouTube, Netflix, or listening to Audible.
 */
class SleepStopTileService : TileService() {

    companion object {
        private const val PREFS_NAME = "sleepstop_qs_tile"
        private const val KEY_IS_ACTIVE = "is_active"
        private const val KEY_SUBTITLE = "subtitle"
        const val ACTION_QUICK_TILE_TOGGLE = "com.sleepstop.sleep_stop.ACTION_QUICK_TILE_TOGGLE"

        fun updateTileState(context: Context, isActive: Boolean, subtitle: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_IS_ACTIVE, isActive)
                .putString(KEY_SUBTITLE, subtitle)
                .apply()

            try {
                requestListeningState(
                    context,
                    ComponentName(context, SleepStopTileService::class.java)
                )
            } catch (_: Exception) {
            }
        }

        fun isTileMarkedActive(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_IS_ACTIVE, false)
        }

        fun getTileSubtitle(context: Context): String {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getString(KEY_SUBTITLE, null)
                ?: if (isTileMarkedActive(context)) "Veille active" else "Prêt à veiller"
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        refreshTileUi()
    }

    override fun onTileAdded() {
        super.onTileAdded()
        refreshTileUi()
    }

    override fun onClick() {
        super.onClick()

        val currentlyActive = isTileMarkedActive(applicationContext)
        // If Flutter engine is alive in memory, toggle directly in background without leaving current app!
        val handledInBackground = MainActivity.dispatchQuickTileToggleFromService()

        if (handledInBackground) {
            val nextActive = !currentlyActive
            val nextSubtitle = if (nextActive) "Démarrage..." else "Arrêté"
            updateTileState(applicationContext, nextActive, nextSubtitle)
            refreshTileUi()
        } else {
            // Cold start: launch MainActivity and instruct it to start the sleep session automatically
            updateTileState(applicationContext, true, "Démarrage...")
            refreshTileUi()
            launchMainActivityAndCollapse()
        }
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    @Suppress("DEPRECATION")
    private fun launchMainActivityAndCollapse() {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_QUICK_TILE_TOGGLE
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pendingIntent = PendingIntent.getActivity(
                this,
                9102,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            startActivityAndCollapse(intent)
        }
    }

    private fun refreshTileUi() {
        val tile = qsTile ?: return
        val active = isTileMarkedActive(applicationContext)
        val subtitle = getTileSubtitle(applicationContext)

        tile.state = if (active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = "SleepStop"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = subtitle
        }
        tile.updateTile()
    }
}
