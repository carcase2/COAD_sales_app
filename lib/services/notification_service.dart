import 'dart:async';
import 'dart:convert';
import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/services/app_update_service.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/home/home_navigation.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Background isolate용 (메인 isolate의 [_localNotifications]와 별도).
@pragma('vm:entry-point')
final FlutterLocalNotificationsPlugin _backgroundLocalNotifications =
    FlutterLocalNotificationsPlugin();

/// 로컬 알림 탭(백그라운드 isolate) → 메인 앱으로 payload 전달.
@pragma('vm:entry-point')
void _onBackgroundLocalNotificationTap(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  unawaited(NotificationService.persistNotificationPayload(payload));
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('[FCM] background message: ${message.messageId} data=${message.data}');
  }
  try {
    await NotificationService.showRemoteMessageNotification(
      message,
      plugin: _backgroundLocalNotifications,
      initializePlugin: true,
    );
  } catch (e, st) {
    if (kDebugMode) {
      print('[FCM] background handler failed: $e\n$st');
    }
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const String _androidChannelId = 'high_importance_channel';
  static const String _androidChannelName = 'High Importance Notifications';
  static const String _androidChannelDescription = 'This channel is used for important notifications.';

  /// Navigation key to support navigation without context
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Cold start / 로그인 대기 payload. [MainTabScreen]에서 [handleInitialMessage]로 처리.
  static Map<String, dynamic>? _pendingMessageData;

  /// [init] 시점 로컬 알림 cold-start payload (navigator 준비 전에는 큐만).
  static String? _pendingLaunchPayload;

  static void _queuePendingData(Map<String, dynamic> data) {
    _pendingMessageData = data;
  }

  static Future<void> persistNotificationPayload(String payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.pendingNotificationPayload, payload);
    } catch (e) {
      if (kDebugMode) {
        print('[FCM] persistNotificationPayload failed: $e');
      }
    }
  }

  static Future<void> _consumeStoredNotificationPayload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(StorageKeys.pendingNotificationPayload);
      if (raw == null || raw.isEmpty) return;
      await prefs.remove(StorageKeys.pendingNotificationPayload);
      _handleNotificationClick(raw);
    } catch (e) {
      if (kDebugMode) {
        print('[FCM] consumeStoredNotificationPayload failed: $e');
      }
    }
  }

  static Future<void> init() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload != null && details.payload!.isNotEmpty) {
          _scheduleNotificationHandling(() => _handleNotificationClick(details.payload));
        }
      },
      onDidReceiveBackgroundNotificationResponse: _onBackgroundLocalNotificationTap,
    );

    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _pendingLaunchPayload = launchPayload;
    }

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDescription,
      importance: Importance.max,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.requestNotificationsPermission();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      unawaited(showRemoteMessageNotification(message, plugin: _localNotifications));
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('[FCM] onMessageOpenedApp data=${message.data}');
      }
      _scheduleNotificationHandling(
        () => _handleMessageData(Map<String, dynamic>.from(message.data)),
      );
    });
  }

  /// Called from [MainTabScreen] when the user is logged in and the navigator is mounted.
  static Future<void> handleInitialMessage() async {
    await _consumeStoredNotificationPayload();

    final launchPayload = _pendingLaunchPayload;
    if (launchPayload != null && launchPayload.isNotEmpty) {
      _pendingLaunchPayload = null;
      _scheduleNotificationHandling(() => _handleNotificationClick(launchPayload));
    }

    if (_pendingMessageData != null) {
      _scheduleNotificationHandling(() => _handleMessageData(_pendingMessageData!));
    }

    for (var attempt = 0; attempt < 8; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      }
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial == null || initial.data.isEmpty) continue;
      if (kDebugMode) {
        print('[FCM] getInitialMessage (attempt $attempt) data=${initial.data}');
      }
      _scheduleNotificationHandling(
        () => _handleMessageData(Map<String, dynamic>.from(initial.data)),
      );
      return;
    }

    retryPendingNavigation();
  }

  /// 앱 재개·navigator 준비 후 대기 중인 접수 상세 이동 재시도.
  static void retryPendingNavigation() {
    unawaited(_consumeStoredNotificationPayload());
    final data = _pendingMessageData;
    if (data == null) return;
    _scheduleNotificationHandling(() => _handleMessageData(data));
  }

  /// navigator·로그인 준비 후 알림 탭 처리 (cold start / 백그라운드 탭).
  static void _scheduleNotificationHandling(VoidCallback handle) {
    void run() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handle();
      });
    }

    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      run();
      return;
    }
    run();
    Future<void>.delayed(const Duration(milliseconds: 400), run);
    Future<void>.delayed(const Duration(milliseconds: 900), run);
  }

  /// FCM data를 로컬 알림으로 표시. 탭 시 [payload]로 상세 화면 이동.
  static Future<void> showRemoteMessageNotification(
    RemoteMessage message, {
    required FlutterLocalNotificationsPlugin plugin,
    bool initializePlugin = false,
  }) async {
    final data = Map<String, dynamic>.from(message.data);
    final payload = _buildLocalPayload(data);
    if (payload == null) return;

    final titleBody = _titleAndBodyFromMessage(message);
    final title = titleBody.$1;
    final body = titleBody.$2;
    if (title.isEmpty && body.isEmpty) return;

    if (initializePlugin) {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await plugin.initialize(
        settings: const InitializationSettings(android: androidSettings),
        onDidReceiveBackgroundNotificationResponse: _onBackgroundLocalNotificationTap,
      );
    }

    final androidPlugin =
        plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDescription,
        importance: Importance.max,
      );
      await androidPlugin.createNotificationChannel(channel);
    }

    final callId = _extractCallIdFromData(data);
    await plugin.show(
      id: callId?.hashCode ?? message.hashCode,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
          tag: callId,
        ),
      ),
    );
  }

  static (String, String) _titleAndBodyFromMessage(RemoteMessage message) {
    final data = message.data;
    final fromDataTitle = (data['title'] ?? '').toString().trim();
    final fromDataBody = (data['body'] ?? '').toString().trim();
    final title = message.notification?.title ?? fromDataTitle;
    final body = message.notification?.body ?? fromDataBody;
    return (title, body);
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
    if (_isIssuanceCompletedNotification(data)) {
      _openIssuanceCompleted(data);
      return;
    }
    final id = _extractCallIdFromData(data);
    if (id != null) {
      _navigateToCallDetail(id);
      return;
    }
    if (kDebugMode) {
      print('[FCM] tap ignored: no call_id in data=$data');
    }
  }

  static bool _isIssuanceCompletedNotification(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['notification_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final action = (data['action'] ?? '').toString().trim().toLowerCase();
    return type == 'issuance_completed' || action == 'open_issuance_completed';
  }

  static IssuanceDomain _parseIssuanceDomain(Object? raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    if (value == 'performancebond' ||
        value == 'performance_bond' ||
        value == 'performance-bond' ||
        value == 'bond') {
      return IssuanceDomain.performanceBond;
    }
    return IssuanceDomain.taxInvoice;
  }

  static void _openIssuanceCompleted(Map<String, dynamic> data) {
    final domain = _parseIssuanceDomain(data['issuance_domain'] ?? data['domain']);
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      _queuePendingData({
        'type': 'issuance_completed',
        'issuance_domain': domain.name,
        'show_completed': true,
      });
      return;
    }
    try {
      final container = ProviderScope.containerOf(ctx);
      final user = container.read(authControllerProvider);
      if (user == null) {
        _queuePendingData({
          'type': 'issuance_completed',
          'issuance_domain': domain.name,
          'show_completed': true,
        });
        return;
      }
      container.read(pendingIssuanceLaunchProvider.notifier).state = (
        domain: domain,
        showCompleted: true,
      );
    } catch (_) {
      _queuePendingData({
        'type': 'issuance_completed',
        'issuance_domain': domain.name,
        'show_completed': true,
      });
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
    _queuePendingData({'type': 'sales_call', 'call_id': id});
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      try {
        final user = ProviderScope.containerOf(ctx).read(authControllerProvider);
        if (user == null) {
          return;
        }
      } catch (_) {
        return;
      }
    }
    _pushDetailRoute(id);
  }

  static void _invalidateHomeSalesCaches() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    try {
      invalidateHomeSalesCaches(ProviderScope.containerOf(ctx).invalidate);
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
      if (kDebugMode) {
        print('[FCM] navigated to SalesCallDetail/$id');
      }
      return;
    }
    if (attempt < 60) {
      final ms = 50 + attempt * 40;
      Future<void>.delayed(Duration(milliseconds: ms), () => _pushDetailRoute(id, attempt: attempt + 1));
    } else if (kDebugMode) {
      print('[FCM] NavigatorState still null after retries; keeping pending payload');
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

  static Future<void> showIssuanceCompletedAlert({
    required String title,
    required String body,
    required IssuanceDomain domain,
    String? masterId,
    String? issueId,
  }) async {
    final payload = jsonEncode({
      'type': 'issuance_completed',
      'issuance_domain': domain.name,
      'show_completed': true,
      'master_id': masterId,
      'issue_id': issueId,
    });
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> showSalesCallRegisteredAlert({
    required String callId,
    required String customerName,
    required String phone,
    String? assigneeName,
  }) async {
    final name = customerName.trim().isEmpty ? '고객' : customerName.trim();
    final phoneText = phone.trim().isEmpty ? '' : ' ($phone)';
    final rawAssignee = (assigneeName ?? '').trim();
    final assignee = rawAssignee.isEmpty ? '미지정' : rawAssignee;
    final payload = jsonEncode({
      'type': 'sales_call',
      'call_id': callId,
    });
    await _localNotifications.show(
      id: callId.hashCode,
      title: '[$assignee] 새 통화 등록 완료',
      body: '$name$phoneText 접수가 등록되었습니다.',
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          tag: callId,
        ),
      ),
    );
  }
}
