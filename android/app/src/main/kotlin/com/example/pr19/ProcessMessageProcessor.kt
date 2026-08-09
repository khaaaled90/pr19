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

    // يمكنك وضعها داخل كلاس ProcessMessageProcessor أو كلاس أداة مستقل
    fun checkAndSendManagerAlert(context: Context, dbHelper: AppSqliteHelper, keywordId: Int, keywordText: String) {
        Log.e("STOCK_ALERT", "================== START ==================")
        try {

            // 1. قراءة الإعدادات من قاعدة البيانات/الكاش
            val isAlertEnabled = dbHelper.getSetting("stock_alert_enabled", "true") == "true"
            Log.e("STOCK_ALERT", "================== START ==================")
            if (!isAlertEnabled){
                Log.e("STOCK_ALERT", "الخدمة معطلة -> RETURN")
                return
            }    

            val ownerPhone = dbHelper.getSetting("owner_phone", "").trim()
            Log.e("STOCK_ALERT", "ownerPhone = '$ownerPhone'")
            if (ownerPhone.isBlank()){
                Log.e("STOCK_ALERT", "رقم المدير فارغ -> RETURN")   
                return
            }
            val thresholdStr = dbHelper.getSetting("warning_threshold", "5")
            Log.e("STOCK_ALERT", "warning_threshold(raw) = $thresholdStr")
            
            val warningThreshold = thresholdStr.toIntOrNull() ?: 5
            Log.e("STOCK_ALERT", "warningThreshold = $warningThreshold")
            Log.e("STOCK_ALERT", "Step 2 -> حساب الكروت المتبقية")

            // 2. حساب المتبقي من الكروت المتاحة لهذه الباقة
            val availableCount = dbHelper.getAvailableNumbersCountByKeywordId(keywordId)
            Log.e(
                "STOCK_ALERT",
                "keywordId=$keywordId availableCount=$availableCount threshold=$warningThreshold"
            )
            // 3. إذا وصل المتبقي للحد الأدنى أو نفذ تماماً
            if (availableCount <= warningThreshold) {
                Log.e(
                    "STOCK_ALERT",
                    "الشرط تحقق ($availableCount <= $warningThreshold)"
                )
                val alertMessage = if (availableCount == 0) {
                    "🚨 تنبيه نفاذ المخزون!\nنفذت أرقام الباقة ($keywordText) بالكامل!"
                } else {
                    "⚠️ تنبيه اقتراب نفاذ المخزون!\nالباقة ($keywordText) المتبقي منها: $availableCount فقط (الحد الأدنى: $warningThreshold)."
                }
                Log.e("STOCK_ALERT", "alertMessage = $alertMessage")
                Log.e("STOCK_ALERT", "Step 4 -> إرسال الرسالة")

                // إرسال SMS لرقم المدير
                DualSimSmsSender.sendSms(
                    context = context,
                    phoneNumber = ownerPhone,
                    message = alertMessage
                )
                Log.d("STOCK_ALERT", "✅ تم إرسال تنبيه المخزون للمدير: $ownerPhone")
            }
        } catch (e: Exception) {
            Log.e("STOCK_ALERT", "خطأ أثناء فحص تنبيه المخزون: ${e.message}")
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
        // 🎯 جلب سعر الفئة المضافة حديثاً
        val keywordPrice = (matchedKwMap["price"] as? Number)?.toDouble() ?: 0.0

        // ⭐ 5. استخراج الاسم ورقم المحفظة من النص والبحث عن رقم هاتف العميل
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

        // 👈 🎯 هنا موقع الإضافة بالضبط (بعد اكتمال البحث عن الرقم)
        if (targetCustomerPhone.isNotBlank() && dbHelper.isSenderIgnored(targetCustomerPhone)) {
            Log.i("PROCESSOR", "تم إهمال الرسالة: العميل $targetCustomerPhone موجود في قائمة الاستثناءات.")
            return
        }

        // ⭐ 6. فحص العميل المعلق (إذا لم يتعرف النظام على هاتف أو اسم)
        if (targetCustomerPhone.isNull_Or_Empty_Or_Invalid()) {
            val displayName = extractedName ?: "معلق (بحاجة لربط)"
            dbHelper.addToArchive(
                sender = rawSender,
                senderName = displayName,
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = "",
                status = "manual_approval_required",
                price = keywordPrice // 🎯 تمرير السعر
            )
            NotificationHelper.showManualApprovalNotification(
                context = context,
                receivedMessage = displayName
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
            Log.e("PROCESSOR1", "⚠️ لم يتم استخراج أي رصيد من الرسالة، سيتم تجاوز فحص التكرار.")
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

        // ⭐ 7. سحب القسيمة الأساسية وإرسالها دائماً (الرسالة الأولى)
        val mainVoucherCode = dbHelper.getAndUseVoucher(keywordId, destinationPhone)
        Log.e("PROCESSOR1", "voucher_approval_required=$mainVoucherCode")
            
        if (mainVoucherCode != null) {
            val defaultReply = AppCache.getDefaultReply(dbHelper)
            val fullMessage = "$defaultReply $mainVoucherCode"

            Log.e("UPDATE_CUSTOMER", "mainVoucherCode=$mainVoucherCode")
            val isSent = DualSimSmsSender.sendSms(
                context = context,
                phoneNumber = destinationPhone,
                message = fullMessage
            )
            Log.e("UPDATE_CUSTOMER", "isSent=$isSent")

            // إنشاء كائن التخزين
            val secureStorage = NativeSecureStorage(context)


            if (isSent) {
                // زيادة العداد بمقدار 1 ووضع علم المزامنة تلقائياً
                secureStorage.incrementVouchersUsed()
                // 2. إطلاق أوان المزامنة مع شرط وجود شبكة إتصال
                val constraints = androidx.work.Constraints.Builder()
                    .setRequiredNetworkType(androidx.work.NetworkType.CONNECTED)
                    .build()

                val syncWorkRequest = androidx.work.OneTimeWorkRequestBuilder<SyncWorker>()
                    .setConstraints(constraints)
                    .build()

                androidx.work.WorkManager.getInstance(context).enqueueUniqueWork(
                    "firebase_vouchers_sync",
                    androidx.work.ExistingWorkPolicy.REPLACE,
                    syncWorkRequest
                )
                // أرشفة القسيمة الأساسية مع السعر
                dbHelper.addToArchive(
                    sender = destinationPhone,
                    senderName = null,
                    receivedMessage = body,
                    matchedKeyword = keywordText,
                    sentNumber = mainVoucherCode,
                    status = "sent",
                    price = keywordPrice // 🎯 تمرير السعر
                )

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
                // 🟢 إظهار الإشعار من الكلاس المستقل
                NotificationHelper.showVoucherSentNotification(context, keywordText, destinationPhone)
            
                Log.e("UPDATE_CUSTOMER", "Calling updateCustomerBalance()")
                
                checkAndSendManagerAlert(context, dbHelper, keywordId, keywordText)

                // 🎯 ⭐ 8. فحص شرط العرض بعد إرسال القسيمة الأساسية (إرسال الرسالة الثانية)
                if (targetCount > 0 && rewardKeywordId != null) {
                    val currentCount = dbHelper.incrementCustomerCounter(destinationPhone, keywordId)
                    
                    if (currentCount >= targetCount) {
                        val rewardVoucherCode = dbHelper.getAndUseVoucher(rewardKeywordId, destinationPhone)

                        if (rewardVoucherCode != null) {
                            // تصفير العداد عند نجاح سحب كرت العرض
                            dbHelper.resetCustomerCounter(destinationPhone, keywordId)

                            // 🎯 جلب اسم وسعر باقة الهدية من الكاش بدقة
                            val rewardKwMap = AppCache.getKeywords(dbHelper).find { 
                                (it["id"] as? Number)?.toInt() == rewardKeywordId 
                            }
                            val rewardKwText = rewardKwMap?.get("keyword") as? String ?: "عرض مجاني"
                            val rewardPrice = (rewardKwMap?.get("price") as? Number)?.toDouble() ?: 0.0

                            val rewardMessage = "🎉 تهانينا! لقد حصلت على كرت مجاني بمناسبة العرض: $rewardVoucherCode"
                            val isRewardSent = DualSimSmsSender.sendSms(
                                context = context,
                                phoneNumber = destinationPhone,
                                message = rewardMessage
                            )

                            if (isRewardSent) {
                                secureStorage.incrementVouchersUsed()
                                // 2. إطلاق أوان المزامنة مع شرط وجود شبكة إتصال
                                val constraints = androidx.work.Constraints.Builder()
                                    .setRequiredNetworkType(androidx.work.NetworkType.CONNECTED)
                                    .build()

                                val syncWorkRequest = androidx.work.OneTimeWorkRequestBuilder<SyncWorker>()
                                    .setConstraints(constraints)
                                    .build()

                                androidx.work.WorkManager.getInstance(context).enqueueUniqueWork(
                                    "firebase_vouchers_sync",
                                    androidx.work.ExistingWorkPolicy.REPLACE,
                                    syncWorkRequest
                                )
                                // 🎯 أرشفة كارت الهدية بالاسم والسعر الخواص به (مثلاً: فئة 002 وسعرها)
                                dbHelper.addToArchive(
                                    sender = destinationPhone,
                                    senderName = null,
                                    receivedMessage = "هدية عرض للباقة: $keywordText",
                                    matchedKeyword = rewardKwText, // 👈 تم التعديل: اسم باقة الهدية (مثلاً 002)
                                    sentNumber = rewardVoucherCode,
                                    status = "sent_reward",
                                    price = rewardPrice // 👈 تم التعديل: سعر باقة الهدية الحقيقي
                                )
                                // 🟢 إظهار الإشعار من الكلاس المستقل
                                NotificationHelper.showVoucherSentNotification(context, rewardKwText, destinationPhone)
                            }
                            
                            checkAndSendManagerAlert(context, dbHelper, rewardKeywordId, "هدية: $rewardKwText")
                        } else {
                            Log.e("PROCESSOR1", "⚠️ تحقق شرط العرض لكن كروت الهدية غير متوفرة!")
                            checkAndSendManagerAlert(context, dbHelper, rewardKeywordId, "نفاد هدايا العرض للرمز: $keywordId")
                        }
                    }
                }
                // 🎯 ⭐ 8. فحص شرط العرض بعد إرسال القسيمة الأساسية (إرسال الرسالة الثانية)
                /*if (targetCount > 0 && rewardKeywordId != null) {
                    val currentCount = dbHelper.incrementCustomerCounter(destinationPhone, keywordId)
                    
                    if (currentCount >= targetCount) {
                        val rewardVoucherCode = dbHelper.getAndUseVoucher(rewardKeywordId, destinationPhone)

                        if (rewardVoucherCode != null) {
                            // تصفير العداد عند نجاح سحب كرت العرض
                            dbHelper.resetCustomerCounter(destinationPhone, keywordId)

                            
                            val rewardMessage = "🎉 تهانينا! لقد حصلت على كرت مجاني بمناسبة العرض: $rewardVoucherCode"
                            val isRewardSent = DualSimSmsSender.sendSms(
                                context = context,
                                phoneNumber = destinationPhone,
                                message = rewardMessage
                            )

                            if (isRewardSent) {
                                secureStorage.incrementVouchersUsed()
                                // 2. إطلاق أوان المزامنة مع شرط وجود شبكة إتصال
                                val constraints = androidx.work.Constraints.Builder()
                                    .setRequiredNetworkType(androidx.work.NetworkType.CONNECTED)
                                    .build()

                                val syncWorkRequest = androidx.work.OneTimeWorkRequestBuilder<SyncWorker>()
                                    .setConstraints(constraints)
                                    .build()

                                androidx.work.WorkManager.getInstance(context).enqueueUniqueWork(
                                    "firebase_vouchers_sync",
                                    androidx.work.ExistingWorkPolicy.REPLACE,
                                    syncWorkRequest
                                )
                                // هدايا العروض تُحسب بقيمة 0.0 في الأرشيف
                                dbHelper.addToArchive(
                                    sender = destinationPhone,
                                    senderName = null,
                                    receivedMessage = "هدية عرض للكلمة: $keywordText",
                                    matchedKeyword = keywordText,
                                    sentNumber = rewardVoucherCode,
                                    status = "sent_reward",
                                    price = 0.0 // 🎯 الهدايا مجانية (0.0)
                                )
                            }
                            checkAndSendManagerAlert(context, dbHelper, rewardKeywordId, "هدية: $keywordText")
                        } else {
                            Log.e("PROCESSOR1", "⚠️ تحقق شرط العرض لكن كروت الهدية غير متوفرة!")
                            checkAndSendManagerAlert(context, dbHelper, rewardKeywordId, "نفاد هدايا العرض: $keywordText")
                        }
                    }
                }*/
            } else {
                // 🟢 أصلحت هنا: التعامل مع فشل الإرسال (مثلاً عند عدم وجود تغطية)
                Log.e("PROCESSOR1", "⚠️ فشل إرسال الـ SMS (قد لا تتوفر تغطية)، تم حفظ العملية كمعلقة pending")
                dbHelper.addToArchive(
                    sender = destinationPhone,
                    senderName = extractNameFromBody(body) ?: destinationPhone,
                    receivedMessage = body,
                    matchedKeyword = keywordText,
                    sentNumber = mainVoucherCode, // حفظ الكرت المحجوز لإعادة إرساله
                    status = "pending",           // حالة معلقة لعدم التغطية
                    price = keywordPrice
                )
            }
        } else {
            // ⭐ 9. حفظ العملية كمعلقة عند نفاذ المخزون الأساسي
            checkAndSendManagerAlert(context, dbHelper, keywordId, keywordText)
            Log.e("PROCESSOR1", "⚠️ لا تتوفر قسائم حالياً! تم حفظ العملية كمعلقة (voucher_approval_required)")
            
            val rawName = extractNameFromBody(body)
            val extractedWallet = extractWalletFromBody(body)
            val displayName = if (!rawName.isNullOrBlank()) rawName else (extractedWallet ?: destinationPhone)

            dbHelper.addToArchive(
                sender = destinationPhone,
                senderName = displayName,
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = "",
                status = "voucher_approval_required",
                price = keywordPrice // 🎯 تمرير السعر
            )
        }
    }

    /*private fun executeProcessing(context: Context, rawSender: String, originPackage: String, body: String, customerPhoneInput: String) {
        val dbHelper = AppSqliteHelper.getInstance(context)

        // 1. فحص تفعيل الخدمة من الكاش
        if (!AppCache.isServiceEnabled(dbHelper)) return

        // 🎯 1.5. فحص قائمة العملاء المستثنين (إذا كان الرقم مستثنى يتم التجاهل فوراً)
        val checkPhone = if (customerPhoneInput.isNotBlank()) customerPhoneInput else rawSender
        if (dbHelper.isSenderIgnored(checkPhone)) {
            Log.i("PROCESSOR", "تم إهمال الرسالة: الرقم $checkPhone موجود في قائمة العملاء المستثنين.")
            return
        }

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

        // ⭐ 7. سحب القسيمة الأساسية وإرسالها دائماً (الرسالة الأولى)
        val mainVoucherCode = dbHelper.getAndUseVoucher(keywordId, destinationPhone)
        Log.e("PROCESSOR1", "voucher_approval_required=$mainVoucherCode")
            
        if (mainVoucherCode != null) {
            val defaultReply = AppCache.getDefaultReply(dbHelper)
            val fullMessage = "$defaultReply $mainVoucherCode"

            Log.e("UPDATE_CUSTOMER", "mainVoucherCode=$mainVoucherCode")
            val isSent = DualSimSmsSender.sendSms(
                context = context,
                phoneNumber = destinationPhone,
                message = fullMessage
            )
            Log.e("UPDATE_CUSTOMER", "isSent=$isSent")
            // إنشاء كائن التخزين
            val secureStorage = NativeSecureStorage(context)

            if (isSent) {
                // زيادة العداد بمقدار 1 ووضع علم المزامنة تلقائياً
                secureStorage.incrementVouchersUsed()

                // أرشفة القسيمة الأساسية
                dbHelper.addToArchive(
                    sender = destinationPhone,
                    senderName = null,
                    receivedMessage = body,
                    matchedKeyword = keywordText,
                    sentNumber = mainVoucherCode,
                    status = "sent"
                )

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
                
                checkAndSendManagerAlert(context, dbHelper, keywordId, keywordText)

                // 🎯 ⭐ 8. فحص شرط العرض بعد إرسال القسيمة الأساسية (إرسال الرسالة الثانية)
                if (targetCount > 0 && rewardKeywordId != null) {
                    val currentCount = dbHelper.incrementCustomerCounter(destinationPhone, keywordId)
                    
                    if (currentCount >= targetCount) {
                        val rewardVoucherCode = dbHelper.getAndUseVoucher(rewardKeywordId, destinationPhone)

                        if (rewardVoucherCode != null) {
                            // تصفير العداد عند نجاح سحب كرت العرض
                            dbHelper.resetCustomerCounter(destinationPhone, keywordId)

                            val rewardMessage = "🎉 تهانينا! لقد حصلت على كرت مجاني بمناسبة العرض: $rewardVoucherCode"
                            val isRewardSent = DualSimSmsSender.sendSms(
                                context = context,
                                phoneNumber = destinationPhone,
                                message = rewardMessage
                            )

                            if (isRewardSent) {
                                secureStorage.incrementVouchersUsed()
                                dbHelper.addToArchive(
                                    sender = destinationPhone,
                                    senderName = null,
                                    receivedMessage = "هدية عرض للكلمة: $keywordText",
                                    matchedKeyword = keywordText,
                                    sentNumber = rewardVoucherCode,
                                    status = "sent_reward"
                                )
                            }
                            checkAndSendManagerAlert(context, dbHelper, rewardKeywordId, "هدية: $keywordText")
                        } else {
                            Log.e("PROCESSOR1", "⚠️ تحقق شرط العرض لكن كروت الهدية غير متوفرة!")
                            checkAndSendManagerAlert(context, dbHelper, rewardKeywordId, "نفاد هدايا العرض: $keywordText")
                        }
                    }
                }
            }
        } else {
            // ⭐ 9. حفظ العملية كمعلقة عند نفاذ المخزون الأساسي
            checkAndSendManagerAlert(context, dbHelper, keywordId, keywordText)
            Log.e("PROCESSOR1", "⚠️ لا تتوفر قسائم حالياً! تم حفظ العملية كمعلقة (voucher_approval_required)")
            
            val rawName = extractNameFromBody(body)
            val extractedWallet = extractWalletFromBody(body)
            val displayName = if (!rawName.isNullOrBlank()) rawName else (extractedWallet ?: destinationPhone)

            dbHelper.addToArchive(
                sender = destinationPhone,
                senderName = displayName,
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = "",
                status = "voucher_approval_required"
            )
        }

        // ⭐ 7. سحب الكرت وإرسال الـ SMS المباشر
        /*val voucherCode = dbHelper.getAndUseVoucher(finalKeywordIdToUse, destinationPhone)
        Log.e("PROCESSOR1", "voucher_approval_required=$voucherCode")
            
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

            // إنشاء كائن التخزين
            val secureStorage = NativeSecureStorage(context)

            if (isSent) {
                // زيادة العداد بمقدار 1 ووضع علم المزامنة تلقائياً
                secureStorage.incrementVouchersUsed()
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
                // 🎯 إضافة التنبيه هنا (بعد نجاح عملية الإرسال الآلي)
                checkAndSendManagerAlert(context, dbHelper, finalKeywordIdToUse, keywordText)
            }
        } else {
            // 🎯 إضافة التنبيه هنا (عند محاولة السحب وعدم وجود كروت)
            checkAndSendManagerAlert(context, dbHelper, finalKeywordIdToUse, keywordText)
            // ⭐ 9. حفظ العملية كمعلقة عند نفاذ المخزون بحالة voucher_approval_required
            Log.e("PROCESSOR1", "⚠️ لا تتوفر قسائم حالياً! تم حفظ العملية كمعلقة (voucher_approval_required)")
            
            val rawName = extractNameFromBody(body)
            val extractedWallet = extractWalletFromBody(body)
            val displayName = if (!rawName.isNullOrBlank()) rawName else (extractedWallet ?: destinationPhone)

            dbHelper.addToArchive(
                sender = destinationPhone,
                senderName = displayName,
                receivedMessage = body,
                matchedKeyword = keywordText,
                sentNumber = "",
                status = "voucher_approval_required"
            )
        }*/
    }*/

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

//************************************/
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

        //if (voucherCode != null) {
        if (voucherCode..isNullOrBlank()) {
            val defaultReply = AppCache.getDefaultReply(dbHelper)
            val messagePrefix = if (isRewardGranted) "تهانينا! لقد حصلت على هدية العرض: " else defaultReply
            val fullMessage = "$messagePrefix $voucherCode"

            val isSent = DualSimSmsSender.sendSms(
                context = context,
                phoneNumber = destinationPhone,
                message = fullMessage
            )

            // ⭐ الأرشفة وتحديث البيانات
            // إنشاء كائن التخزين
            val secureStorage = NativeSecureStorage(context)

            if (isSent) {
                // زيادة العداد بمقدار 1 ووضع علم المزامنة تلقائياً
                secureStorage.incrementVouchersUsed()
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