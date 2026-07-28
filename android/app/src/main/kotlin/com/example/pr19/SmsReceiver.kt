package com.example.pr19

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("SMS_RECEIVER", "onReceive Called")
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            Log.d("SMS_RECEIVER", "SMS_RECEIVED_ACTION")
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                Log.d(
                    "SMS_RECEIVER",
                    "Sender=${sms.originatingAddress} Body=${sms.messageBody}"
                )
                val sender = sms.originatingAddress ?: continue
                val body = sms.messageBody ?: continue

                val inputData = Data.Builder()
                    .putString("sender", sender)
                    .putString("body", body)
                    .build()

                val workRequest = OneTimeWorkRequestBuilder<ProcessMessageWorker>()
                    .setInputData(inputData)
                    .build()

                WorkManager.getInstance(context).enqueue(workRequest)
            }
        }
    }
}
