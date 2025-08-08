// lib/services/push_notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/appwrite/appwrite.dart';



final Messaging appwriteMessaging = Messaging(client);

Future<void> setupPushNotifications(String userId) async {
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission();
  print('User granted permission: ${settings.authorizationStatus == AuthorizationStatus.authorized}');

  String? fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken == null) {
    print('Failed to get FCM token. Push notifications will be disabled.');
    return;
  }
  print('FCM Token received: $fcmToken');

  try {
    // You MUST replace this with your actual Provider ID
    final String appwriteProviderId = '6892706b000e722adf67';

    await appwriteMessaging.createSubscriber(
      topicId: fcmToken,
      subscriberId: appwriteProviderId,
      targetId: 'users_$userId',
    );
    print('SUCCESSFULLY REGISTERED DEVICE WITH APPWRITE MESSAGING FOR USER: $userId.');
  } catch (e) {
    print('FAILED TO REGISTER DEVICE WITH APPWRITE: $e');
  }
}