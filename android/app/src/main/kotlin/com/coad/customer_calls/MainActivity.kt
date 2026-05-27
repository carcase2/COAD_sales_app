package com.coad.customer_calls

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // singleTop + 알림 탭 시 Intent가 Flutter(로컬 알림/FCM)로 전달되도록 필요
        setIntent(intent)
    }
}
