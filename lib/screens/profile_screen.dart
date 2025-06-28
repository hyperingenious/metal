import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_app_screen.dart';

class ProfileScreen extends StatelessWidget {
  final nameController = TextEditingController();
  final countryController = TextEditingController();

  Future<void> saveProfile(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAuthenticated', true);
    await prefs.setString('name', nameController.text);
    await prefs.setString('country', countryController.text);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MainAppScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: 'Name')),
            TextField(controller: countryController, decoration: InputDecoration(labelText: 'Country')),
            SizedBox(height: 20),
            ElevatedButton(onPressed: () => saveProfile(context), child: Text('Save Profile')),
          ],
        ),
      ),
    );
  }
}
