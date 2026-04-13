import 'dart:async';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  // Navigation key to support navigation without context
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> init() async {
    // 1. Initialize Firebase Messaging
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Set Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Setup Local Notifications (for foreground)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle foreground notification tap
        if (details.payload != null) {
          _handleNotificationClick(details.payload);
        }
      },
    );

    // 4. Create Notification Channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 5. Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          payload: message.data['call_id'], // Pass call_id as payload
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.max,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(notification.body ?? ''),
              icon: android.smallIcon,
            ),
          ),
        );
      }
    });

    // 6. Handle click when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message.data['call_id']);
    });

    // 7. Initial message check will be handled in UI layer to ensure navigator is ready
//    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
//    if (initialMessage != null) {
//      _handleNotificationClick(initialMessage.data['call_id']);
//    }
  }

  static Future<void> handleInitialMessage() async {
    // 1. Give some time for the app and FCM service to settle (vital for Cold Start)
    await Future.delayed(const Duration(milliseconds: 1000));
    
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print("[ColdStart] Handling initial notification message: ${initialMessage.data}");
      }
      _handleNotificationClick(initialMessage.data['call_id']);
    }
  }

  static void _handleNotificationClick(String? callId, {int retryCount = 0}) {
    if (callId == null || callId.isEmpty) return;
    
    if (kDebugMode) {
      print("Notification Click Handler (Retry: $retryCount) - callId: $callId");
    }

    final state = navigatorKey.currentState;
    if (state != null) {
      state.push(
        MaterialPageRoute(
          builder: (context) => SalesCallDetailScreen(id: callId),
        ),
      );
    } else {
      // If navigator is not ready, retry after a short delay (up to 3 times)
      if (retryCount < 3) {
        if (kDebugMode) {
          print("NavigatorState is null, retrying in 800ms...");
        }
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleNotificationClick(callId, retryCount: retryCount + 1);
        });
      } else {
        if (kDebugMode) {
          print("ERROR: NavigatorState is still null after 3 retries. Deep linking failed.");
        }
      }
    }
  }

  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      if (kDebugMode) {
        print("Error getting FCM token: $e");
      }
      return null;
    }
  }

  static Future<void> updateTokenInSupabase(String userId) async {
    final token = await getToken();
    if (token == null) return;

    await Supabase.instance.client
        .from('users')
        .update({'fcm_token': token})
        .eq('id', userId);
    
    if (kDebugMode) {
      print("FCM Token updated for user $userId: $token");
    }
  }

  static void listenToTokenRefresh(String userId) {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token})
          .eq('id', userId);
    });
  }
}
