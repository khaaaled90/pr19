package com.example.pr19

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.tasks.await

class SyncWorker(appContext: Context, workerParams: WorkerParameters) :
    CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            val storage = NativeSecureStorage(applicationContext)

            val needsSync = storage.getNeedsSync()
            val deviceId = storage.getDeviceId()
            val vouchersUsed = storage.getVouchersUsed()

            // إذا لم تكن هناك حاجة للمزامنة أو رقم الجهاز غير موجود
            if (!needsSync || deviceId.isEmpty()) {
                return Result.success()
            }

            val db = FirebaseFirestore.getInstance()
            val updateData = mapOf(
                "device_id" to deviceId,
                "vouchers_used" to vouchersUsed
            )

            // الرفع للفايربيس
            db.collection("licenses").document(deviceId)
                .set(updateData, SetOptions.merge())
                .await()

            // تصفير علم المزامنة فور النجاح
            storage.setNeedsSync(false)
            Result.success()

        } catch (e: Exception) {
            Result.retry() // عند انقطاع النت يعيد المحاولة تلقائياً عند توفره
        }
    }
}