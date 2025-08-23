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
import 'package:lushh/screens/profile_completion/isAnsweredAllQuestionsScreen.dart';
import 'package:lushh/services/config_service.dart';

// Import all IDs using ConfigService
final appwriteEndpoint = ConfigService().get('APPWRITE_ENDPOINT');
final projectId = ConfigService().get('PROJECT_ID');
final databaseId = ConfigService().get('DATABASE_ID');
final biodataCollectionId = ConfigService().get('BIODATA_COLLECTIONID');
final blockedCollectionId = ConfigService().get('BLOCKED_COLLECTIONID');
final completionStatusCollectionId = ConfigService().get(
  'COMPLETION_STATUS_COLLECTIONID',
);
final connectionsCollectionId = ConfigService().get('CONNECTIONS_COLLECTIONID');
final hasShownCollectionId = ConfigService().get('HAS_SHOWN_COLLECTIONID');
final hobbiesCollectionId = ConfigService().get('HOBBIES_COLLECTIONID');
final imageCollectionId = ConfigService().get('IMAGE_COLLECTIONID');
final locationCollectionId = ConfigService().get('LOCATION_COLLECTIONID');
final messageInboxCollectionId = ConfigService().get(
  'MESSAGE_INBOX_COLLECTIONID',
);
final messagesCollectionId = ConfigService().get('MESSAGES_COLLECTIONID');
final notificationsCollectionId = ConfigService().get(
  'NOTIFICATIONS_COLLECTIONID',
);
final preferenceCollectionId = ConfigService().get('PREFERENCE_COLLECTIONID');
final reportsCollectionId = ConfigService().get('REPORTS_COLLECTIONID');
final usersCollectionId = ConfigService().get('USERS_COLLECTIONID');

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

  Future<void> _checkProfileStatus() async {
    try {
      // Load configuration first
      if (!ConfigService().variableStatus) {
        await ConfigService().loadBootstrapConfig();
      }

      // Now get the configuration values after they've been loaded
      final appwriteEndpoint = ConfigService().get('APPWRITE_ENDPOINT');
      final projectId = ConfigService().get('PROJECT_ID');
      final databaseId = ConfigService().get('DATABASE_ID');
      final completionStatusCollectionId = ConfigService().get(
        'COMPLETION_STATUS_COLLECTIONID',
      );

      // Validate that required configuration values are present
      if (
          appwriteEndpoint == null ||
          projectId == null ||
          databaseId == null ||
          completionStatusCollectionId == null) {
        throw Exception('Required configuration values are missing');
      }

      // Initialize Appwrite client with the loaded configuration
      final client = Client()
        ..setEndpoint(appwriteEndpoint)
        ..setProject(projectId)
        ..setSelfSigned(status: true);

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

      final isAnsweredQuestions =
          completionDocument.data['isAnsweredQuestions'] as bool? ?? false;

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
      } else if (isAnsweredQuestions == false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => IsAnsweredAllQuestionsScreen()),
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
    } catch (e) {
      // Handle other errors including configuration errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Configuration error: ${e.toString()}')),
      );
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
