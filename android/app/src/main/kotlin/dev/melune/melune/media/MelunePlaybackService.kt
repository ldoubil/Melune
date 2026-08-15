package dev.melune.melune.media

import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionResult
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import dev.melune.melune.MainActivity

@UnstableApi
class MelunePlaybackService : MediaSessionService() {
    private var session: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
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
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return session
    }

    override fun onDestroy() {
        MeluneMediaHub.onButtonsChanged = null
        session?.release()
        session = null
        super.onDestroy()
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
