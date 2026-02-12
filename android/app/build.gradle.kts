plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.afsheen.pinknote"
    compileSdk = 36
    ndkVersion = "27.0.12077973" // From your file

    // This is the modern and preferred way to set the Java version for the app module.
    kotlin {
        jvmToolchain(17)
    }

    // ✅ REDUNDANT BUT FORCEFUL FIX:
    // We are adding this block in addition to the jvmToolchain setting above.
    // Sometimes, a misconfigured plugin (like the one causing the error)
    // will ignore the jvmToolchain but respect this older, more explicit setting.
    // This should finally force all Kotlin compilation in this module to use Java 17.
    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            storeFile = file("keystore.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: project.property("KEYSTORE_PASSWORD") as String
            keyAlias = System.getenv("KEY_ALIAS") ?: project.property("KEY_ALIAS") as String
            keyPassword = System.getenv("KEY_PASSWORD") ?: project.property("KEY_PASSWORD") as String
        }
    }

    defaultConfig {
        applicationId = "com.afsheen.pinknote"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // This is required by flutter_local_notifications and other plugins.
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ UPDATED the desugar_jdk_libs version as required by the build error.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // The Kotlin standard library.
    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")

    // Your other dependencies
    implementation("com.google.android.gms:play-services-auth:21.0.0")
    implementation("com.google.firebase:firebase-auth:22.3.1")
}