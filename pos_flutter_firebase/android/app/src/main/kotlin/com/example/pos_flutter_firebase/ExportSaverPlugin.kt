package com.example.pos_flutter_firebase

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream

class ExportSaverPlugin : FlutterPlugin, MethodCallHandler {
  private var channel: MethodChannel? = null
  private var context: Context? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, CHANNEL)
    channel?.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel?.setMethodCallHandler(null)
    channel = null
    context = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "saveToDownloads" -> {
        val name = call.argument<String>("name") ?: "export"
        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null) {
          result.error("BYTES_NULL", "bytes is null", null)
          return
        }
        try {
          val location = saveToDownloads(name, mimeType, bytes)
          result.success(location)
        } catch (e: Exception) {
          result.error("SAVE_FAILED", e.message, null)
        }
      }
      else -> result.notImplemented()
    }
  }

  private fun saveToDownloads(fileName: String, mimeType: String, bytes: ByteArray): String {
    val appContext = context ?: throw IllegalStateException("Context unavailable")
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val values = ContentValues().apply {
        put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
        put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        put(MediaStore.MediaColumns.IS_PENDING, 1)
      }
      val resolver = appContext.contentResolver
      val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
        ?: throw IllegalStateException("Could not create file in Downloads")
      try {
        val stream = resolver.openOutputStream(uri)
          ?: throw IllegalStateException("Could not open output stream")
        stream.use { it.write(bytes) }
      } catch (e: Exception) {
        resolver.delete(uri, null, null)
        throw e
      }
      values.clear()
      values.put(MediaStore.MediaColumns.IS_PENDING, 0)
      resolver.update(uri, values, null, null)
      return uri.toString()
    } else {
      val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
      if (!dir.exists() && !dir.mkdirs()) {
        throw IllegalStateException("Could not create Downloads directory")
      }
      val file = File(dir, fileName)
      FileOutputStream(file).use { it.write(bytes) }
      return file.absolutePath
    }
  }

  private companion object {
    const val CHANNEL = "com.lolo.posllo/export_saver"
  }
}
