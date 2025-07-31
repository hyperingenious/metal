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

    if (!isAllCompleted) {
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

/*
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/screens/otp_screen.dart';
import '../appwrite/appwrite.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  String databaseId = '685a90fa0009384c5189';
  String completionStatusCollectionId = '686777d300169b27b237';
  Future<void> _checkSession() async {
    try {
      final session = await account.getSession(sessionId: 'current');

      final userId = session.userId;
      final doc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: completionStatusCollectionId,
        queries: [Query.equal('user', userId)],
      );

      bool isAllCompleted = doc.documents[0].data['isAllCompleted'] ?? false;

      print(isAllCompleted);

      if (!isAllCompleted) {
        Navigator.pushReplacementNamed(context, '/profile_completion_router');
      } else {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (_) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/phone_input_screen');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
*/
