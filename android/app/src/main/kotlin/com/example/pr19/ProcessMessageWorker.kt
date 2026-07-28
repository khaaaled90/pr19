package com.example.pr19

import android.util.Log
import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.ListenableWorker

class ProcessMessageWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): ListenableWorker.Result {
        val rawSender = inputData.getString("sender") ?: ""
        val originPackage = inputData.getString("origin_package") ?: rawSender
        val body = inputData.getString("body") ?: return ListenableWorker.Result.failure()
        
        val dbHelper = AppSqliteHelper.getInstance(applicationContext)

        // 1. التحقق من تفعيل الخدمة
        if (dbHelper.getSetting("service_enabled", "true") != "true") {
            return ListenableWorker.Result.success()
        }

        // 2. التحقق من قائمة المرسلين المسموحين (Whitelist)
        val allowAllSendersValue = dbHelper.getSetting("allow_all_senders", "false")
        val allowAllSenders = allowAllSendersValue == "true"
        
        if (!allowAllSenders && !dbHelper.isSenderAllowed(originPackage) && !dbHelper.isSenderAllowed(rawSender)) {
            Log.d("WORKER", "Message rejected because sender package is not allowed")
            return ListenableWorker.Result.success()
        }

        // 3. المطابقة مع الكلمات المفتاحية
        val matchedKwMap = dbHelper.matchKeyword(body)
        if (matchedKwMap == null) {
            Log.d("WORKER", "No keyword matched. Skipping archive save.")
            return ListenableWorker.Result.success()
        }

        val keywordId = matchedKwMap["id"] as Int
        val keywordText = matchedKwMap["keyword"] as String
        val targetCount = matchedKwMap["target_count"] as? Int ?: 0
        val rewardKeywordId = matchedKwMap["reward_keyword_id"] as? Int
        val rewardQty = matchedKwMap["reward_qty"] as? Int ?: 1

        // =========================================================
        // 🎯 4. تحديد رقم هاتف العميل المستهدف (بالترتيب المباشر)
        // =========================================================
        var targetCustomerPhone: String? = null

        if (rawSender.startsWith("+967") || rawSender.startsWith("7")) {
            // أ) إذا كان مرسل الرسالة هاتف عميل مباشر (SMS)
            targetCustomerPhone = extractPhoneFromBody(rawSender) ?: rawSender
        } else {
            // ب) إذا كان الإشعار قادم من تطبيق محفظة/بنك:
            // 1. نبحث أولاً عن رقم هاتف مذكور داخل نص الرسالة/الإشعار نفسه
            targetCustomerPhone = extractPhoneFromBody(body)
            
            // 2. إذا لم نجد رقم هاتف في نص الرسالة، نبحث عن الاسم أو المحفظة في جدول العملاء
            if (targetCustomerPhone == null) {
                targetCustomerPhone = dbHelper.findCustomerPhoneByIdentifier(body)
            }
        }

        // =========================================================
        // 🛑 حالة: تعذر العثور على رقم هاتف (تحويل للمعالجة اليدوية)
        // =========================================================
        if (targetCustomerPhone.isNull_Or_Empty_Or_Invalid()) {
            Log.w("WORKER", "No valid target customer phone found. Moving to manual approval pool.")
            
            // أرشفة الإشعار بحالة تحتاج موافقة يدوية بدون حجز قسيمة
            dbHelper.addToArchive(
                sender = rawSender,
                senderName = "معلق (بحاجة لربط)",
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = "",
                status = "manual_approval_required"
            )
            return ListenableWorker.Result.success()
        }

        // الرقم المؤكد والنهائي للعميل المستلم للقسيمة
        val destinationPhone: String = targetCustomerPhone!!

        // =========================================================
        // ✅ 5. آلية فحص الرصيد المالي لمنع التكرار لكل رقم عميل
        // =========================================================
        val extractedBalance = extractBalanceFromBody(body)
        if (!extractedBalance.isNullOrBlank()) {
            val isDuplicate = dbHelper.isDuplicateBalance(destinationPhone, extractedBalance)
            if (isDuplicate) {
                Log.w("WORKER", "Duplicate transaction detected for $destinationPhone with balance $extractedBalance. Skipping execution.")
                return ListenableWorker.Result.success()
            }
        }

        // =========================================================
        // 🎁 6. معالجة القسائم ونظام العروض والمكافآت
        // =========================================================
        var finalKeywordIdToUse = keywordId
        var isRewardGranted = false

        if (targetCount > 0 && rewardKeywordId != null) {
            val currentCount = dbHelper.incrementCustomerCounter(destinationPhone, keywordId)
            
            if (currentCount >= targetCount) {
                finalKeywordIdToUse = rewardKeywordId
                isRewardGranted = true
                dbHelper.resetCustomerCounter(destinationPhone, keywordId)
                Log.d("WORKER", "Reward triggered for $destinationPhone! Reward Keyword ID: $rewardKeywordId")
            }
        }

        // سحب القسيمة المطلوبة لحساب العميل
        val voucherCode = dbHelper.getAndUseVoucher(finalKeywordIdToUse, destinationPhone)

        if (voucherCode != null) {
            val defaultReply = dbHelper.getSetting("default_reply", "شكراً لتواصلك. رقمك الخاص هو: ")
            
            val messagePrefix = if (isRewardGranted) {
                "تهانينا! لقد حصلت على هدية العرض: "
            } else {
                defaultReply
            }

            val fullMessage = "$messagePrefix $voucherCode"
            
            // =========================================================
            // 🎯 7. إرسال الرسالة النصية إلى رقم العميل المستهدف حصراً
            // =========================================================
            val isSent = DualSimSmsSender.sendSms(
                context = applicationContext,
                phoneNumber = destinationPhone,
                message = fullMessage
            )

            if (isSent) {
                // أرشفة العملية
                dbHelper.addToArchive(
                    sender = destinationPhone,
                    senderName = null,
                    receivedMessage = body,
                    matchedKeyword = keywordText,
                    sentNumber = voucherCode,
                    status = if (isRewardGranted) "sent_reward" else "sent"
                )

                // =========================================================
                // 👤 8. حفظ وتحديث بيانات العميل بالكامل دون مسح البيانات القديمة
                // =========================================================
                val extractedName = extractNameFromBody(body)
                val extractedWallet = extractWalletFromBody(body)

                dbHelper.updateCustomerBalance(
                    phone = destinationPhone,
                    newBalance = extractedBalance ?: "",
                    name = extractedName,
                    walletNumber = extractedWallet
                )
                Log.d("WORKER", "Successfully updated customer data & balance for $destinationPhone")

                Log.d("WORKER", "Successfully processed and archived transaction.")
            } else {
                Log.e("WORKER", "Failed to send SMS to $destinationPhone. Transaction NOT archived.")
            }
        } else {
            Log.w("WORKER", "Out of stock for keyword ID $finalKeywordIdToUse. Transaction NOT archived.")
        }

        return ListenableWorker.Result.success()
    }

    /// دالة استخراج رقم الهاتف اليمني من نص الإشعار أو الرسالة
    private fun extractPhoneFromBody(body: String): String? {
        val phoneRegex = Regex("""(?:\+?967|0)?(7[01378]\d{8})""")
        val match = phoneRegex.find(body)
        return match?.groupValues?.get(1)
    }

    /// دالة استخراج الرصيد المالي المتبقي من نص الإشعار
    private fun extractBalanceFromBody(body: String): String? {
        val balanceRegex = Regex("""(?:رصيدك|الرصيد|رصيدكم|Balance|Bal)[\s:]*([\d,]+(?:\.\d+)?)""", RegexOption.IGNORE_CASE)
        val match = balanceRegex.find(body)
        return match?.groupValues?.get(1)?.replace(",", "")
    }

    /// دالة استخراج اسم المودع/العميل من نص الإشعار
    private fun extractNameFromBody(body: String): String? {
        val nameRegex = Regex("""(?:من|المودع|العميل|From)[\s:]+([^\d\n,]{3,30})""", RegexOption.IGNORE_CASE)
        val match = nameRegex.find(body)
        return match?.groupValues?.get(1)?.trim()
    }

    /// دالة استخراج رقم المحفظة/الحساب من نص الإشعار
    private fun extractWalletFromBody(body: String): String? {
        val walletRegex = Regex("""(?:محفظة|حساب|Acc|Wallet)[\s:]*(\d{6,15})""", RegexOption.IGNORE_CASE)
        val match = walletRegex.find(body)
        return match?.groupValues?.get(1)?.trim()
    }

    private fun String?.isNull_Or_Empty_Or_Invalid(): Boolean {
        if (this.isNullOrBlank()) return true
        return !this.contains(Regex("""\d{9}"""))
    }
}
/*package com.example.pr19

import android.util.Log
import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.ListenableWorker

class ProcessMessageWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): ListenableWorker.Result {
        val rawSender = inputData.getString("sender") ?: ""
        val originPackage = inputData.getString("origin_package") ?: rawSender
        val body = inputData.getString("body") ?: return ListenableWorker.Result.failure()
        
        val dbHelper = AppSqliteHelper.getInstance(applicationContext)

        // 1. التحقق من تفعيل الخدمة
        if (dbHelper.getSetting("service_enabled", "true") != "true") {
            return ListenableWorker.Result.success()
        }

        // 2. التحقق من قائمة المرسلين المسموحين (Whitelist)
        val allowAllSendersValue = dbHelper.getSetting("allow_all_senders", "false")
        val allowAllSenders = allowAllSendersValue == "true"
        
        if (!allowAllSenders && !dbHelper.isSenderAllowed(originPackage) && !dbHelper.isSenderAllowed(rawSender)) {
            Log.d("WORKER", "Message rejected because sender package is not allowed")
            return ListenableWorker.Result.success()
        }

        // 3. المطابقة مع الكلمات المفتاحية
        val matchedKwMap = dbHelper.matchKeyword(body)
        if (matchedKwMap == null) {
            Log.d("WORKER", "No keyword matched. Skipping archive save.")
            return ListenableWorker.Result.success()
        }

        val keywordId = matchedKwMap["id"] as Int
        val keywordText = matchedKwMap["keyword"] as String
        val targetCount = matchedKwMap["target_count"] as? Int ?: 0
        val rewardKeywordId = matchedKwMap["reward_keyword_id"] as? Int
        val rewardQty = matchedKwMap["reward_qty"] as? Int ?: 1

        // 4. استخراج رقم الهاتف مباشرة أو عبر الاسم/رقم المحفظة المخزنة
        val extractedPhone = if (rawSender.startsWith("+967") || rawSender.startsWith("7")) {
            rawSender
        } else {
            dbHelper.findCustomerPhoneByIdentifier(body)
        }

        // =========================================================
        // 🛑 حالة: الإشعار يخص عميل غير مسجل (معالجة يدوية)
        // =========================================================
        if (extractedPhone.isNull_Or_Empty_Or_Invalid()) {
            Log.w("WORKER", "No valid customer phone found. Moving to manual approval pool.")
            
            // إضافة الإشعار للأرشيف بحالة تحتاج موافقة يدوية لربطه برقم الهاتف لاحقاً
            dbHelper.addToArchive(
                sender = rawSender,
                senderName = "معلق (بحاجة لربط)",
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = "",
                status = "manual_approval_required"
            )
            return ListenableWorker.Result.success()
        }

        val safePhone: String = extractedPhone!!

        // =========================================================
        // ✅ 5. آلية فحص الرصيد المالي لمنع التكرار لكل رقم
        // =========================================================
        val extractedBalance = extractBalanceFromBody(body)
        if (extractedBalance != null) {
            val isDuplicate = dbHelper.isDuplicateBalance(safePhone, extractedBalance)
            if (isDuplicate) {
                Log.w("WORKER", "Duplicate transaction detected for $safePhone with balance $extractedBalance. Skipping execution.")
                return ListenableWorker.Result.success()
            }
        }

        // =========================================================
        // 🎁 6. معالجة القسائم ونظام العروض والمكافآت
        // =========================================================
        var finalKeywordIdToUse = keywordId
        var isRewardGranted = false

        // إذا كان للكلمة نظام مكافآت (هدف عداد)
        if (targetCount > 0 && rewardKeywordId != null) {
            val currentCount = dbHelper.incrementCustomerCounter(safePhone, keywordId)
            
            if (currentCount >= targetCount) {
                // العميل وصل للهدف -> يتم تغيير القسيمة المسحوبة إلى قسيمة المكافأة
                finalKeywordIdToUse = rewardKeywordId
                isRewardGranted = true
                dbHelper.resetCustomerCounter(safePhone, keywordId)
                Log.d("WORKER", "Reward triggered for $safePhone! Reward Keyword ID: $rewardKeywordId")
            }
        }

        // سحب القسيمة المطلوبة (سواء كانت العادية أو المكافأة)
        val voucherCode = dbHelper.getAndUseVoucher(finalKeywordIdToUse, safePhone)

        if (voucherCode != null) {
            val defaultReply = dbHelper.getSetting("default_reply", "شكراً لتواصلك. رقمك الخاص هو: ")
            
            val messagePrefix = if (isRewardGranted) {
                "تهانينا! لقد حصلت على هدية العرض: "
            } else {
                defaultReply
            }

            val fullMessage = "$messagePrefix $voucherCode"
            
            // 7. إرسال الرسالة النصية
            val isSent = DualSimSmsSender.sendSms(
                context = applicationContext,
                phoneNumber = safePhone,
                message = fullMessage
            )

            if (isSent) {
                // أرشفة العملية
                dbHelper.addToArchive(
                    sender = safePhone,
                    senderName = null,
                    receivedMessage = body,
                    matchedKeyword = keywordText,
                    sentNumber = voucherCode,
                    status = if (isRewardGranted) "sent_reward" else "sent"
                )

                // تحديث رصيد العميل بعد الإرسال الناجح فقط
                if (extractedBalance != null) {
                    dbHelper.updateCustomerBalance(
                        phone = safePhone,
                        newBalance = extractedBalance
                    )
                    Log.d("WORKER", "Successfully updated last balance for $safePhone to $extractedBalance")
                }

                Log.d("WORKER", "Successfully processed and archived transaction.")
            } else {
                Log.e("WORKER", "Failed to send SMS. Transaction NOT archived.")
            }
        } else {
            Log.w("WORKER", "Out of stock for keyword ID $finalKeywordIdToUse. Transaction NOT archived.")
        }

        return ListenableWorker.Result.success()
    }

    /// دالة استخراج الرصيد المالي المتبقي من نص الإشعار
    private fun extractBalanceFromBody(body: String): String? {
        val balanceRegex = Regex("""(?:رصيدك|الرصيد|رصيدكم|Balance|Bal)[\s:]*([\d,]+(?:\.\d+)?)""", RegexOption.IGNORE_CASE)
        val match = balanceRegex.find(body)
        return match?.groupValues?.get(1)?.replace(",", "")
    }

    private fun String?.isNull_Or_Empty_Or_Invalid(): Boolean {
        if (this.isNullOrBlank()) return true
        return !this.contains(Regex("""\d{9}"""))
    }
}*/


/*package com.example.pr19

import android.util.Log
import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.ListenableWorker

class ProcessMessageWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): ListenableWorker.Result {
        // 1. استقبال البيانات
        val rawSender = inputData.getString("sender") ?: ""
        val originPackage = inputData.getString("origin_package") ?: rawSender
        val body = inputData.getString("body") ?: return ListenableWorker.Result.failure()
        
        val dbHelper = AppSqliteHelper.getInstance(applicationContext)

        // 2. التحقق من مفتاح الخدمة
        if (dbHelper.getSetting("service_enabled", "true") != "true") {
            return ListenableWorker.Result.success()
        }

        // 3. التحقق من السماح للـ Package المصدر أو مرسل الـ SMS
        val allowAllSendersValue = dbHelper.getSetting("allow_all_senders", "false")
        val allowAllSenders = allowAllSendersValue == "true"
        
        Log.d("WORKER", "allowAllSenders = $allowAllSenders")
        Log.d("WORKER", "originPackage = $originPackage")
        
        if (!allowAllSenders && !dbHelper.isSenderAllowed(originPackage) && !dbHelper.isSenderAllowed(rawSender)) {
            Log.d("WORKER", "Message rejected because sender package is not allowed")
            return ListenableWorker.Result.success()
        }

        // 4. مطابقة الكلمة المفتاحية / الفئة
        val matchedKwMap = dbHelper.matchKeyword(body)
        Log.d("WORKER", "body = $body")
        Log.d("WORKER", "matchedKwMap = $matchedKwMap")
        
        if (matchedKwMap == null) {
            Log.d("WORKER", "No keyword matched. Skipping archive save.")
            return ListenableWorker.Result.success()
        }

        val keywordId = matchedKwMap["id"] as Int
        val keywordText = matchedKwMap["keyword"] as String

        // 5. تحديد رقم العميل المستهدف بوضوح
        val extractedPhone = if (rawSender.startsWith("+967") || rawSender.startsWith("7")) {
            rawSender
        } else {
            dbHelper.findCustomerPhoneByIdentifier(body)
        }

        Log.d("WORKER", "Final targetCustomerPhone = $extractedPhone")

        // ✅ إذا كان الرقم فارغاً أو غير صالح، يتوقف العمل مباشرة
        if (extractedPhone.isNull_Or_Empty_Or_Invalid()) {
            Log.w("WORKER", "No valid customer phone found. Skipping archive save.")
            return ListenableWorker.Result.success()
        }

        // ✅ تحويل المتغير إلى Non-Nullable String بشكل صريح بعد التحقق أعلاه
        val safePhone: String = extractedPhone!!

        // 6. سحب القسيمة والإرسال
        val voucherCode = dbHelper.getAndUseVoucher(keywordId, safePhone)
        Log.d("WORKER", "voucherCode = $voucherCode")

        if (voucherCode != null) {
            val defaultReply = dbHelper.getSetting("default_reply", "شكراً لتواصلك. رقمك الخاص هو: ")
            val fullMessage = "$defaultReply $voucherCode"
            
            Log.d("WORKER", "Sending SMS to $safePhone")
            
            val isSent = DualSimSmsSender.sendSms(
                context = applicationContext,
                phoneNumber = safePhone,
                message = fullMessage
            )

            Log.d("WORKER", "sendSms returned = $isSent")

            // ✅ الحفظ في الأرشيف يتم فقط عند نجاح إرسال الـ SMS للعميل
            if (isSent) {
                dbHelper.addToArchive(
                    sender = safePhone,
                    senderName = null,
                    receivedMessage = body,
                    matchedKeyword = keywordText,
                    sentNumber = voucherCode,
                    status = "sent"
                )
                Log.d("WORKER", "Successfully archived sent transaction.")
            } else {
                Log.e("WORKER", "Failed to send SMS. Transaction NOT archived.")
            }
        } else {
            Log.w("WORKER", "Out of stock. Transaction NOT archived.")
        }

        return ListenableWorker.Result.success()
    }

    // دالة مساعدة للتأكد من صحة رقم الهاتف
    private fun String?.isNull_Or_Empty_Or_Invalid(): Boolean {
        if (this.isNullOrBlank()) return true
        return !this.contains(Regex("""\d{9}"""))
    }
}*/





/*package com.example.pr19
import android.util.Log
import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.ListenableWorker

class ProcessMessageWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): ListenableWorker.Result {
        val sender = inputData.getString("sender") ?: return ListenableWorker.Result.failure()
        val body = inputData.getString("body") ?: return ListenableWorker.Result.failure()
        val dbHelper = AppSqliteHelper.getInstance(applicationContext)

        if (dbHelper.getSetting("service_enabled", "true") != "true") {
            return ListenableWorker.Result.success()
        }

        // ===== تم تعطيل فلترة المرسل مؤقتاً =====
        val allowAllSendersValue = dbHelper.getSetting("allow_all_senders", "false")
        val allowAllSenders = allowAllSendersValue == "true"
        
        Log.d("WORKER", "allow_all_senders(DB) = $allowAllSendersValue")
        Log.d("WORKER", "allowAllSenders = $allowAllSenders")
        Log.d("WORKER", "sender = $sender")
        Log.d("WORKER", "isSenderAllowed = ${dbHelper.isSenderAllowed(sender)}")
        
        if (!allowAllSenders && !dbHelper.isSenderAllowed(sender)) {
            Log.d("WORKER", "Message rejected because sender is not allowed")
            return ListenableWorker.Result.success()
        }
        /*val allowAllSenders = dbHelper.getSetting("allow_all_senders", "false") == "true"
        Log.d("WORKER", "allow_all_senders (DB) = $allowAllSendersValue")
        if (!allowAllSenders && !dbHelper.isSenderAllowed(sender)) {
            return ListenableWorker.Result.success()
        }*/

        // تعطيل مطابقة الكلمات المفتاحية مؤقتاً
        /*val matchedKwMap = mapOf<String, Any>(
            "id" to 1,
            "keyword" to "ALL"
        )*/
        // ===== تم تعطيل فلترة المرسل مؤقتاً =====
        val matchedKwMap = dbHelper.matchKeyword(body)
        Log.d("WORKER", "body = $body")
        Log.d("WORKER", "matchedKwMap = $matchedKwMap")
        if (matchedKwMap == null) {
            dbHelper.addToArchive(sender, null, body, null, null, "no_keyword_matched")
            return ListenableWorker.Result.success()
        }

        val keywordId = matchedKwMap["id"] as Int
        val keywordText = matchedKwMap["keyword"] as String
        val targetCustomerPhone = dbHelper.findCustomerPhoneByIdentifier(body) ?: sender
        Log.d("WORKER", "targetCustomerPhone = $targetCustomerPhone")
        
        val voucherCode = dbHelper.getAndUseVoucher(keywordId, targetCustomerPhone)
        Log.d("WORKER", "voucherCode = $voucherCode")

        if (voucherCode != null) {
            val defaultReply = dbHelper.getSetting("default_reply", "شكراً لتواصلك. رقمك الخاص هو: ")
            val fullMessage = "$defaultReply $voucherCode"
            
            Log.d("WORKER", "Sending SMS to $targetCustomerPhone")
            val isSent = DualSimSmsSender.sendSms(
                context = applicationContext,
                phoneNumber = targetCustomerPhone,
                message = fullMessage
            )

            Log.d("WORKER", "sendSms returned = $isSent")

            val status = if (isSent) "sent" else "failed_sending"

            dbHelper.addToArchive(
                sender = targetCustomerPhone,
                senderName = null,
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = voucherCode,
                status = status
            )
        } else {
            dbHelper.addToArchive(
                sender = targetCustomerPhone,
                senderName = null,
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = null,
                status = "out_of_stock"
            )
        }

        return ListenableWorker.Result.success()
    }
}*/
