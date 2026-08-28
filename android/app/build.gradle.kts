plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.app.cardpay"

    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.app.cardpay"

        minSdk = 21
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 🟢 تحديد المعماريات المستهدفة لتقليل حجم الـ APK وصعوبة التفكيك
        ndk {
            abiFilters.addAll(setOf("armeabi-v7a", "arm64-v8a", "x86_64"))
        }
    }

    // 🟢 ربط بناء كود C++ Native
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("KEYSTORE_PATH") ?: "kha.jks"
            val keystoreFile = rootProject.file("app/$keystorePath")

            if (keystoreFile.exists()) {
                storeFile = keystoreFile
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            if (releaseSigning.storeFile != null && releaseSigning.storeFile!!.exists()) {
                signingConfig = releaseSigning
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }

            //isMinifyEnabled = false
            //isShrinkResources = false
            // 🟢 تفعيل التمويه وتقليص الكود والموارد
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-messaging-ktx")
}

flutter {
    source = "../.."
}