package dev.melune.melune.media

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.SimpleBasePlayer
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.CommandButton
import androidx.media3.session.SessionCommand
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.max
import kotlin.math.roundToInt

object MeluneMediaHub {
    const val CHANNEL = "dev.melune.media3"
    const val ACTION_FAVORITE = "dev.melune.favorite"
    const val ACTION_LYRICS = "dev.melune.lyrics"

    private val main = Handler(Looper.getMainLooper())
    private val lock = Any()
    var channel: MethodChannel? = null
    var player: MelunePlayer? = null
    var onButtonsChanged: (() -> Unit)? = null

    @Volatile
    var serviceRunning = false

    @Volatile
    var snapshot: Snapshot = Snapshot()

    fun bind(context: Context, messenger: BinaryMessenger) {
        val bound = player ?: MelunePlayer(context.applicationContext).also { player = it }
        channel = MethodChannel(messenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                        synchronized(lock) {
                            snapshot = Snapshot.from(args)
                        }
                        main.post {
                            bound.publish()
                            onButtonsChanged?.invoke()
                            ensureService(context.applicationContext)
                        }
                        Thread {
                            prepareArtwork(context.applicationContext)
                            main.post {
                                bound.publish()
                                onButtonsChanged?.invoke()
                            }
                        }.start()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun ensureService(context: Context) {
        val intent = android.content.Intent(context, MelunePlaybackService::class.java)
        if (!snapshot.enabled) {
            serviceRunning = false
            runCatching { context.stopService(intent) }
            return
        }
        if (serviceRunning) {
            return
        }
        try {
            androidx.core.content.ContextCompat.startForegroundService(context, intent)
        } catch (_: Exception) {
            runCatching { context.startService(intent) }
        }
    }

    fun send(action: String, extras: Any? = null) {
        main.post {
            runCatching { channel?.invokeMethod(action, extras) }
        }
    }

    fun customButtons(): List<CommandButton> {
        val liked = snapshot.liked
        val favorite = CommandButton.Builder(
            if (liked) CommandButton.ICON_HEART_FILLED else CommandButton.ICON_HEART_UNFILLED,
        )
            .setDisplayName(if (liked) "取消喜欢" else "喜欢")
            .setSessionCommand(SessionCommand(ACTION_FAVORITE, Bundle.EMPTY))
            .setEnabled(snapshot.enabled)
            .build()
        val lyrics = CommandButton.Builder(CommandButton.ICON_CLOSED_CAPTIONS)
            .setDisplayName("歌词")
            .setSessionCommand(SessionCommand(ACTION_LYRICS, Bundle.EMPTY))
            .setEnabled(snapshot.enabled)
            .build()
        return listOf(favorite, lyrics)
    }

    private fun prepareArtwork(context: Context) {
        val path = synchronized(lock) { snapshot.artworkPath }
        if (path.isNullOrEmpty()) {
            synchronized(lock) {
                snapshot = snapshot.copy(artworkUri = null, artworkBytes = null)
            }
            return
        }
        val source = File(path)
        if (!source.isFile) {
            synchronized(lock) {
                if (snapshot.artworkPath == path) {
                    snapshot = snapshot.copy(artworkUri = null, artworkBytes = null)
                }
            }
            return
        }
        try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            var sample = 1
            val longest = max(bounds.outWidth, bounds.outHeight).coerceAtLeast(1)
            while (longest / sample > 512) {
                sample *= 2
            }
            val decoded = BitmapFactory.decodeFile(
                path,
                BitmapFactory.Options().apply { inSampleSize = sample },
            ) ?: return
            val size = max(decoded.width, decoded.height).coerceAtLeast(1)
            val bitmap = if (size > 512) {
                val scale = 512f / size
                Bitmap.createScaledBitmap(
                    decoded,
                    (decoded.width * scale).roundToInt().coerceAtLeast(1),
                    (decoded.height * scale).roundToInt().coerceAtLeast(1),
                    true,
                )
            } else {
                decoded
            }
            val outFile = File(context.cacheDir, "media_art/cover.jpg").apply {
                parentFile?.mkdirs()
            }
            outFile.outputStream().use { stream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
            }
            val bytes = ByteArrayOutputStream().use { stream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
                stream.toByteArray()
            }
            if (bitmap != decoded) {
                bitmap.recycle()
            }
            decoded.recycle()
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.artwork",
                outFile,
            )
            // SystemUI 主要吃 artworkData；content URI 给能读 FileProvider 的控制器作备份。
            snapshot = synchronized(lock) {
                if (snapshot.artworkPath == path) {
                    snapshot.copy(artworkUri = uri, artworkBytes = bytes)
                } else {
                    snapshot
                }
            }
        } catch (_: Exception) {
            synchronized(lock) {
                if (snapshot.artworkPath == path) {
                    snapshot = snapshot.copy(artworkUri = null, artworkBytes = null)
                }
            }
        }
    }

    data class QueueEntry(
        val id: String,
        val title: String,
        val artist: String,
        val album: String,
        val durationMs: Long,
    )

    data class Snapshot(
        val enabled: Boolean = false,
        val playing: Boolean = false,
        val loading: Boolean = false,
        val liked: Boolean = false,
        val positionMs: Long = 0,
        val durationMs: Long = 0,
        val index: Int = 0,
        val id: String = "",
        val title: String = "",
        val artist: String = "",
        val album: String = "",
        val artworkPath: String? = null,
        val artworkUri: Uri? = null,
        val artworkBytes: ByteArray? = null,
        val queue: List<QueueEntry> = emptyList(),
    ) {
        companion object {
            fun from(args: Map<*, *>): Snapshot {
                val queue = (args["queue"] as? List<*>)?.mapNotNull { raw ->
                    val item = raw as? Map<*, *> ?: return@mapNotNull null
                    QueueEntry(
                        id = item["id"] as? String ?: return@mapNotNull null,
                        title = item["title"] as? String ?: "",
                        artist = item["artist"] as? String ?: "",
                        album = item["album"] as? String ?: "",
                        durationMs = (item["durationMs"] as? Number)?.toLong() ?: 0L,
                    )
                } ?: emptyList()
                return Snapshot(
                    enabled = args["enabled"] as? Boolean ?: false,
                    playing = args["playing"] as? Boolean ?: false,
                    loading = args["loading"] as? Boolean ?: false,
                    liked = args["liked"] as? Boolean ?: false,
                    positionMs = (args["positionMs"] as? Number)?.toLong() ?: 0L,
                    durationMs = (args["durationMs"] as? Number)?.toLong() ?: 0L,
                    index = (args["index"] as? Number)?.toInt() ?: 0,
                    id = args["id"] as? String ?: "",
                    title = args["title"] as? String ?: "",
                    artist = args["artist"] as? String ?: "",
                    album = args["album"] as? String ?: "",
                    artworkPath = args["artworkPath"] as? String,
                    queue = queue,
                )
            }
        }
    }
}

@UnstableApi
class MelunePlayer(context: Context) : SimpleBasePlayer(Looper.getMainLooper()) {

    fun publish() {
        Handler(Looper.getMainLooper()).post { invalidateState() }
    }

    override fun getState(): State {
        val snap = MeluneMediaHub.snapshot
        val commands = Player.Commands.Builder()
            .addAll(
                Player.COMMAND_PLAY_PAUSE,
                Player.COMMAND_PREPARE,
                Player.COMMAND_STOP,
                Player.COMMAND_SEEK_IN_CURRENT_MEDIA_ITEM,
                Player.COMMAND_SEEK_TO_DEFAULT_POSITION,
                Player.COMMAND_SEEK_BACK,
                Player.COMMAND_SEEK_FORWARD,
                Player.COMMAND_SEEK_TO_PREVIOUS,
                Player.COMMAND_SEEK_TO_NEXT,
                Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM,
                Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM,
                Player.COMMAND_SEEK_TO_MEDIA_ITEM,
                Player.COMMAND_GET_CURRENT_MEDIA_ITEM,
                Player.COMMAND_GET_METADATA,
                Player.COMMAND_GET_TIMELINE,
                Player.COMMAND_GET_AUDIO_ATTRIBUTES,
            )
            .build()
        val builder = State.Builder()
            .setAvailableCommands(commands)
            .setSeekBackIncrementMs(10_000)
            .setSeekForwardIncrementMs(10_000)
        if (!snap.enabled || snap.id.isEmpty()) {
            return builder
                .setPlayWhenReady(false, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
                .setPlaybackState(Player.STATE_IDLE)
                .build()
        }
        val playlist = if (snap.queue.isEmpty()) {
            listOf(itemData(snap.id, snap.title, snap.artist, snap.album, snap.durationMs, true))
        } else {
            snap.queue.mapIndexed { index, entry ->
                itemData(
                    uid = "$index:${entry.id}",
                    title = entry.title,
                    artist = entry.artist,
                    album = entry.album,
                    durationMs = entry.durationMs,
                    current = index == snap.index.coerceIn(0, snap.queue.lastIndex),
                )
            }
        }
        val playbackState = when {
            !snap.enabled || snap.id.isEmpty() -> Player.STATE_IDLE
            snap.loading && !snap.playing -> Player.STATE_BUFFERING
            else -> Player.STATE_READY
        }
        return builder
            .setPlaylist(playlist)
            .setCurrentMediaItemIndex(snap.index.coerceIn(0, (playlist.size - 1).coerceAtLeast(0)))
            .setContentPositionMs(snap.positionMs.coerceAtLeast(0))
            .setPlayWhenReady(snap.playing, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
            .setPlaybackParameters(PlaybackParameters.DEFAULT)
            .setPlaybackState(playbackState)
            .build()
    }

    private fun itemData(
        uid: String,
        title: String,
        artist: String,
        album: String,
        durationMs: Long,
        current: Boolean,
    ): MediaItemData {
        val snap = MeluneMediaHub.snapshot
        val metadata = MediaMetadata.Builder()
            .setTitle(title.ifEmpty { snap.title })
            .setArtist(artist.ifEmpty { snap.artist })
            .setAlbumTitle(album.ifEmpty { snap.album })
            .setAlbumArtist(artist.ifEmpty { snap.artist })
            .setMediaType(MediaMetadata.MEDIA_TYPE_MUSIC)
            .setIsBrowsable(false)
            .setIsPlayable(true)
        if (current) {
            snap.artworkUri?.let(metadata::setArtworkUri)
            snap.artworkBytes?.let { metadata.setArtworkData(it, MediaMetadata.PICTURE_TYPE_FRONT_COVER) }
        }
        val mediaItem = MediaItem.Builder()
            .setMediaId(uid)
            .setMediaMetadata(metadata.build())
            .build()
        val durationUs = if (durationMs > 0) durationMs * 1_000 else C.TIME_UNSET
        return MediaItemData.Builder(uid)
            .setMediaItem(mediaItem)
            .setDurationUs(durationUs)
            .setIsSeekable(durationMs > 0)
            .build()
    }

    override fun handleSetPlayWhenReady(playWhenReady: Boolean): ListenableFuture<*> {
        MeluneMediaHub.send(if (playWhenReady) "play" else "pause")
        return Futures.immediateVoidFuture()
    }

    override fun handlePrepare(): ListenableFuture<*> = Futures.immediateVoidFuture()

    override fun handleStop(): ListenableFuture<*> {
        MeluneMediaHub.send("pause")
        return Futures.immediateVoidFuture()
    }

    override fun handleSeek(
        mediaItemIndex: Int,
        positionMs: Long,
        seekCommand: Int,
    ): ListenableFuture<*> {
        when (seekCommand) {
            Player.COMMAND_SEEK_TO_NEXT, Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM ->
                MeluneMediaHub.send("next")
            Player.COMMAND_SEEK_TO_PREVIOUS, Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM ->
                MeluneMediaHub.send("previous")
            Player.COMMAND_SEEK_FORWARD ->
                MeluneMediaHub.send("next")
            Player.COMMAND_SEEK_BACK ->
                MeluneMediaHub.send("previous")
            else -> {
                val current = MeluneMediaHub.snapshot.index
                if (mediaItemIndex >= 0 && mediaItemIndex != current) {
                    MeluneMediaHub.send("playAt", mediaItemIndex)
                } else {
                    MeluneMediaHub.send("seek", positionMs.coerceAtLeast(0))
                }
            }
        }
        return Futures.immediateVoidFuture()
    }
}
