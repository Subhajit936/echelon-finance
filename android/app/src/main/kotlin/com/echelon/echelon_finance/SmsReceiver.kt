package com.echelon.echelon_finance

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Fires whenever Android delivers a new SMS.
 * If the Flutter engine is alive → forwards directly via EventChannel.
 * If the app is closed → persists to SharedPreferences; MainActivity
 * drains it on next launch via the pending MethodChannel.
 */
class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            ?: return

        val body = StringBuilder()
        val sender = messages.firstOrNull()?.originatingAddress ?: return
        messages.forEach { body.append(it.messageBody) }

        val payload = mapOf(
            "body"      to body.toString(),
            "sender"    to sender,
            "timestamp" to System.currentTimeMillis()
        )

        val sink = SmsEventSink.eventSink
        if (sink != null) {
            // App is foregrounded/backgrounded — Flutter engine is running.
            Handler(Looper.getMainLooper()).post { sink.success(payload) }
        } else {
            // App is fully closed — persist for next launch.
            val prefs = context.getSharedPreferences("echelon_pending_sms", Context.MODE_PRIVATE)
            val arr = JSONArray(prefs.getString("list", "[]"))
            arr.put(JSONObject().apply {
                put("body",      body.toString())
                put("sender",    sender)
                put("timestamp", System.currentTimeMillis())
            })
            prefs.edit().putString("list", arr.toString()).apply()
        }
    }
}

/** Singleton EventSink shared between MainActivity and SmsReceiver. */
object SmsEventSink {
    @Volatile var eventSink: EventChannel.EventSink? = null
}
