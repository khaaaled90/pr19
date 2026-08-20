#include <jni.h>
#include <string>
#include <android/log.h>
#include <unistd.h>
#include <signal.h>
#include <cstdio>

const char* OFFICIAL_SHA256 = "94CB9C92B7692B8FB222C1DED9EB4B18F8992B036EB8FC1619B320204030AF7A";

bool verifySelfSignatureNative(JNIEnv* env, jobject context) {
    if (context == NULL) return false;

    // 1. Get SDK Version
    jclass versionClass = env->FindClass("android/os/Build$VERSION");
    jfieldID sdkIntField = env->GetStaticFieldID(versionClass, "SDK_INT", "I");
    jint sdkInt = env->GetStaticIntField(versionClass, sdkIntField);

    // 2. Context.getPackageManager() & Context.getPackageName()
    jclass contextClass = env->GetObjectClass(context);
    jmethodID getPM = env->GetMethodID(contextClass, "getPackageManager", "()Landroid/content/pm/PackageManager;");
    jobject packageManager = env->CallObjectMethod(context, getPM);

    jmethodID getPkgName = env->GetMethodID(contextClass, "getPackageName", "()Ljava/lang/String;");
    jstring packageName = (jstring)env->CallObjectMethod(context, getPkgName);

    jclass pmClass = env->GetObjectClass(packageManager);
    jobject packageInfo = NULL;

    jobject signature = NULL;

    if (sdkInt >= 28) { // Android 9.0+
        // GET_SIGNING_CERTIFICATES = 0x08000000
        jmethodID getPackageInfo = env->GetMethodID(pmClass, "getPackageInfo", "(Ljava/lang/String;I)Landroid/content/pm/PackageInfo;");
        packageInfo = env->CallObjectMethod(packageManager, getPackageInfo, packageName, 0x08000000);

        if (packageInfo == NULL) return false;

        jclass packageInfoClass = env->GetObjectClass(packageInfo);
        jfieldID signingInfoField = env->GetFieldID(packageInfoClass, "signingInfo", "Landroid/content/pm/SigningInfo;");
        jobject signingInfo = env->GetObjectField(packageInfo, signingInfoField);

        if (signingInfo == NULL) return false;

        jclass signingInfoClass = env->GetObjectClass(signingInfo);
        jmethodID getApkContentsSigners = env->GetMethodID(signingInfoClass, "getApkContentsSigners", "()[Landroid/content/pm/Signature;");
        jobjectArray signatures = (jobjectArray)env->CallObjectMethod(signingInfo, getApkContentsSigners);

        if (signatures == NULL || env->GetArrayLength(signatures) == 0) return false;
        signature = env->GetObjectArrayElement(signatures, 0);

    } else { // Android 8.1 and lower
        // GET_SIGNATURES = 0x00000040
        jmethodID getPackageInfo = env->GetMethodID(pmClass, "getPackageInfo", "(Ljava/lang/String;I)Landroid/content/pm/PackageInfo;");
        packageInfo = env->CallObjectMethod(packageManager, getPackageInfo, packageName, 0x00000040);

        if (packageInfo == NULL) return false;

        jclass packageInfoClass = env->GetObjectClass(packageInfo);
        jfieldID signaturesField = env->GetFieldID(packageInfoClass, "signatures", "[Landroid/content/pm/Signature;");
        jobjectArray signatures = (jobjectArray)env->GetObjectField(packageInfo, signaturesField);

        if (signatures == NULL || env->GetArrayLength(signatures) == 0) return false;
        signature = env->GetObjectArrayElement(signatures, 0);
    }

    if (signature == NULL) return false;

    // 3. MessageDigest SHA-256 Calculation
    jclass messageDigestClass = env->FindClass("java/security/MessageDigest");
    jmethodID getInstance = env->GetStaticMethodID(messageDigestClass, "getInstance", "(Ljava/lang/String;)Ljava/security/MessageDigest;");
    jstring algorithm = env->NewStringUTF("SHA-256");
    jobject digestObj = env->CallStaticObjectMethod(messageDigestClass, getInstance, algorithm);

    jclass signatureClass = env->GetObjectClass(signature);
    jmethodID toByteArray = env->GetMethodID(signatureClass, "toByteArray", "()[B");
    jbyteArray sigBytes = (jbyteArray)env->CallObjectMethod(signature, toByteArray);

    jmethodID digestMethod = env->GetMethodID(messageDigestClass, "digest", "([B)[B");
    jbyteArray hashBytes = (jbyteArray)env->CallObjectMethod(digestObj, digestMethod, sigBytes);

    if (hashBytes == NULL) return false;

    // 4. Convert Bytes to Hex
    jsize length = env->GetArrayLength(hashBytes);
    jbyte* buffer = env->GetByteArrayElements(hashBytes, NULL);

    char hexBuffer[67]; // تكبير حجم المصفوفة بأمان لتجنب أي Buffer Overflow
    for (int i = 0; i < length; i++) {
        snprintf(&hexBuffer[i * 2], 3, "%02X", (unsigned char)buffer[i]);
    }
    hexBuffer[64] = '\0';
    env->ReleaseByteArrayElements(hashBytes, buffer, JNI_ABORT);

    return (std::string(hexBuffer) == OFFICIAL_SHA256);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_pr19_SecurityHelper_initSecurityNative(JNIEnv* env, jobject /* thiz */, jobject context) {
    bool isValid = verifySelfSignatureNative(env, context);

    if (!isValid) {
        // 🔴 إنهاء العملية فوراً ومباشرة من الـ Native
        kill(getpid(), SIGKILL);
        exit(0);
    }
}

//#include <jni.h>
//#include <string>
//#include <android/log.h>

// ضع هنا الـ SHA-256 الخاصة بتوقيع Release الخاطف بك (بالحروف الكبيرة وبدون : )
// يمكن تقييد الفحص بالتأكد من أن التوقيع يطابق مفتاحك الأصلي
//const char* EXPECTED_SHA256 = "94CB9C92B7692B8FB222C1DED9EB4B18F8992B036EB8FC1619B320204030AF7A";

//extern "C" JNIEXPORT jboolean JNICALL
//Java_com_example_pr19_SecurityHelper_verifySignatureNative(
//        JNIEnv* env,
//        jobject /* thiz */,
/*        jstring currentSignature) {

    if (currentSignature == NULL) return JNI_FALSE;

    // تحويل النص من Java String إلى C++ String
    const char* nativeString = env->GetStringUTFChars(currentSignature, 0);
    std::string currentSigStr(nativeString);
    env->ReleaseStringUTFChars(currentSignature, nativeString);

    // المقارنة الفعلية وإعادة النتيجة
    return (currentSigStr == EXPECTED_SHA256) ? JNI_TRUE : JNI_FALSE;
}*/