package com.example.shiguang

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// 继承 FlutterFragmentActivity（androidx ComponentActivity）：
// health 插件的 Health Connect 权限弹窗要求宿主 Activity 为 ComponentActivity，
// 用 FlutterActivity 会导致 requestAuthorization 静默失败、永远不弹授权框。
class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.shiguang/storage_permission"
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isStorageManagerGranted" -> {
                    result.success(isStorageManagerGranted())
                }
                "requestStorageManager" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        if (Environment.isExternalStorageManager()) {
                            result.success(true)
                        } else {
                            permissionResult = result
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivityForResult(intent, 1001)
                        }
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1001) {
            permissionResult?.success(isStorageManagerGranted())
            permissionResult = null
        }
    }

    private fun isStorageManagerGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true
        }
    }
}
