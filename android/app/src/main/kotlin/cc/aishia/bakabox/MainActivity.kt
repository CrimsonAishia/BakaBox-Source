package cc.aishia.bakabox

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.WindowManager
import android.webkit.CookieManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val INSTALL_CHANNEL = "cc.aishia.bakabox/install"
    private val COOKIE_CHANNEL = "cc.aishia.bakabox/cookie"
    private val WAKELOCK_CHANNEL = "cc.aishia.bakabox/wakelock"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // APK 安装 Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        installApk(path, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "APK path is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Cookie 获取 Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COOKIE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookies" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        getCookies(url, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "URL is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 屏幕常亮 Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WAKELOCK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    runOnUiThread {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(true)
                }
                "disable" -> {
                    runOnUiThread {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun getCookies(url: String, result: MethodChannel.Result) {
        try {
            val cookieManager = CookieManager.getInstance()
            val cookieString = cookieManager.getCookie(url)
            
            if (cookieString.isNullOrEmpty()) {
                result.success(emptyList<Map<String, String>>())
                return
            }
            
            // 解析 cookie 字符串为 List<Map<String, String>>
            val cookies = cookieString.split(";").mapNotNull { cookie ->
                val parts = cookie.trim().split("=", limit = 2)
                if (parts.size == 2) {
                    mapOf("name" to parts[0].trim(), "value" to parts[1].trim())
                } else {
                    null
                }
            }
            
            result.success(cookies)
        } catch (e: Exception) {
            result.error("COOKIE_ERROR", "Failed to get cookies: ${e.message}", null)
        }
    }

    private fun installApk(apkPath: String, result: MethodChannel.Result) {
        try {
            val apkFile = File(apkPath)
            if (!apkFile.exists()) {
                result.error("FILE_NOT_FOUND", "APK file not found: $apkPath", null)
                return
            }

            val intent = Intent(Intent.ACTION_VIEW)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

            val apkUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // Android 7.0+ 需要使用 FileProvider
                intent.flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
                FileProvider.getUriForFile(this, "$packageName.fileprovider", apkFile)
            } else {
                Uri.fromFile(apkFile)
            }

            intent.setDataAndType(apkUri, "application/vnd.android.package-archive")
            startActivity(intent)
            result.success("APK installation started")
            
        } catch (e: Exception) {
            result.error("INSTALL_ERROR", "Failed to install APK: ${e.message}", null)
        }
    }
}