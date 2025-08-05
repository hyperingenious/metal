// main.dart
import 'package:flutter/material.dart';
import 'package:lushh/screens/auth_gate.dart';
import 'package:lushh/screens/home_screen.dart';
import 'package:lushh/screens/phone_input_screen.dart';
import 'package:lushh/screens/profile_completion/profile_completion_router.dart';
import 'package:lushh/screens/settings_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lushh',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(
          0xFFFAFAFA,
        ), // Very light background for entire app
      ),
      initialRoute: '/',
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute(
          builder: (context) => AuthGate(requestedRoute: settings.name),
          settings: settings,
        );
      },
    );
  }
}
