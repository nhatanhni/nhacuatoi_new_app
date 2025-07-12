package com.nhacuatoimqtt.iotapp.iot_app

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsAnimationControllerCompat

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Configure edge-to-edge display for Android 15 compatibility
        // Using modern APIs instead of deprecated ones
        
        // Configure window for edge-to-edge experience
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Configure system bars with modern API
        val windowInsetsController = WindowCompat.getInsetsController(window, window.decorView)
        
        // Set light appearance for system bars
        windowInsetsController.isAppearanceLightStatusBars = true
        windowInsetsController.isAppearanceLightNavigationBars = true
        
        // Ensure system bars are visible and properly handled
        windowInsetsController.show(WindowInsetsCompat.Type.systemBars())
        
        // Handle system bar insets properly for edge-to-edge
        windowInsetsController.systemBarsBehavior = 
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
    }
    
    override fun onResume() {
        super.onResume()
        
        // Ensure edge-to-edge is maintained when app resumes
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
} 