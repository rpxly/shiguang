package com.example.shiguang

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

/// Health Connect 权限说明页：系统在权限弹窗中点击「隐私政策」时打开。
class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val tv = TextView(this)
        tv.setPadding(64, 96, 64, 64)
        tv.textSize = 16f
        tv.text = "拾光需要读取您的步数数据，用于在月刊中自动展示本月步数。" +
            "步数数据仅在本机读取与展示，不会上传到任何服务器。" +
            "您也可以在月刊中手动填写步数，关闭本权限不影响其他功能。"
        setContentView(tv)
    }
}
