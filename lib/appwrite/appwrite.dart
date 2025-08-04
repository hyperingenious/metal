import 'package:appwrite/appwrite.dart';

// Environment variables
const appwriteEndpoint = String.fromEnvironment('APPWRITE_ENDPOINT');
const projectId = String.fromEnvironment('PROJECT_ID');
const databaseId = String.fromEnvironment('DATABASE_ID');
const storageBucketId = String.fromEnvironment('STORAGE_BUCKETID');
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

final client = Client()
  ..setEndpoint(appwriteEndpoint)
  ..setProject(projectId)
  ..setSelfSigned(status: true);

final account = Account(client);
final databases = Databases(client);
final storage = Storage(client);
final realtime = Realtime(client);
