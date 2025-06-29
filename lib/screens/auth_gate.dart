import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../appwrite/appwrite.dart';
import 'home_screen.dart';
import 'phone_input_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final session = await account.getSession(sessionId: 'current');
      setState(() {
        _hasSession = session != null;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _hasSession = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_hasSession) {
      return const HomeScreen();
    } else {
      return const PhoneInputScreen();
    }
  }
}
