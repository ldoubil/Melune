package dev.melune.melune.media

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionResult
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import dev.melune.melune.MainActivity
import dev.melune.melune.R

@UnstableApi
class MelunePlaybackService : MediaSessionService() {
    private var session: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
        val notifications = DefaultMediaNotificationProvider.Builder(this)
            .setChannelId(CHANNEL_ID)
            .setChannelName(R.string.playback_channel_name)
            .build()
        notifications.setSmallIcon(R.drawable.ic_stat_melune)
        setMediaNotificationProvider(notifications)
        val player = MeluneMediaHub.player ?: MelunePlayer(applicationContext).also {
            MeluneMediaHub.player = it
        }
        val activity = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        session = MediaSession.Builder(this, player)
            .setId("melune")
            .setSessionActivity(activity)
            .setCallback(MeluneSessionCallback())
            .build()
        MeluneMediaHub.onButtonsChanged = {
            val buttons = MeluneMediaHub.customButtons()
            session?.setCustomLayout(buttons)
            session?.setMediaButtonPreferences(buttons)
        }
        val buttons = MeluneMediaHub.customButtons()
        session?.setCustomLayout(buttons)
        session?.setMediaButtonPreferences(buttons)
        player.publish()
        enterForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        enterForeground()
        return super.onStartCommand(intent, flags, startId)
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return session
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        val playing = MeluneMediaHub.snapshot.playing
        if (!playing) {
            session?.player?.stop()
            stopSelf()
        }
    }

    override fun onDestroy() {
        MeluneMediaHub.onButtonsChanged = null
        session?.release()
        session = null
        super.onDestroy()
    }

    private fun enterForeground() {
        val snap = MeluneMediaHub.snapshot
        val title = snap.title.ifEmpty { getString(R.string.playback_channel_name) }
        val text = snap.artist.ifEmpty { "Melune · 洛音" }
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_melune)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(snap.playing || snap.enabled)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .build()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        } else {
            0
        }
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) {
            return
        }
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.playback_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                setShowBadge(false)
                setSound(null, null)
            },
        )
    }

    companion object {
        const val CHANNEL_ID = "dev.melune.melune.playback"
        const val NOTIFICATION_ID = DefaultMediaNotificationProvider.DEFAULT_NOTIFICATION_ID
    }
}

@UnstableApi
private class MeluneSessionCallback : MediaSession.Callback {
    override fun onConnect(
        session: MediaSession,
        controller: MediaSession.ControllerInfo,
    ): MediaSession.ConnectionResult {
        val sessionCommands = MediaSession.ConnectionResult.DEFAULT_SESSION_AND_LIBRARY_COMMANDS
            .buildUpon()
            .add(SessionCommand(MeluneMediaHub.ACTION_FAVORITE, Bundle.EMPTY))
            .add(SessionCommand(MeluneMediaHub.ACTION_LYRICS, Bundle.EMPTY))
            .build()
        return MediaSession.ConnectionResult.AcceptedResultBuilder(session)
            .setAvailableSessionCommands(sessionCommands)
            .setCustomLayout(MeluneMediaHub.customButtons())
            .setMediaButtonPreferences(MeluneMediaHub.customButtons())
            .build()
    }

    override fun onCustomCommand(
        session: MediaSession,
        controller: MediaSession.ControllerInfo,
        customCommand: SessionCommand,
        args: Bundle,
    ): ListenableFuture<SessionResult> {
        when (customCommand.customAction) {
            MeluneMediaHub.ACTION_FAVORITE -> MeluneMediaHub.send("favorite")
            MeluneMediaHub.ACTION_LYRICS -> MeluneMediaHub.send("lyrics")
            else -> return Futures.immediateFuture(SessionResult(SessionResult.RESULT_ERROR_NOT_SUPPORTED))
        }
        return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
    }
}
