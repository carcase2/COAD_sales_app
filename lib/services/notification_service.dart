import 'dart:async';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// Navigation key to support navigation without context
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Cold start: [init] reads [FirebaseMessaging.getInitialMessage] once and stores the id here.
  /// [MainTabScreen] calls [handleInitialMessage] after login so detail opens reliably.
  static String? _pendingCallIdFromNotification;

  static Future<void> init() async {
    // 1. Initialize Firebase Messaging
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Set Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Cold start: read once as early as possible (after Firebase.initializeApp in main).
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      final id = _extractCallIdFromData(initial.data);
      if (id != null) {
        _pendingCallIdFromNotification = id;
      }
      if (kDebugMode) {
        print('[FCM] getInitialMessage data=${initial.data} → callId=$id');
      }
    }

    // 4. Setup Local Notifications (for foreground)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload != null && details.payload!.isNotEmpty) {
          _handleNotificationClick(details.payload);
        }
      },
    );

    // 5. Create Notification Channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 6. Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        final payload = _extractCallIdFromData(message.data) ?? '';
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          payload: payload.isEmpty ? null : payload,
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

    // 7. Background → user taps system notification (app still in memory)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final id = _extractCallIdFromData(message.data);
      if (kDebugMode) {
        print('[FCM] onMessageOpenedApp data=${message.data} → callId=$id');
      }
      if (id != null) {
        _navigateToCallDetail(id);
      }
    });
  }

  /// Called from [MainTabScreen] when the user is logged in and the navigator is mounted.
  static void handleInitialMessage() {
    final id = _pendingCallIdFromNotification;
    if (id == null || id.isEmpty) return;
    _navigateToCallDetail(id);
  }

  static String? _extractCallIdFromData(Map<String, dynamic> data) {
    const keys = ['call_id', 'callId', 'sales_call_id'];
    for (final k in keys) {
      if (!data.containsKey(k)) continue;
      final n = _normalizeCallId(data[k]);
      if (n != null) return n;
    }
    for (final e in data.entries) {
      if (e.key.toLowerCase() == 'call_id') {
        final n = _normalizeCallId(e.value);
        if (n != null) return n;
      }
    }
    return null;
  }

  static String? _normalizeCallId(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  static void _handleNotificationClick(String? raw) {
    final id = _normalizeCallId(raw);
    if (id == null) return;
    if (kDebugMode) {
      print('[FCM] local notification tap callId=$id');
    }
    _navigateToCallDetail(id);
  }

  static void _navigateToCallDetail(String id) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      try {
        final user = ProviderScope.containerOf(ctx).read(authControllerProvider);
        if (user == null) {
          _pendingCallIdFromNotification = id;
          return;
        }
      } catch (_) {
        _pendingCallIdFromNotification = id;
        return;
      }
    }
    _pushDetailRoute(id);
  }

  static void _pushDetailRoute(String id, {int attempt = 0}) {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      _pendingCallIdFromNotification = null;
      nav.push(
        MaterialPageRoute<void>(
          builder: (context) => SalesCallDetailScreen(id: id),
          settings: RouteSettings(name: 'SalesCallDetail/$id'),
        ),
      );
      return;
    }
    if (attempt < 30) {
      final ms = 30 + attempt * 25;
      Future<void>.delayed(Duration(milliseconds: ms), () => _pushDetailRoute(id, attempt: attempt + 1));
    } else if (kDebugMode) {
      print('[FCM] NavigatorState still null after retries; keeping pending call id');
      _pendingCallIdFromNotification = id;
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

    try {
      await Supabase.instance.client.from('users').update({'fcm_token': token}).eq('id', userId);

      if (kDebugMode) {
        print("[NotificationService] FCM Token updated successfully for user $userId");
      }
    } catch (e) {
      if (kDebugMode) {
        print("[NotificationService] ERROR updating FCM token in Supabase: $e");
      }
    }
  }

  static void listenToTokenRefresh(String userId) {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      if (kDebugMode) {
        print("[NotificationService] FCM Token refreshed: $token");
      }
      try {
        await Supabase.instance.client.from('users').update({'fcm_token': token}).eq('id', userId);
        if (kDebugMode) {
          print("[NotificationService] Refreshed FCM Token synced with Supabase");
        }
      } catch (e) {
        if (kDebugMode) {
          print("[NotificationService] ERROR syncing refreshed token: $e");
        }
      }
    });
  }
}
