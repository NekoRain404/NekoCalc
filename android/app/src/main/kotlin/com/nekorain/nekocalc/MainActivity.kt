package com.nekorain.nekocalc

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val backupChannelName = "nekocalc/backup_file"
    private val hapticsChannelName = "nekocalc/haptics"
    private val exportRequestCode = 8101
    private val importRequestCode = 8102

    private var pendingExportContent: String? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "exportJson" -> {
                    if (pendingResult != null) {
                        result.error("busy", "另一个文件操作正在进行", null)
                        return@setMethodCallHandler
                    }
                    val fileName = call.argument<String>("fileName") ?: "nekocalc-backup.json"
                    val content = call.argument<String>("content") ?: ""
                    pendingExportContent = content
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, fileName)
                    }
                    startActivityForResult(intent, exportRequestCode)
                }

                "importJson" -> {
                    if (pendingResult != null) {
                        result.error("busy", "另一个文件操作正在进行", null)
                        return@setMethodCallHandler
                    }
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                    }
                    startActivityForResult(intent, importRequestCode)
                }

                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hapticsChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "tap" -> {
                    val strength = call.argument<String>("strength") ?: "标准"
                    performHapticTap(strength)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            exportRequestCode -> handleExportResult(resultCode, data?.data)
            importRequestCode -> handleImportResult(resultCode, data?.data)
        }
    }

    private fun handleExportResult(resultCode: Int, uri: Uri?) {
        val result = pendingResult ?: return
        val content = pendingExportContent ?: ""
        pendingResult = null
        pendingExportContent = null
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(false)
            return
        }
        try {
            contentResolver.openOutputStream(uri, "wt")?.use { stream ->
                stream.write(content.toByteArray(Charsets.UTF_8))
            } ?: throw IllegalStateException("无法打开输出文件")
            result.success(true)
        } catch (error: Exception) {
            result.error("export_failed", error.message, null)
        }
    }

    private fun handleImportResult(resultCode: Int, uri: Uri?) {
        val result = pendingResult ?: return
        pendingResult = null
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            val content = contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8).use { reader ->
                reader?.readText()
            } ?: throw IllegalStateException("无法读取备份文件")
            result.success(content)
        } catch (error: Exception) {
            result.error("import_failed", error.message, null)
        }
    }

    private fun performHapticTap(strength: String) {
        val amplitude = when (strength) {
            "轻" -> 45
            "强" -> 255
            else -> 135
        }
        val duration = when (strength) {
            "轻" -> 10L
            "强" -> 28L
            else -> 18L
        }
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = getSystemService(VibratorManager::class.java)
                manager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (!vibrator.hasVibrator()) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(duration, amplitude))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(duration)
            }
        } catch (_: Exception) {
        }
    }
}
