package com.sleepstop.sleep_stop

import android.service.notification.NotificationListenerService

/**
 * Allows MediaSessionManager.getActiveSessions() to inspect the active external
 * media player's package name (Audible, YouTube, Spotify, etc.) and current
 * track/chapter title when granted Notification Listener access.
 */
class SleepStopMediaListenerService : NotificationListenerService()
