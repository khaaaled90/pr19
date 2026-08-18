#include <jni.h>
#include <string>
#include <android/log.h>

// ضع هنا الـ SHA-256 الخاصة بتوقيع Release الخاطف بك (بالحروف الكبيرة وبدون : )
// يمكن تقييد الفحص بالتأكد من أن التوقيع يطابق مفتاحك الأصلي
const char* EXPECTED_SHA256 = "94CB9C92B7692B8FB222C1DED9EB4B18F8992B036EB8FC1619B320204030AF7A";

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_pr19_SecurityHelper_verifySignatureNative(
        JNIEnv* env,
        jobject /* thiz */,
        jstring currentSignature) {

    if (currentSignature == NULL) return JNI_FALSE;

    // تحويل النص من Java String إلى C++ String
    const char* nativeString = env->GetStringUTFChars(currentSignature, 0);
    std::string currentSigStr(nativeString);
    env->ReleaseStringUTFChars(currentSignature, nativeString);

    // المقارنة الفعلية وإعادة النتيجة
    return (currentSigStr == EXPECTED_SHA256) ? JNI_TRUE : JNI_FALSE;
}