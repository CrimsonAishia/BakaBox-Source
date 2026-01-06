package cc.aishia.bakabox

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "cc.aishia.bakabox/install"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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