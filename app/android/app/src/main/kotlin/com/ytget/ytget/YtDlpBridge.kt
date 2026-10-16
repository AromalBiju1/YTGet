package com.ytget.ytget

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class YtDlpBridge(private val appContext: Context) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> executor.execute {
                try {
                    YoutubeDL.getInstance().init(appContext)
                    FFmpeg.getInstance().init(appContext)
                    mainHandler.post { result.success(true) }
                } catch (e: Exception) {
                    mainHandler.post { result.error("INIT_FAILED", e.message, null) }
                }
            }
            "getInfo" -> {
                val url = call.argument<String>("url")
                    ?: return result.error("BAD_ARGS", "missing url", null)
                executor.execute {
                    try {
                        val info = YoutubeDL.getInstance().getInfo(url)
                        val thumb = info.thumbnail
                            ?: info.thumbnails?.lastOrNull()?.url
                            ?: ""
                        val map = mapOf(
                            "title" to (info.title ?: "Unknown"),
                            "author" to (info.uploader ?: ""),
                            "thumb" to thumb,
                            "durSec" to info.duration
                        )
                        mainHandler.post { result.success(map) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("INFO_FAILED", firstLine(e), null) }
                    }
                }
            }
            "download" -> {
                val processId = call.argument<String>("processId")
                    ?: return result.error("BAD_ARGS", "missing processId", null)
                val url = call.argument<String>("url")
                    ?: return result.error("BAD_ARGS", "missing url", null)
                @Suppress("UNCHECKED_CAST")
                val options = call.argument<List<String>>("options") ?: emptyList()
                executor.execute {
                    try {
                        val request = YoutubeDLRequest(url)
                        applyOptions(request, options)
                        YoutubeDL.getInstance().execute(request, processId) { progress, eta, _ ->
                            postEvent(mapOf("processId" to processId, "progress" to progress, "eta" to eta))
                        }
                        postEvent(mapOf("processId" to processId, "done" to true))
                        mainHandler.post { result.success(true) }
                    } catch (e: Exception) {
                        postEvent(mapOf("processId" to processId, "error" to firstLine(e)))
                        mainHandler.post { result.error("DOWNLOAD_FAILED", firstLine(e), null) }
                    }
                }
            }
            "cancel" -> {
                val processId = call.argument<String>("processId")
                val ok = if (processId != null) {
                    YoutubeDL.getInstance().destroyProcessById(processId)
                } else false
                result.success(ok)
            }
            "update" -> executor.execute {
                try {
                    val status = YoutubeDL.getInstance()
                        .updateYoutubeDL(appContext, YoutubeDL.UpdateChannel.STABLE)
                    mainHandler.post { result.success(status?.name ?: "UNKNOWN") }
                } catch (e: Exception) {
                    mainHandler.post { result.error("UPDATE_FAILED", firstLine(e), null) }
                }
            }
            "version" -> executor.execute {
                try {
                    val v = YoutubeDL.getInstance().version(appContext) ?: "unknown"
                    mainHandler.post { result.success(v) }
                } catch (e: Exception) {
                    mainHandler.post { result.error("VERSION_FAILED", firstLine(e), null) }
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun applyOptions(request: YoutubeDLRequest, options: List<String>) {
        var i = 0
        while (i < options.size) {
            val token = options[i]
            if (token.startsWith("-") && i + 1 < options.size && !options[i + 1].startsWith("-")) {
                request.addOption(token, options[i + 1])
                i += 2
            } else {
                request.addOption(token)
                i += 1
            }
        }
    }

    private fun postEvent(event: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(event) }
    }

    private fun firstLine(e: Exception): String {
        return (e.message ?: e.toString()).lineSequence().firstOrNull()?.take(300)
            ?: "unknown error"
    }
}
