// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:lushh/screens/auth_gate.dart';
import 'firebase_options.dart';
import 'package:lushh/screens/home_screen.dart';
import 'package:lushh/screens/phone_input_screen.dart';
import 'package:lushh/screens/profile_completion/profile_completion_router.dart';
import 'package:lushh/screens/settings_screen.dart';
import 'package:lushh/services/config_service.dart';


// This top-level function handles messages when the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // print("🔔 Handling a background message: ${message.messageId}");
}

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up the background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
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