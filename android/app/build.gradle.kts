import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Reads android/app/google-services.json (project wazapp-512609, package com.webappypie.wazapp).
    id("com.google.gms.google-services")
}

android {
    namespace = "com.webappypie.wazapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.webappypie.wazapp"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Google Mobile Ads App ID (guide section 8). The App ID is a manifest value (never served at runtime):
        // debug/profile builds carry Google's official TEST App ID so a dev build can never touch production ads.
        manifestPlaceholders["admobAppId"] = "ca-app-pub-3940256099942544~3347511713"
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Production Google Mobile Ads App ID for WazApp (guide section 8, production identifiers table).
            manifestPlaceholders["admobAppId"] = "ca-app-pub-4918750794442822~8675091503"
            // Release builds are never silently debug-signed. Provide android/key.properties
            // (see key.properties.example) or pass -PallowDebugSigning=true for local R8 checks only.
            signingConfig = when {
                keystorePropertiesFile.exists() -> signingConfigs.getByName("release")
                project.hasProperty("allowDebugSigning") -> signingConfigs.getByName("debug")
                else -> null
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Video editing (trim / crop / mute / overlays) and H.264 export. Same media3 line as video_player_android.
    implementation("androidx.media3:media3-transformer:1.9.2")
    implementation("androidx.media3:media3-effect:1.9.2")
    implementation("androidx.media3:media3-common:1.9.2")
    implementation("com.google.guava:guava:33.4.0-android")
}
