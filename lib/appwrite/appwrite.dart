import 'package:appwrite/appwrite.dart';
import '../services/config_service.dart';

// Environment variables
final appwriteEndpoint = ConfigService().get('APPWRITE_ENDPOINT');
final projectId = ConfigService().get('PROJECT_ID') ?? "696d271a00370d723a6c";
final databaseId = ConfigService().get('DATABASE_ID') ?? "685a90fa0009384c5189";
final storageBucketId = ConfigService().get('STORAGE_BUCKETID') ?? "686c230b002fb6f5149e";
final blockedCollectionId = ConfigService().get('BLOCKED_COLLECTIONID');
final completionStatusCollectionId = ConfigService().get(
  'COMPLETION_STATUS_COLLECTIONID',
);
final connectionsCollectionId = ConfigService().get('CONNECTIONS_COLLECTIONID');
final hasShownCollectionId = ConfigService().get('HAS_SHOWN_COLLECTIONID');
final hobbiesCollectionId = ConfigService().get('HOBBIES_COLLECTIONID');
final imageCollectionId = ConfigService().get('IMAGE_COLLECTIONID') ?? "685aa0ef00090023c8a3";
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
final usersCollectionId = ConfigService().get('USERS_COLLECTIONID') ?? "68616ecc00163ed41e57";

final client = Client()
  ..setEndpoint("https://sgp.cloud.appwrite.io/v1")
  ..setProject("696d271a00370d723a6c")
  ..setSelfSigned(status: true);

final account = Account(client);
final databases = Databases(client);
final storage = Storage(client);
final realtime = Realtime(client);