import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Key properties dosyasını yükle
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "dev.ogos.anotheriptvplayer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Signing configurations
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    defaultConfig {
        applicationId = "dev.ogos.anotheriptvplayer"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ── ABI Splits: produce one APK per CPU architecture ──────────────────
    // arm64-v8a  → all modern Android phones (2016+)
    // armeabi-v7a → older 32-bit phones
    // x86_64     → emulators / Chrome OS (optional)
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = false   // set true only if you need a fat fallback APK
        }
    }

    // Give each ABI APK a unique versionCode (required by Play Store)
    val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
    applicationVariants.all {
        val variant = this
        outputs.forEach { output ->
            val baseVariantOutput = output as com.android.build.gradle.api.BaseVariantOutput
            val abiName = baseVariantOutput.getFilter(com.android.build.OutputFile.ABI)
            val abiCode = abiCodes[abiName] ?: 0
            if (abiCode != 0) {
                baseVariantOutput.versionCodeOverride = (variant.versionCode ?: 0) * 10 + abiCode
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Sadece keystore dosyası varsa signing kullan
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true   // ← ADD THIS: strips unused Android resources
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }

        // CI için imzasız build type
        create("releaseUnsigned") {
            isMinifyEnabled = true
            isShrinkResources = true   // ← ADD THIS too
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // signingConfig tanımlanmıyor - imzasız build
        }
    }
}

flutter {
    source = "../.."
}