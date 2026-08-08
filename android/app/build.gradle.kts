plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // ✅ إضافة إضافة خدمات جوجل الخاصة بـ Firebase (صيغة Kotlin DSL)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.pr19"

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
        applicationId = "com.example.pr19"
        
        minSdk = 21
        targetSdk = 36
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 🔑 إعدادات التوقيع باستعمال بيانات GitHub Secrets
    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("KEYSTORE_PATH") ?: "kha.jks"
            val keystoreFile = rootProject.file("app/$keystorePath")
            
            // تحقق مما إذا كان ملف الـ Keystore موجوداً قبل ضبط التوقيع
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
            // استخدام التوقيع المحدد أعلاه عند البناء
            val releaseSigning = signingConfigs.getByName("release")
            if (releaseSigning.storeFile != null && releaseSigning.storeFile!!.exists()) {
                signingConfig = releaseSigning
            } else {
                // للعمل المحلي في حال عدم وجود ملف الـ Keystore
                signingConfig = signingConfigs.getByName("debug")
            }

            isMinifyEnabled = false
            isShrinkResources = false
    
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    
    // ✅ إضافة مكتبة WorkManager المفقودة (صيغة Kotlin DSL)
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-firestore-ktx")
}

flutter {
    source = "../.."
}
