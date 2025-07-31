import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/appwrite/appwrite.dart' as appwrite;
import 'package:lushh/screens/profile_completion/screen_1.dart';
import 'package:lushh/screens/profile_completion/screen_2.dart';
import 'package:lushh/screens/profile_completion/screen_3.dart';
import 'package:lushh/screens/profile_completion/screen_4.dart';
import 'package:lushh/screens/profile_completion/screen_5.dart';
import 'package:lushh/screens/profile_completion/screen_6.dart';
import 'package:lushh/screens/profile_completion/screen_7.dart';
import 'package:lushh/screens/profile_completion/screen_8.dart';

// Import all IDs from environment using String.fromEnvironment
const appwriteDevKey = String.fromEnvironment('APPWRITE_DEV_KEY');
const appwriteEndpoint = String.fromEnvironment('APPWRITE_ENDPOINT');
const projectId = String.fromEnvironment('PROJECT_ID');
const databaseId = String.fromEnvironment('DATABASE_ID');
const biodataCollectionId = String.fromEnvironment('BIODATA_COLLECTIONID');
const blockedCollectionId = String.fromEnvironment('BLOCKED_COLLECTIONID');
const completionStatusCollectionId = String.fromEnvironment(
  'COMPLETION_STATUS_COLLECTIONID',
);
const connectionsCollectionId = String.fromEnvironment(
  'CONNECTIONS_COLLECTIONID',
);
const hasShownCollectionId = String.fromEnvironment('HAS_SHOWN_COLLECTIONID');
const hobbiesCollectionId = String.fromEnvironment('HOBBIES_COLLECTIONID');
const imageCollectionId = String.fromEnvironment('IMAGE_COLLECTIONID');
const locationCollectionId = String.fromEnvironment('LOCATION_COLLECTIONID');
const messageInboxCollectionId = String.fromEnvironment(
  'MESSAGE_INBOX_COLLECTIONID',
);
const messagesCollectionId = String.fromEnvironment('MESSAGES_COLLECTIONID');
const notificationsCollectionId = String.fromEnvironment(
  'NOTIFICATIONS_COLLECTIONID',
);
const preferenceCollectionId = String.fromEnvironment(
  'PREFERENCE_COLLECTIONID',
);
const reportsCollectionId = String.fromEnvironment('REPORTS_COLLECTIONID');
const usersCollectionId = String.fromEnvironment('USERS_COLLECTIONID');

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

  // Use environment variables from above

  Future<void> _checkProfileStatus() async {
    try {
      // You will need to initialize your Appwrite client, account, and databases here using the above constants.
      final client = Client()
        ..setEndpoint(appwriteEndpoint)
        ..setProject(projectId)
        ..setSelfSigned(status: true)
        ..setDevKey(appwriteDevKey);

      final account = Account(client);
      final databases = Databases(client);

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
