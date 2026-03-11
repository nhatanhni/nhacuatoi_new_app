import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iot_app/screens/home_screen.dart';
import 'package:iot_app/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String accessToken = prefs.getString('accessToken') ?? '';

  runApp(MyApp(initialRoute: accessToken.isEmpty ? '/login' : '/'));
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final String initialRoute;

  const MyApp({Key? key, required this.initialRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Pump Station',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => HomeScreen(),
        '/login': (context) => LoginScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
