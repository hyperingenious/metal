import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'phone_auth_screen.dart';
import 'main_app_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool? isAuthenticated;

  @override
  void initState() {
    super.initState();
    checkAuth();
  }

  void checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    bool auth = prefs.getBool('isAuthenticated') ?? false;
    if (auth) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainAppScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PhoneAuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
