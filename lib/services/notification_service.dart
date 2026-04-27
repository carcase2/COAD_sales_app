import 'dart:async';
import 'dart:convert';
import 'package:coad_customer_calls/services/app_update_service.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
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

  /// Cold start payload cache. [MainTabScreen] calls [handleInitialMessage] after login.
  static Map<String, dynamic>? _pendingMessageData;

  static void _queuePendingData(Map<String, dynamic> data) {
    _pendingMessageData = data;
  }

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
      _pendingMessageData = Map<String, dynamic>.from(initial.data);
      if (kDebugMode) {
        print('[FCM] getInitialMessage data=${initial.data}');
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

    // 앱이 "로컬 알림 탭"으로 시작된 경우(종료 상태)도 누락 없이 처리.
    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _handleNotificationClick(launchPayload);
    }

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
        final payload = _buildLocalPayload(message.data);
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          payload: payload,
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
      final data = Map<String, dynamic>.from(message.data);
      if (kDebugMode) {
        print('[FCM] onMessageOpenedApp data=${message.data}');
      }
      _handleMessageData(data);
    });
  }

  /// Called from [MainTabScreen] when the user is logged in and the navigator is mounted.
  static void handleInitialMessage() {
    final data = _pendingMessageData;
    if (data == null) return;
    _pendingMessageData = null;
    _handleMessageData(data);
  }

  static String? _buildLocalPayload(Map<String, dynamic> data) {
    if (_isAppUpdateNotification(data)) {
      final storeUrl = (data['store_url'] ?? '').toString().trim();
      return jsonEncode({
        'type': 'app_update',
        'store_url': storeUrl,
      });
    }
    final callId = _extractCallIdFromData(data);
    if (callId == null) return null;
    return jsonEncode({
      'type': 'sales_call',
      'call_id': callId,
    });
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
    // 일부 전송 경로는 data가 JSON 문자열로 한 단계 더 감싸질 수 있음.
    final rawNested = data['data'];
    if (rawNested is String && rawNested.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawNested);
        if (decoded is Map<String, dynamic>) {
          return _extractCallIdFromData(decoded);
        }
        if (decoded is Map) {
          return _extractCallIdFromData(
            decoded.map((key, value) => MapEntry('$key', value)),
          );
        }
      } catch (_) {
        // ignore malformed nested data
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

  static void _handleNotificationClick(String? rawPayload) {
    if (rawPayload == null || rawPayload.isEmpty) return;
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) {
        _handleMessageData(decoded);
        return;
      }
      if (decoded is Map) {
        _handleMessageData(decoded.map((key, value) => MapEntry('$key', value)));
        return;
      }
    } catch (_) {
      // Legacy payload compatibility: raw call_id string.
    }
    final id = _normalizeCallId(rawPayload);
    if (id == null) return;
    if (kDebugMode) {
      print('[FCM] local notification tap legacy callId=$id');
    }
    _navigateToCallDetail(id);
  }

  static void _handleMessageData(Map<String, dynamic> data) {
    if (_isAppUpdateNotification(data)) {
      _openUpdateFlow(data);
      return;
    }
    final id = _extractCallIdFromData(data);
    if (id != null) {
      _navigateToCallDetail(id);
    }
  }

  static bool _isAppUpdateNotification(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['notification_type'] ?? '').toString().trim().toLowerCase();
    final action = (data['action'] ?? '').toString().trim().toLowerCase();
    return type == 'app_update' || action == 'open_update';
  }

  static Future<void> _openUpdateFlow(Map<String, dynamic> data) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      _queuePendingData(data);
      return;
    }
    try {
      final user = ProviderScope.containerOf(ctx).read(authControllerProvider);
      if (user == null) {
        _queuePendingData(data);
        return;
      }
    } catch (_) {
      _queuePendingData(data);
      return;
    }
    final storeUrl = (data['store_url'] ?? '').toString().trim();
    await AppUpdateService.checkAndUpdateIfNeeded(
      ctx,
      forceRecheck: true,
      showUpToDateMessage: true,
      preferredStoreUrl: storeUrl.isEmpty ? null : storeUrl,
    );
  }

  static void _navigateToCallDetail(String id) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      try {
        final user = ProviderScope.containerOf(ctx).read(authControllerProvider);
        if (user == null) {
          _queuePendingData({'type': 'sales_call', 'call_id': id});
          return;
        }
      } catch (_) {
        _queuePendingData({'type': 'sales_call', 'call_id': id});
        return;
      }
    }
    _pushDetailRoute(id);
  }

  /// 푸시로 상세 진입 시 홈·상담현황에 쓰이는 목록/통계가 이전 캐시를 유지하는 문제 방지
  /// ([SalesCallCreateScreen] 접수 성공 시와 동일하게 무효화)
  static void _invalidateHomeSalesCaches() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    try {
      final container = ProviderScope.containerOf(ctx);
      container.invalidate(todayStatsProvider);
      container.invalidate(todayCallsContentProvider);
      container.invalidate(todayFollowOverviewProvider);
      container.invalidate(todayIncompleteOverviewProvider);
      container.invalidate(rankingCallsProvider);
    } catch (_) {
      // ProviderScope 미연결(테스트 등) 시 무시
    }
  }

  static void _pushDetailRoute(String id, {int attempt = 0}) {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      _pendingMessageData = null;
      nav.push(
        MaterialPageRoute<void>(
          builder: (context) => SalesCallDetailScreen(id: id),
          settings: RouteSettings(name: 'SalesCallDetail/$id'),
        ),
      );
      _invalidateHomeSalesCaches();
      return;
    }
    if (attempt < 30) {
      final ms = 30 + attempt * 25;
      Future<void>.delayed(Duration(milliseconds: ms), () => _pushDetailRoute(id, attempt: attempt + 1));
    } else {
      if (kDebugMode) {
        print('[FCM] NavigatorState still null after retries; keeping pending payload');
      }
      _queuePendingData({'type': 'sales_call', 'call_id': id});
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
