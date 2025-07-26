// main.dart
import 'package:flutter/material.dart';
import 'package:metal/screens/auth_gate.dart';
import 'package:metal/screens/home_screen.dart';
import 'package:metal/screens/phone_input_screen.dart';
import 'package:metal/screens/profile_completion/profile_completion_router.dart';
import 'package:metal/screens/settings_screen.dart';

void main(){
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
