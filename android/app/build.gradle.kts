import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.nhacuatoimqtt.iotapp"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nhacuatoimqtt.iotapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 21
        targetSdk = 35
        versionCode = 16
        versionName = "2.0.7"
        
        // Android 15 specific configurations
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file("$it") }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    
    // Android 15 16KB page size support
    packagingOptions {
        jniLibs {
            useLegacyPackaging = false
        }
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/DEPENDENCIES"
            excludes += "META-INF/LICENSE"
            excludes += "META-INF/LICENSE.txt"
            excludes += "META-INF/license.txt"
            excludes += "META-INF/NOTICE"
            excludes += "META-INF/NOTICE.txt"
            excludes += "META-INF/notice.txt"
            excludes += "META-INF/ASL2.0"
            excludes += "META-INF/*.kotlin_module"
        }
        // Enable 16KB page size support for Android 15
        dex {
            useLegacyPackaging = false
        }
    }
    
    // Android 15 specific configurations
    buildFeatures {
        buildConfig = true
    }
    
    // Enable proper edge-to-edge support
    androidResources {
        generateLocaleConfig = false
    }
    
    // Android 15 specific optimizations
    bundle {
        language {
            enableSplit = true
        }
        density {
            enableSplit = true
        }
        abi {
            enableSplit = true
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // Material Design - latest version for Android 15
    implementation("com.google.android.material:material:1.12.0")
    
    // AndroidX Core - latest versions for Android 15
    implementation("androidx.core:core-ktx:1.13.0")
    implementation("androidx.core:core:1.13.0")
    
    // Activity - latest version for edge-to-edge support
    implementation("androidx.activity:activity:1.9.0")
    implementation("androidx.activity:activity-ktx:1.9.0")
    
    // Window - for edge-to-edge support
    implementation("androidx.window:window:1.2.0")
    implementation("androidx.window:window-java:1.2.0")
    
    // Lifecycle - for Android 15 compatibility
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.0")
    implementation("androidx.lifecycle:lifecycle-common-java8:2.8.0")
    
    // Edge-to-edge support
    implementation("androidx.core:core-splashscreen:1.0.1")
    
    // Fragment - for Android 15
    implementation("androidx.fragment:fragment-ktx:1.7.0")
    
    // AppCompat - for backward compatibility
    implementation("androidx.appcompat:appcompat:1.7.0")
    
    // Additional Android 15 support
    implementation("androidx.annotation:annotation:1.8.0")
    implementation("androidx.collection:collection-ktx:1.4.0")
}

flutter {
    source = "../.."
}
