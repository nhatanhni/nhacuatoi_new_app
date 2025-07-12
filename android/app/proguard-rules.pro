# Add project specific ProGuard rules here.
# You can control the set of set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Android 15 compatibility - Edge-to-edge support
-keep class androidx.core.view.** { *; }
-keep class androidx.activity.** { *; }
-keep class androidx.window.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class androidx.core.** { *; }
-keep class androidx.fragment.** { *; }
-keep class androidx.appcompat.** { *; }
-keep class androidx.annotation.** { *; }
-keep class androidx.collection.** { *; }

# Edge-to-edge display support - specific classes
-keep class androidx.core.view.WindowInsetsCompat { *; }
-keep class androidx.core.view.WindowInsetsControllerCompat { *; }
-keep class androidx.core.view.WindowCompat { *; }
-keep class androidx.core.view.WindowInsetsAnimationCompat { *; }
-keep class androidx.core.view.WindowInsetsAnimationControllerCompat { *; }

# Material Design - Android 15 compatibility
-keep class com.google.android.material.** { *; }

# MQTT client
-keep class org.eclipse.paho.client.mqttv3.** { *; }

# WiFi scanning
-keep class android.net.wifi.** { *; }

# Camera permissions
-keep class androidx.camera.** { *; }

# 16KB page size optimization for Android 15
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Android 15 specific optimizations
-keep class com.nhacuatoimqtt.iotapp.** { *; }
-keepclassmembers class com.nhacuatoimqtt.iotapp.** {
    *;
}

# Optimize for 16KB page size - specific optimizations
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification

# Remove debug logs in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
}

# Android 15 specific - avoid deprecated API usage
-dontwarn android.view.Window
-dontwarn android.view.WindowManager
-dontwarn android.view.WindowInsets

# Edge-to-edge specific rules
-keep class androidx.core.view.WindowInsetsCompat$Type { *; }
-keep class androidx.core.view.WindowInsetsControllerCompat$Behavior { *; }

# Additional Android 15 optimizations
-keep class androidx.annotation.NonNull { *; }
-keep class androidx.annotation.Nullable { *; } 