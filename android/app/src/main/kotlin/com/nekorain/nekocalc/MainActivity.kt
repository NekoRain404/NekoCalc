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
import com.nekorain.nekocalc.qalculate.QalculateEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val backupChannelName = "nekocalc/backup_file"
    private val documentExportChannelName = "nekocalc/document_export"
    private val appLinkChannelName = "nekocalc/app_link"
    private val hapticsChannelName = "nekocalc/haptics"
    private val qalculateChannelName = "nekocalc/qalculate"
    private val exportRequestCode = 8101
    private val importRequestCode = 8102
    private val documentExportRequestCode = 8103

    // 中文：引擎必须提成字段。每次调用新建一个的话，每次调用都会重新加载一遍全局定义。
    //       内部的 Calculator 是 by lazy，所以这里构造很便宜。
    // English: The engine must be hoisted to a field. Building one per call would reload the global
    //          definitions on every call. Its internal Calculator is `by lazy`, so constructing
    //          this is cheap.
    private val qalculateEngine = QalculateEngine()

    private var pendingExportContent: String? = null
    private var pendingDocumentBytes: ByteArray? = null
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
                    // 中文：⚠️ **必须包住，同文件的 `exportBytes` 早就这么包了。** 没有处理
                    //       `ACTION_CREATE_DOCUMENT` 的 Activity 时（精简系统、某些受管设备配置）它会抛
                    //       `ActivityNotFoundException`，而这一路**没有外层 catch**：异常会跨平台线程崩掉，
                    //       而且 `pendingResult` 会**永远留在非空**——此后每一次备份调用都会立刻返回
                    //       `busy`（见 `:43` 与 `:60` 的守卫），**导出与导入在这一进程的生命周期里彻底死掉**。
                    //       捕获后把状态复位并如实回一个错误，后续调用才能继续可用。
                    // English: ⚠️ **this must be guarded; the sibling `exportBytes` above has always done so.**
                    //          On a device with no activity handling `ACTION_CREATE_DOCUMENT` (stripped
                    //          images, some managed-device profiles) it throws `ActivityNotFoundException`,
                    //          and this path has **no outer catch**: the exception crosses the platform
                    //          thread and crashes, and `pendingResult` is left **non-null forever** — every
                    //          later backup call then returns `busy` immediately (see the guards at `:43`
                    //          and `:60`), so **export and import are dead for the life of the process**.
                    //          Catching it clears the state and answers with a real error, so later calls
                    //          keep working.
                    try {
                        startActivityForResult(intent, exportRequestCode)
                    } catch (error: Exception) {
                        pendingExportContent = null
                        pendingResult = null
                        result.error("export_unavailable", error.message, null)
                    }
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
                    // 中文：同 `exportJson`——这一路同样没有外层 catch，不包住就会**崩 + 把通道永久卡在 busy**。
                    // English: as in `exportJson` — no outer catch here either; unguarded, it both throws
                    //          across the platform thread and wedges the channel on `busy` permanently.
                    try {
                        startActivityForResult(intent, importRequestCode)
                    } catch (error: Exception) {
                        pendingResult = null
                        result.error("import_unavailable", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, documentExportChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "exportBytes" -> {
                    if (pendingResult != null) {
                        result.error("busy", "另一个文件操作正在进行", null)
                        return@setMethodCallHandler
                    }
                    val fileName = call.argument<String>("fileName") ?: "nekocalc-export"
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("invalid_content", "导出内容为空", null)
                        return@setMethodCallHandler
                    }
                    pendingDocumentBytes = bytes
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mimeType
                        putExtra(Intent.EXTRA_TITLE, fileName)
                    }
                    try {
                        startActivityForResult(intent, documentExportRequestCode)
                    } catch (error: Exception) {
                        pendingDocumentBytes = null
                        pendingResult = null
                        result.error("export_unavailable", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appLinkChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val rawUrl = call.argument<String>("url")
                    val uri = rawUrl?.let(Uri::parse)
                    if (uri == null || (uri.scheme != "https" && uri.scheme != "http")) {
                        result.error("invalid_url", "仅支持打开 HTTP(S) 链接", null)
                        return@setMethodCallHandler
                    }
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, uri))
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("open_failed", error.message, null)
                    }
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
        // 中文：libqalculate 原生引擎。求值入口由提交路径（按下等号）使用；边打边算仍在 Dart 侧。
        // English: The native libqalculate engine. The submit path (pressed =) uses the evaluation
        //          entry point; as-you-type evaluation stays on the Dart side.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, qalculateChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "evaluate" -> {
                    val expression = call.argument<String>("expression")
                    if (expression == null) {
                        result.error("invalid_expression", "缺少 expression 参数", null)
                        return@setMethodCallHandler
                    }
                    // 中文：角度模式必须显式传下来，缺失就拒绝——不猜默认值。角度单位决定
                    //       sin/cos 的自变量怎么解释，猜错的代价是一个算错的答案，而不是一条错误。
                    // English: The angle mode must be passed explicitly; a missing one is rejected
                    //          rather than defaulted. The angle unit decides how sin/cos arguments
                    //          are read, and guessing wrong costs a wrong answer rather than an error.
                    val angleMode = call.argument<String>("angleMode")
                    if (angleMode == null) {
                        result.error("invalid_angle_mode", "缺少 angleMode 参数", null)
                        return@setMethodCallHandler
                    }
                    // 中文：在引擎线程上回复，主线程不等待引擎。
                    // English: Reply from the engine thread; the main thread does not wait.
                    qalculateEngine.evaluateAsync(expression, angleMode) { payload -> result.success(payload) }
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
            documentExportRequestCode -> handleDocumentExportResult(resultCode, data?.data)
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

    private fun handleDocumentExportResult(resultCode: Int, uri: Uri?) {
        val result = pendingResult ?: return
        val bytes = pendingDocumentBytes
        pendingResult = null
        pendingDocumentBytes = null
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(false)
            return
        }
        if (bytes == null) {
            result.error("export_failed", "导出内容已丢失", null)
            return
        }
        try {
            contentResolver.openOutputStream(uri, "wt")?.use { stream ->
                stream.write(bytes)
            } ?: throw IllegalStateException("无法打开输出文件")
            result.success(true)
        } catch (error: Exception) {
            result.error("export_failed", error.message, null)
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
