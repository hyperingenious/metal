// auth_gate.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';

// This file in your app should already export configured `client`, `account`, `databases`
import 'package:lushh/appwrite/appwrite.dart';

import 'home_screen.dart';
import 'phone_input_screen.dart';
import 'profile_completion/profile_completion_router.dart';
import 'settings_screen.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NEW: Shared preferences import

// Import IDs from ConfigService
import 'package:lushh/services/config_service.dart';

final projectId = ConfigService().get('PROJECT_ID') as String;
final databaseId = ConfigService().get('DATABASE_ID') as String;
final completionStatusCollectionId =
ConfigService().get('COMPLETION_STATUS_COLLECTIONID') as String;

// Use the existing Appwrite `client` from your appwrite.dart
late final Messaging _messaging = Messaging(client);
final _prefsKey = 'appwrite_push_target_id';

class AuthGate extends StatefulWidget {
  final String? requestedRoute;
  const AuthGate({super.key, this.requestedRoute});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool isChecking = true;
  bool isLoggedIn = false;
  bool isAllCompleted = false;
  bool isAnsweredQuestions = false;

  @override
  void initState() {
    super.initState();
    checkLogin();

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleNotification(message.data);
    });

    // Notification tap (app in background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotification(message.data);
    });
  }

  Future<void> checkLogin() async {
    try {
      final user = await account.get();

      if (!ConfigService().variableStatus && user != null) {
        await ConfigService().loadBootstrapConfig();
      }

      final userId = user.$id;

      final doc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: completionStatusCollectionId,
        queries: [Query.equal('user', userId)],
      );

      setState(() {
        isLoggedIn = true;
        isChecking = false;
        isAllCompleted = doc.documents[0].data['isAllCompleted'] ?? false;
        isAnsweredQuestions = doc.documents[0].data['isAnsweredQuestions'] ?? false;
      });

      _setupPushNotifications(userId);
    } catch (e) {
      setState(() {
        isLoggedIn = false;
        isChecking = false;
      });
    }
  }

  /// Gets a stored target ID or creates a new one and persists it.
  Future<String?> _getOrCreatePushTarget(String fcmToken) async {
    final prefs = await SharedPreferences.getInstance();
    String? storedTargetId = prefs.getString(_prefsKey);

    if (storedTargetId != null) {
      debugPrint('Found existing push target ID: $storedTargetId');
      return storedTargetId;
    }

    try {
      const String appwriteProviderId = '6892706b000e722adf67';
      final newTargetId = ID.unique(); // A new, valid ID

      final createdTarget = await account.createPushTarget(
        targetId: newTargetId,
        identifier: fcmToken,
        providerId: appwriteProviderId,
      );

      await prefs.setString(_prefsKey, createdTarget.$id);
      debugPrint('🎉 Created new push target with ID: ${createdTarget.$id}');
      return createdTarget.$id;

    } on AppwriteException catch (e) {
      if (e.code == 409) { // 409 Conflict: target already exists
        debugPrint('🎯 Target with a similar ID already exists. Not creating a new one.');
        // In a real app, you might try to find the existing target and update it.
        // For now, we'll just return null and let the subscription fail gracefully.
        return null;
      }
      rethrow;
    }
  }


  /// Registers this device as a push **target** in Appwrite and subscribes it to a per-user topic.
  /// Improved push notification setup
  Future<void> _setupPushNotifications(String userId) async {
    debugPrint('✅ Push notification setup started for user: $userId');

    // Request permission
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ Push notification permission denied');
      return;
    }

    // Get FCM token
    final String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) {
      debugPrint('❌ FCM token is null; cannot register push target.');
      return;
    }
    debugPrint('🔔 FCM token received: $fcmToken');

    final prefs = await SharedPreferences.getInstance();
    const String appwriteProviderId = '6892706b000e722adf67';
    const String topicId = 'global_notifications';

    String? targetId = prefs.getString('push_target_id_$userId'); // User-specific key
    String? subscriberId = prefs.getString('push_subscriber_id_$userId'); // User-specific key

    try {
      // Step 1: Try to get or create push target
      if (targetId != null) {
        debugPrint('🎯 Found existing target ID: $targetId');

        // Try to update the existing target with new FCM token
        try {
          await account.updatePushTarget(
            targetId: targetId,
            identifier: fcmToken,
          );
          debugPrint('✅ Push target updated with latest FCM token');
        } on AppwriteException catch (e) {
          if (e.code == 404) {
            // Target doesn't exist anymore, clear and recreate
            debugPrint('⚠️ Target not found, will create new one');
            targetId = null;
            subscriberId = null; // Also clear subscriber
            await prefs.remove('push_target_id_$userId');
            await prefs.remove('push_subscriber_id_$userId');
          } else {
            debugPrint('❌ Failed to update target: ${e.message}');
            throw e;
          }
        }
      }

      // Step 2: Create new target if needed
      if (targetId == null) {
        debugPrint('📤 Creating new push target...');

        try {
          final createdTarget = await account.createPushTarget(
            targetId: ID.unique(),
            identifier: fcmToken,
            providerId: appwriteProviderId,
          );

          targetId = createdTarget.$id;
          await prefs.setString('push_target_id_$userId', targetId);
          debugPrint('🎉 Created new push target: $targetId');

          // Force new subscription since we have a new target
          subscriberId = null;
          await prefs.remove('push_subscriber_id_$userId');

        } on AppwriteException catch (e) {
          debugPrint('❌ Failed to create push target: ${e.message}');
          return;
        }
      }

      // Step 3: Subscribe to topic if not already subscribed
      if (subscriberId == null && targetId != null) {
        debugPrint('➕ Subscribing to topic: $topicId');

        try {
          final newSubscriber = await _messaging.createSubscriber(
            topicId: topicId,
            subscriberId: ID.unique(),
            targetId: targetId,
          );

          subscriberId = newSubscriber.$id;
          await prefs.setString('push_subscriber_id_$userId', subscriberId);
          debugPrint('🎉 Subscribed to topic successfully! Subscriber ID: $subscriberId');

        } on AppwriteException catch (e) {
          if (e.code == 409) {
            // Already subscribed
            debugPrint('✨ Target already subscribed to topic');
          } else {
            debugPrint('❌ Failed to subscribe to topic: ${e.message}');
          }
        }
      } else {
        debugPrint('✨ Already subscribed to topic. Subscriber ID: $subscriberId');
      }

      // Step 4: Setup token refresh listener
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 FCM token refreshed!');

        try {
          final savedTargetId = prefs.getString('push_target_id_$userId');
          if (savedTargetId != null) {
            await account.updatePushTarget(
              targetId: savedTargetId,
              identifier: newToken,
            );
            debugPrint('✅ Updated push target with refreshed token');
          }
        } catch (e) {
          debugPrint('❌ Failed to update push target on token refresh: $e');
        }
      });

      debugPrint('✅ Push notification setup completed successfully!');

    } catch (e, st) {
      debugPrint('❌ Unexpected error in push setup: $e');
      debugPrint('$st');
    }
  }

  // Also add this method to verify subscription status
  Future<void> verifyPushSetup(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final targetId = prefs.getString('push_target_id_$userId');
    final subscriberId = prefs.getString('push_subscriber_id_$userId');

    debugPrint('🔍 Verifying push setup:');
    debugPrint('   Target ID: $targetId');
    debugPrint('   Subscriber ID: $subscriberId');

    if (targetId == null || subscriberId == null) {
      debugPrint('⚠️ Push setup incomplete, reinitializing...');
      await _setupPushNotifications(userId);
    }
  }

  // Handle custom data payloads
  void _handleNotification(Map<String, dynamic> data) {
    final notificationType = data['type'];
    if (notificationType == 'new_invitation') {
      debugPrint('New invitation from: ${data['senderName']}');
    } else if (notificationType == 'match') {
      debugPrint('Match! You can now chat with ${data['partnerName']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!isLoggedIn) {
      return const PhoneInputScreen();
    }

    if (!isAllCompleted || !isAnsweredQuestions) {
      return const ProfileCompletionRouter();
    }

    switch (widget.requestedRoute) {
      case '/main':
        return const HomeScreen();
      case '/settings':
        return const SettingsScreen();
      case '/profile_completion_router':
        return const ProfileCompletionRouter();
      default:
        return const HomeScreen();
    }
  }
}