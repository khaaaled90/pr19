package com.example.pr19

import android.content.Context
import android.util.Log
import java.util.concurrent.Executors

object ProcessMessageProcessor {

    private val backgroundExecutor = Executors.newSingleThreadExecutor()

    fun processMessageAsync(context: Context, rawSender: String, originPackage: String, body: String, customerPhoneInput: String) {
        // ⭐ تشغيل المعالجة بالكامل فوراً داخل خيط خلفي مستقل لحماية الـ Main Thread ومنع ANR
        backgroundExecutor.execute {
            try {
                executeProcessing(context, rawSender, originPackage, body, customerPhoneInput)
            } catch (e: Exception) {
                Log.e("PROCESSOR", "Unhandled exception in message processing: ${e.message}", e)
            }
        }
    }

    private fun executeProcessing(context: Context, rawSender: String, originPackage: String, body: String, customerPhoneInput: String) {
        val dbHelper = AppSqliteHelper.getInstance(context)

        // 1. فحص تفعيل الخدمة من الكاش
        if (!AppCache.isServiceEnabled(dbHelper)) return

        // 2. فحص المرسل المسموح به من الكاش
        val allowAllSenders = AppCache.isAllowAllSenders(dbHelper)
        if (!allowAllSenders && !dbHelper.isSenderAllowed(originPackage) && !dbHelper.isSenderAllowed(rawSender)) {
            Log.d("PROCESSOR", "Sender rejected: $rawSender / $originPackage")
            return
        }

        // 3. مطابقة الكلمة المفتاحية عبر الكاش
        val keywords = AppCache.getKeywords(dbHelper)
        var matchedKwMap: Map<String, Any>? = null
        for (kw in keywords) {
            val kwText = kw["keyword"] as? String ?: continue
            if (body.contains(kwText, ignoreCase = true)) {
                matchedKwMap = kw
                break
            }
        }

        if (matchedKwMap == null) return

        // ⭐ 4. التحويل الآمن للأرقام لمنع ClassCastException (Number casting)
        val keywordId = (matchedKwMap["id"] as? Number)?.toInt() ?: return
        val keywordText = matchedKwMap["keyword"] as? String ?: ""
        val targetCount = (matchedKwMap["target_count"] as? Number)?.toInt() ?: 0
        val rewardKeywordId = (matchedKwMap["reward_keyword_id"] as? Number)?.toInt()

        
        // ⭐ 5. البحث عن رقم هاتف العميل من الكاش الموحد فوراً إذا لم يأتِ مع الإشعار
        // ⭐ استخراج الاسم ورقم المحفظة من النص
        
        //val extractedName = extractNameFromBody(body)
        val extractedWallet = extractWalletFromBody(body)
        val rawName = extractNameFromBody(body)
        val extractedName = if (rawName.isNullOrBlank()) extractedWallet ?: "" else rawName    

        var targetCustomerPhone = customerPhoneInput

        // ⭐ البحث في الكاش باستخدام المحفظة أولاً أو الاسم المسحوب ثانياً
        if (targetCustomerPhone.isBlank()) {
            Log.d("PROCESSOR", "Searching by wallet/name...")
            if (!extractedWallet.isNullOrBlank()) {
                Log.d("PROCESSOR", "Searching wallet = $extractedWallet")
                Log.d("PROCESSOR", "Searching name = $extractedName")
                targetCustomerPhone = AppCache.findPhoneByIdentifier(dbHelper, extractedWallet) ?: ""
            }
            if (targetCustomerPhone.isBlank() && !extractedName.isNullOrBlank()) {
                Log.d("PROCESSOR", "Searching wallet = $extractedWallet")
                Log.d("PROCESSOR", "Searching name = $extractedName")
                targetCustomerPhone = AppCache.findPhoneByIdentifier(dbHelper, extractedName) ?: ""
            }
        }
        /*var targetCustomerPhone = customerPhoneInput
        if (targetCustomerPhone.isBlank()) {
            targetCustomerPhone = AppCache.findPhoneByIdentifier(dbHelper, body) ?: ""
        }*/

        // ⭐ 6. فحص العميل المعلق (إذا لم يتعرف النظام على هاتف أو اسم)
        if (targetCustomerPhone.isNull_Or_Empty_Or_Invalid()) {
            //val displayName = extractNameFromBody(body) ?: "معلق (بحاجة لربط)"
            val displayName = extractedName ?: "معلق (بحاجة لربط)"
            dbHelper.addToArchive(
                sender = rawSender,
                senderName = displayName,
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = "",
                status = "manual_approval_required"
            )
            return
        }

        Log.e("PROCESSOR1", "===> بدء مرحلة التحقق من الرصيد <===")
        val destinationPhone = targetCustomerPhone
        Log.e("PROCESSOR1", "رقم العميل المستهدف (destinationPhone): '$destinationPhone'")
        
        Log.e("PROCESSOR1", "جاري استخراج الرصيد من نص الرسالة...")
        val extractedBalance = extractBalanceFromBody(body)
        Log.e("PROCESSOR1", "الرصيد المستخرج (extractedBalance): '$extractedBalance'")

        if (!extractedBalance.isNullOrBlank()) {
            Log.e("PROCESSOR1", "الرصيد غير فارغ، جاري فحص التكرار عبر isDuplicateBalance...")

            if (dbHelper.isDuplicateBalance(destinationPhone, extractedBalance)) {
                Log.e("PROCESSOR1", "Duplicate balance detected for $destinationPhone. Skipping.")                
                return
            } else {
                Log.e("PROCESSOR1", "✅ الرصيد جديد وغير مكرر للعميل: $destinationPhone.")
            }

        } else {
            Log.e("PROCESSOR1", "⚠️ لم يتم استخراج أي رصيد من الرسالة (extractedBalance is null or blank)، سيتم تجاوز فحص التكرار.")
        }

        var finalKeywordIdToUse = keywordId
        var isRewardGranted = false

        if (targetCount > 0 && rewardKeywordId != null) {
            val currentCount = dbHelper.incrementCustomerCounter(destinationPhone, keywordId)
            if (currentCount >= targetCount) {
                finalKeywordIdToUse = rewardKeywordId
                isRewardGranted = true
                dbHelper.resetCustomerCounter(destinationPhone, keywordId)
            }
        }

        // ⭐ 7. سحب الكرت وإرسال الـ SMS المباشر
        val voucherCode = dbHelper.getAndUseVoucher(finalKeywordIdToUse, destinationPhone)

        if (voucherCode != null) {
            val defaultReply = AppCache.getDefaultReply(dbHelper)
            val messagePrefix = if (isRewardGranted) "تهانينا! لقد حصلت على هدية العرض: " else defaultReply
            val fullMessage = "$messagePrefix $voucherCode"

            Log.e("UPDATE_CUSTOMER", "voucherCode=$voucherCode")
            val isSent = DualSimSmsSender.sendSms(
                context = context,
                phoneNumber = destinationPhone,
                message = fullMessage
            )
            Log.e("UPDATE_CUSTOMER", "isSent=$isSent")

            // ⭐ 8. الأرشفة وتحديث البيانات
            if (isSent) {
                dbHelper.addToArchive(
                    sender = destinationPhone,
                    senderName = null,
                    receivedMessage = body,
                    matchedKeyword = keywordText,
                    sentNumber = voucherCode,
                    status = if (isRewardGranted) "sent_reward" else "sent"
                )

                //val extractedName = extractNameFromBody(body)
                val extractedWallet = extractWalletFromBody(body)
                val rawName = extractNameFromBody(body)
                val extractedName = if (rawName.isNullOrBlank()) extractedWallet ?: "" else rawName    
    

                Log.e("UPDATE_CUSTOMER", "isSent=$isSent")
                dbHelper.updateCustomerBalance(
                    phone = destinationPhone,
                    newBalance = extractedBalance ?: "",
                    name = extractedName,
                    walletNumber = extractedWallet
                )
                Log.e("UPDATE_CUSTOMER", "Calling updateCustomerBalance()")
            }
        }
    }

    private fun extractNameFromBody(body: String): String? {
        val nameRegex = Regex("""(?:من|المودع|العميل|المحول|حساب|من الحساب|From)[\s:]+([^\d\n,.:]{3,30})""", RegexOption.IGNORE_CASE)
        val match = nameRegex.find(body)
        var extracted = match?.groupValues?.get(1)?.trim() ?: return null
        val ignoredWords = listOf("نجاح", "عملية", "إيداع", "تحويل", "رصيد", "مبلغ", "إلى", "حساب")
        for (word in ignoredWords) {
            if (extracted.contains(word)) {
                extracted = extracted.substringBefore(word).trim()
            }
        }
        return if (extracted.length >= 3) extracted else null
    }

    private fun extractBalanceFromBody(body: String): String? {
        //val balanceRegex = Regex("""(?:رصيدك|الرصيد|رصيدكم|Balance|Bal)[\s:]*([\d,]+(?:\.\d+)?)""", RegexOption.IGNORE_CASE)
        val balanceRegex = Regex("""(?:رصيدك|الرصيد|رصيدكم|رصيد|متبقي|المتبقي|ر\.?ص|Balance|Bal)[\s:]*([\d,]+(?:\.\d+)?)""", RegexOption.IGNORE_CASE)
        return balanceRegex.find(body)?.groupValues?.get(1)?.replace(",", "")
    }

    private fun extractWalletFromBody(body: String): String? {
        //val walletRegex = Regex("""(?:محفظة|حساب|Acc|Wallet)[\s:]*(\d{6,15})""", RegexOption.IGNORE_CASE)
        val walletRegex = Regex("""(?:محفظة|حساب|Acc|Wallet|من|From)[\s:]*(\d{5,15})""", RegexOption.IGNORE_CASE)
        return walletRegex.find(body)?.groupValues?.get(1)?.trim()
    }

    private fun String?.isNull_Or_Empty_Or_Invalid(): Boolean {
        if (this.isNullOrBlank()) return true
        val digitsOnly = this.replace(Regex("""[^\d]"""), "")
        return digitsOnly.length < 8
    }
}
/*package com.example.pr19

import android.content.Context
import android.util.Log
import java.util.concurrent.Executors

object ProcessMessageProcessor {

    private val backgroundExecutor = Executors.newSingleThreadExecutor()

    fun processMessageAsync(context: Context, rawSender: String, originPackage: String, body: String, customerPhoneInput: String) {
        // ⭐ تشغيل المعالجة بالكامل فوراً داخل خيط خلفي مستقل لحماية الـ Main Thread ومنع ANR
        backgroundExecutor.execute {
            try {
                executeProcessing(context, rawSender, originPackage, body, customerPhoneInput)
            } catch (e: Exception) {
                Log.e("PROCESSOR", "Unhandled exception in message processing: ${e.message}", e)
            }
        }
    }

    private fun executeProcessing(context: Context, rawSender: String, originPackage: String, body: String, customerPhoneInput: String) {
        val dbHelper = AppSqliteHelper.getInstance(context)

        if (!AppCache.isServiceEnabled(dbHelper)) return

        val allowAllSenders = AppCache.isAllowAllSenders(dbHelper)
        if (!allowAllSenders && !dbHelper.isSenderAllowed(originPackage) && !dbHelper.isSenderAllowed(rawSender)) {
            Log.d("PROCESSOR", "Sender rejected: $rawSender / $originPackage")
            
            return
        }

        val keywords = AppCache.getKeywords(dbHelper)
        var matchedKwMap: Map<String, Any>? = null
        for (kw in keywords) {
            val kwText = kw["keyword"] as? String ?: continue
            if (body.contains(kwText, ignoreCase = true)) {
                matchedKwMap = kw
                break
            }
        }

        if (matchedKwMap == null) return

        // ⭐ 1. التحويل الآمن للأرقام لمنع ClassCastException (Number casting)
        val keywordId = (matchedKwMap["id"] as? Number)?.toInt() ?: return
        val keywordText = matchedKwMap["keyword"] as? String ?: ""
        val targetCount = (matchedKwMap["target_count"] as? Number)?.toInt() ?: 0
        val rewardKeywordId = (matchedKwMap["reward_keyword_id"] as? Number)?.toInt()

        var targetCustomerPhone = customerPhoneInput
        Log.d(
            "PROCESSOR",
            "customerPhoneInput='$customerPhoneInput' extractedName='$extractedName' extractedWallet='$extractedWallet'"
        )
        if (targetCustomerPhone.isBlank()) {
            targetCustomerPhone = dbHelper.findCustomerPhoneByIdentifier(body) ?: ""
        }

        // ⭐ 4. التحقق المعدل لمنع تحويل الأرقام الصحيحة للمعلقات بالخطأ
        if (targetCustomerPhone.isNull_Or_Empty_Or_Invalid()) {
            val displayName = extractNameFromBody(body) ?: "معلق (بحاجة لربط)"
            dbHelper.addToArchive(
                sender = rawSender,
                senderName = displayName,
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = "",
                status = "manual_approval_required"
            )
            return
        }

        val destinationPhone = targetCustomerPhone
        val extractedBalance = extractBalanceFromBody(body)
        if (!extractedBalance.isNullOrBlank()) {
            if (dbHelper.isDuplicateBalance(destinationPhone, extractedBalance)) {
                Log.w("PROCESSOR", "Duplicate balance detected for $destinationPhone. Skipping.")
                return
            }
        }

        var finalKeywordIdToUse = keywordId
        var isRewardGranted = false

        if (targetCount > 0 && rewardKeywordId != null) {
            val currentCount = dbHelper.incrementCustomerCounter(destinationPhone, keywordId)
            if (currentCount >= targetCount) {
                finalKeywordIdToUse = rewardKeywordId
                isRewardGranted = true
                dbHelper.resetCustomerCounter(destinationPhone, keywordId)
            }
        }

        // ⭐ إرسال الـ SMS المباشر فوراً
        val voucherCode = dbHelper.getAndUseVoucher(finalKeywordIdToUse, destinationPhone)

        if (voucherCode != null) {
            val defaultReply = AppCache.getDefaultReply(dbHelper)
            val messagePrefix = if (isRewardGranted) "تهانينا! لقد حصلت على هدية العرض: " else defaultReply
            val fullMessage = "$messagePrefix $voucherCode"

            val isSent = DualSimSmsSender.sendSms(
                context = context,
                phoneNumber = destinationPhone,
                message = fullMessage
            )

            // ⭐ الأرشفة وتحديث البيانات
            if (isSent) {
                dbHelper.addToArchive(
                    sender = destinationPhone,
                    senderName = null,
                    receivedMessage = body,
                    matchedKeyword = keywordText,
                    sentNumber = voucherCode,
                    status = if (isRewardGranted) "sent_reward" else "sent"
                )

                val extractedName = extractNameFromBody(body)
                val extractedWallet = extractWalletFromBody(body)

                dbHelper.updateCustomerBalance(
                    phone = destinationPhone,
                    newBalance = extractedBalance ?: "",
                    name = extractedName,
                    walletNumber = extractedWallet
                )
            }
        }
    
            Log.d("PROCESSOR", "customerPhoneInput='$customerPhoneInput'")
            Log.d("PROCESSOR", "targetCustomerPhone='$targetCustomerPhone'")
            Log.d("PROCESSOR", "extractedName='$extractedName'")
            Log.d("PROCESSOR", "extractedWallet='$extractedWallet'")
    }

    private fun extractNameFromBody(body: String): String? {
        val nameRegex = Regex("""(?:من|المودع|العميل|المحول|حساب|من الحساب|From)[\s:]+([^\d\n,.:]{3,30})""", RegexOption.IGNORE_CASE)
        val match = nameRegex.find(body)
        var extracted = match?.groupValues?.get(1)?.trim() ?: return null
        val ignoredWords = listOf("نجاح", "عملية", "إيداع", "تحويل", "رصيد", "مبلغ", "إلى", "حساب")
        for (word in ignoredWords) {
            if (extracted.contains(word)) {
                extracted = extracted.substringBefore(word).trim()
            }
        }
        return if (extracted.length >= 3) extracted else null
    }

    private fun extractBalanceFromBody(body: String): String? {
        val balanceRegex = Regex("""(?:رصيدك|الرصيد|رصيدكم|Balance|Bal)[\s:]*([\d,]+(?:\.\d+)?)""", RegexOption.IGNORE_CASE)
        return balanceRegex.find(body)?.groupValues?.get(1)?.replace(",", "")
    }

    private fun extractWalletFromBody(body: String): String? {
        val walletRegex = Regex("""(?:محفظة|حساب|Acc|Wallet)[\s:]*(\d{6,15})""", RegexOption.IGNORE_CASE)
        return walletRegex.find(body)?.groupValues?.get(1)?.trim()
    }

    // ⭐ إصلاح الخلل رقم 4: فحص يستوعب الأرقام الدولية اليمنيّة والمحلية والحسابات
    private fun String?.isNull_Or_Empty_Or_Invalid(): Boolean {
        if (this.isNullOrBlank()) return true
        val digitsOnly = this.replace(Regex("""[^\d]"""), "")
        return digitsOnly.length < 8
    }
}*/