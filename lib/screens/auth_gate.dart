// auth_gate.dart
import 'package:appwrite/appwrite.dart';

import 'package:flutter/material.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'home_screen.dart';
import 'phone_input_screen.dart';
import 'profile_completion/profile_completion_router.dart';
import 'settings_screen.dart';

// Import IDs from .env using String.fromEnvironment
const String databaseId = String.fromEnvironment('DATABASE_ID');
const String completionStatusCollectionId = String.fromEnvironment(
  'COMPLETION_STATUS_COLLECTIONID',
);

class AuthGate extends StatefulWidget {
  final String? requestedRoute;
  const AuthGate({super.key, this.requestedRoute});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool isChecking = true;
  bool isLoggedIn = false;
  bool isAllCompleted = false;
  bool isAnsweredQuestions = false;

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  void checkLogin() async {
    try {
      await account.get(); // will throw if unauthenticated
      final user = await account.get();
      final userId = user.$id;

      final doc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: completionStatusCollectionId,
        queries: [Query.equal('user', userId)],
      );

      setState(() {
        isLoggedIn = true;
        isChecking = false;
        isAllCompleted = doc.documents[0].data['isAllCompleted'] ?? false;
        isAnsweredQuestions = doc.documents[0].data['isAnsweredQuestions'] ?? false;
      });
    } catch (e) {
      setState(() {
        isLoggedIn = false;
        isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!isLoggedIn) {
      return const PhoneInputScreen();
    }

    if (!isAllCompleted || !isAnsweredQuestions) {
      return const ProfileCompletionRouter();
    }

    switch (widget.requestedRoute) {
      case '/main':
        return const HomeScreen();
      case '/settings':
        return const SettingsScreen();
      case '/profile_completion_router':
        return const ProfileCompletionRouter();
      default:
        return const HomeScreen();
    }
  }
}