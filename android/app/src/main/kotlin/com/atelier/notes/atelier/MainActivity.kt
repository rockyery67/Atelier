package com.atelier.notes.atelier

import android.media.AudioManager
import android.app.NotificationManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "atelier/device").setMethodCallHandler { call, result ->
            if (call.method == "soundAllowed") {
                val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val notifications = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                result.success(audio.ringerMode == AudioManager.RINGER_MODE_NORMAL && notifications.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL)
            } else { result.notImplemented() }
        }
    }
}
