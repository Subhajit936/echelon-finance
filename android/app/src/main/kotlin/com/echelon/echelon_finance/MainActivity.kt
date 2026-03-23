package com.echelon.echelon_finance

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val SMS_EVENT_CHANNEL   = "echelon_finance/sms_events"
        const val PENDING_SMS_CHANNEL = "echelon_finance/pending_sms"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Live SMS EventChannel ──────────────────────────────────────────
        // Dart listens to this stream; SmsReceiver writes to SmsEventSink.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    SmsEventSink.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    SmsEventSink.eventSink = null
                }
            })

        // ── Pending SMS MethodChannel ──────────────────────────────────────
        // Called once on app launch to drain SMS received while app was closed.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PENDING_SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingAndClear" -> {
                        val prefs = getSharedPreferences(
                            "echelon_pending_sms", Context.MODE_PRIVATE
                        )
                        val pending = prefs.getString("list", "[]") ?: "[]"
                        prefs.edit().putString("list", "[]").apply()
                        result.success(pending)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
