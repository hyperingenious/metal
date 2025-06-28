import 'package:flutter/material.dart';
import 'profile_screen.dart';

class PhoneAuthScreen extends StatelessWidget {
  final phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Enter Phone Number')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: phoneController, decoration: InputDecoration(labelText: 'Phone')),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen()),
                );
              },
              child: Text('Verify (Mock)'),
            ),
          ],
        ),
      ),
    );
  }
}
