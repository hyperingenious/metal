import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:metal/appwrite/appwrite.dart';
import 'package:metal/screens/otp_screen.dart';
import 'package:metal/screens/profile_completion/screen_1.dart';
import 'package:metal/screens/profile_completion/screen_2.dart';
import 'package:metal/screens/profile_completion/screen_3.dart';
import 'package:metal/screens/profile_completion/screen_4.dart';
import 'package:metal/screens/profile_completion/screen_5.dart';
import 'package:metal/screens/profile_completion/screen_6.dart';
import 'package:metal/screens/profile_completion/screen_7.dart';
import 'package:metal/screens/profile_completion/screen_8.dart';
// import 'dob_name_screen.dart';    // first onboarding screen
// import 'hobbies_screen.dart';     // next screen (optional)
// import 'home_screen.dart';        // final screen

class ProfileCompletionRouter extends StatefulWidget {
  const ProfileCompletionRouter({super.key});

  @override
  State<ProfileCompletionRouter> createState() =>
      _ProfileCompletionRouterState();
}

class _ProfileCompletionRouterState extends State<ProfileCompletionRouter> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkProfileStatus();
  }

  String databaseId = '685a90fa0009384c5189';
  String completionStatusCollectionId = '686777d300169b27b237';

  Future<void> _checkProfileStatus() async {
    try {
      final user = await account.get();
      final userId = user.$id;

      final doc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: completionStatusCollectionId,
        queries: [Query.equal('user', userId)],
      );

      final completionDocument = doc.documents[0];

      final isAddedDOBAndName =
          completionDocument.data['isAddedDOBAndName'] as bool? ?? false;

      final isHeightAdded =
          completionDocument.data['isHeightAdded'] as bool? ?? false;

      final isGenderAdded =
          completionDocument.data['isGenderAdded'] as bool? ?? false;

      final isAddedHobbies =
          completionDocument.data['isAddedHobbies'] as bool? ?? false;

      final isAddedMinMaxAge =
          completionDocument.data['isAddedMinMaxAge'] as bool? ?? false;

      final isAddedPreferredMaxDistAndHobbies =
          completionDocument.data['isAddedPreferredMaxDistAndHobbies']
              as bool? ??
          false;

      final isAllImagesAdded =
          completionDocument.data['isAllImagesAdded'] as bool? ?? false;

      final isLocationAdded =
          completionDocument.data['isLocationAdded'] as bool? ?? false;

      if (isAddedDOBAndName == false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AddDobAndNameScreen()),
        );
      } else if (isHeightAdded == false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AddHeightScreen()),
        );
      } else if (isGenderAdded == false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AddGenderScreen()),
        );
      } else if (isAddedHobbies == false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AddHobbiesScreen()),
        );
      } else if (isAddedMinMaxAge == false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AddMinMaxAgeScreen()),
        );
      } else if (isAddedPreferredMaxDistAndHobbies == false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AddPreferredMaxDistAndHobbiesScreen(),
          ),
        );
      } else if (isAllImagesAdded == false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AddImagesScreen()),
        );
      } else if (isLocationAdded == false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AddLocationScreen()),
        );
      }
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        final user = await account.get();
        final userId = user.$id;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AddDobAndNameScreen()),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : const SizedBox(),
    );
  }
}
