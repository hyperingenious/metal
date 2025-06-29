import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../appwrite/appwrite.dart'; // your configured Appwrite client
import 'phone_input_screen.dart';  // for redirection after logout

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      await account.deleteSession(sessionId: 'current');

      // Navigate back to phone login after logout
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
        (route) => false,
      );
    } on AppwriteException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Logout failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _logout(context),
          child: const Text('Logout'),
        ),
      ),
    );
  }
}
