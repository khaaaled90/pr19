package com.example.pr19

import android.content.Context
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.os.Build

object DualSimSmsSender {

    fun sendSms(context: Context, phoneNumber: String, message: String, preferredSubId: Int? = null): Boolean {
        return try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (preferredSubId != null && preferredSubId != -1) {
                    context.getSystemService(SmsManager::class.java).createForSubscriptionId(preferredSubId)
                } else {
                    context.getSystemService(SmsManager::class.java)
                }
            } else {
                @Suppress("DEPRECATION")
                if (preferredSubId != null && preferredSubId != -1) {
                    SmsManager.getSmsManagerForSubscriptionId(preferredSubId)
                } else {
                    SmsManager.getDefault()
                }
            }

            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
