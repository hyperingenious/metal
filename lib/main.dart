import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'screens/phone_input_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/home_screen.dart'; 
import 'appwrite/appwrite.dart'; 
import 'screens/auth_gate.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Appwrite Phone Auth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepPurple),

      // Use AuthGate as the home widget
      home: const AuthGate(),
      routes: {'/main': (context) => const HomeScreen()},
    );
  }
}