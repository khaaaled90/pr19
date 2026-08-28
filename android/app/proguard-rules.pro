# حماية جميع الحزم والكلاسات والدوال في المشروع والمكتبات
#-keep class ** { *; }
#-keepclassmembers class ** { *; }
#-dontwarn **
#-dontnote **
# =====================================================================
# 1. إعدادات التمويه والضغط المشددة
# =====================================================================

# إزالة جميع سجلات الـ Logging لحماية مسارات الكود والبيانات الحساسة
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# إعادة تسمية الكلاسات والحزم بأسماء مبهمة وقصيرة جداً
-repackageclasses ''
-allowaccessmodification
-flattenpackagehierarchy ''

# إخفاء أسماء الملفات الأصلية وأرقام الأسطر
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature

# =====================================================================
# 2. قواعد استثناء المكتبات الأساسية (لمنع إنهيار التطبيق)
# =====================================================================

# --- Flutter Engine & Plugins ---
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# --- Firebase ---
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# --- AndroidX WorkManager & Crypto ---
-keep class androidx.work.** { *; }
-keep class androidx.security.crypto.** { *; }

# --- Native C/C++ Code (JNI) ---
-keepclasseswithmembernames class * {
    native <methods>;
}

# --- SQLite & Serialization ---
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    private void writeReplace();
    private void readResolve();
}

# عدم طباعة تحذيرات للمكتبات الخارجيّة
-dontwarn **
-dontnote **

# =====================================================================
# استثناء إضافات Flutter والـ Method Channels (يمنع اختفاء وإخفاق الـ UI)
# =====================================================================

# استثناء كافة plugins الخاصة بـ Flutter
-keep class io.flutter.plugins.** { *; }
-keep class dev.fluttercommunity.** { *; }

# استثناء خاص بمكتبة url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class dev.fluttercommunity.plus.urllauncher.** { *; }

# عدم حذف أو تغيير أسماء الـ Annotations المطلوبة للـ MethodChannels
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# منع حجب أو حذف كلاسات المساعدة الديناميكية للواجهات
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
# =====================================================================
# حماية كلاسات الأمان والـ JNI الخاصة بالتطبيق (Security & Native)
# =====================================================================

# منع R8 من تغيير اسم أو مسار كلاس SecurityHelper والدوال التابعة له
-keep class com.app.cardpay.SecurityHelper {
    public static *** isSecurityViolated(...);
    private static *** getAppSignatureSha256(...);
    public static *** verifySignatureNative(...);
    native <methods>;
}
# 1. تثبيت أسماء المستقبلات والخدمات لتبقى مطابقة لـ AndroidManifest.xml (ضروري جداً)
-keep class com.app.cardpay.SmsReceiver { *; }
-keep class com.app.cardpay.NativeNotificationListener { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.app.cardpay.MyFirebaseMessagingService { *; }
-keep class com.app.cardpay.AppSqliteHelper { *; }


# 2. تمويه وتعتيم كلاسات التخزين والترخيص (آمن تماماً ولن يسبب كراش)
-keep,allowobfuscation class com.app.cardpay.NativeSecureStorage { *; }
-keep,allowobfuscation class com.app.cardpay.LicenseManager { *; }
-keep,allowobfuscation class com.app.cardpay.ProcessMessageProcessor { *; }
-keep,allowobfuscation class com.app.cardpay.NotificationHelper { *; }
-keep,allowobfuscation class com.app.cardpay.SecurityHelper { *; }

