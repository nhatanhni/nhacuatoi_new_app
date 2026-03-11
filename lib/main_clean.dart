import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Conditional imports for platform-specific implementations
import 'main_web_simple.dart' if (dart.library.io) 'main_mobile.dart';

void main() {
  if (kIsWeb) {
    // For web platform, use the simple web main
    runApp(const IoTApp());
  } else {
    // For mobile platforms, use placeholder for now
    runApp(const MobileApp());
  }
}

// Placeholder for mobile app
class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Control App - Mobile',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Mobile Version'),
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_android, size: 100, color: Colors.blue),
              SizedBox(height: 20),
              Text(
                'Mobile version',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('Full mobile app implementation needed'),
            ],
          ),
        ),
      ),
    );
  }
}
