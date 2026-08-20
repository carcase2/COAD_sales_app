import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/services/app_update_service.dart';
import 'package:coad_customer_calls/features/issuance/issuance_helpers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_list_kind.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_detail.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_providers.dart';
import 'package:coad_customer_calls/features/home/home_navigation.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_reception_list_screen.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
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
    print(
      '[FCM] background message: ${message.messageId} data=${message.data}',
    );
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
  static const String _androidChannelCallId = 'call_notifications';
  static const String _androidChannelIssuanceId = 'issuance_notifications';
  static const String _androidChannelScheduleId = 'schedule_notifications';
  static const String _androidChannelGeneralId = 'general_notifications';

  static const String _androidChannelCallName = '새 접수 알림';
  static const String _androidChannelIssuanceName = '발급요청 알림';
  static const String _androidChannelScheduleName = '일정 알림';
  static const String _androidChannelGeneralName = '일반 알림';

  static const String _androidChannelCallDesc = '새 통화 접수 알림';
  static const String _androidChannelIssuanceDesc = '세금계산서/이행증권 발급 알림';
  static const String _androidChannelScheduleDesc = '본사일반·대구지사 일정 변경 알림';
  static const String _androidChannelGeneralDesc = '앱 업데이트 등 일반 알림';

  /// Navigation key to support navigation without context
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Cold start / 로그인 대기 payload. [MainTabScreen]에서 [handleInitialMessage]로 처리.
  static Map<String, dynamic>? _pendingMessageData;

  /// [init] 시점 로컬 알림 cold-start payload (navigator 준비 전에는 큐만).
  static String? _pendingLaunchPayload;

  /// cold-start launch payload 1회 처리 후 재사용 방지(파일 선택 등 resume 시 오탐).
  static bool _coldStartLaunchHandled = false;

  /// 최신 알림 탭 처리만 유효하게 유지하기 위한 세대 토큰.
  static int _handlingGeneration = 0;

  /// 통화 상세 이동 요청의 최신성 보장을 위한 시퀀스.
  static int _callNavigationRequestSeq = 0;
  static int _asNavigationRequestSeq = 0;
  static int _issuanceNavigationRequestSeq = 0;
  static String? _lastOpenedIssuanceDetailKey;
  static DateTime? _lastOpenedIssuanceDetailAt;

  static void _log(String message) {
    debugPrint('[NotificationService] $message');
  }

  /// 알림 카테고리별 수신 설정 키 (설정 화면과 공유) — 기본값은 모두 켜짐.
  static const String prefKeyNotifyNewCall = 'notify_enabled_new_call_v1';
  static const String prefKeyNotifyIssuance = 'notify_enabled_issuance_v1';
  static const String prefKeyNotifyGeneralSchedule =
      'notify_enabled_general_schedule_v1';
  static const String prefKeyNotifyDaeguSchedule =
      'notify_enabled_daegu_schedule_v1';

  /// 사용자가 해당 카테고리 알림을 꺼두었으면 false.
  /// 앱 업데이트 등 분류 불가 알림은 항상 표시.
  static Future<bool> _isCategoryEnabled(Map<String, dynamic> data) async {
    String? key;
    if (_isIssuanceCompletedNotification(data) ||
        _isIssuanceRequestNotification(data)) {
      key = prefKeyNotifyIssuance;
    } else if (_isDaeguScheduleNotification(data)) {
      key = prefKeyNotifyDaeguSchedule;
    } else if (_isGeneralScheduleNotification(data)) {
      key = prefKeyNotifyGeneralSchedule;
    } else if (_extractCallIdFromData(data) != null) {
      key = prefKeyNotifyNewCall;
    }
    if (key == null) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? true;
    } catch (_) {
      return true;
    }
  }

  static String _androidChannelIdForData(Map<String, dynamic> data) {
    if (_isAsReceptionNotification(data)) {
      return _androidChannelCallId;
    }
    if (_isIssuanceCompletedNotification(data) ||
        _isIssuanceRequestNotification(data)) {
      return _androidChannelIssuanceId;
    }
    if (_isGeneralScheduleNotification(data) ||
        _isDaeguScheduleNotification(data)) {
      return _androidChannelScheduleId;
    }
    if (_extractCallIdFromData(data) != null) {
      return _androidChannelCallId;
    }
    return _androidChannelGeneralId;
  }

  static String _androidChannelNameForId(String channelId) {
    switch (channelId) {
      case _androidChannelCallId:
        return _androidChannelCallName;
      case _androidChannelIssuanceId:
        return _androidChannelIssuanceName;
      case _androidChannelScheduleId:
        return _androidChannelScheduleName;
      default:
        return _androidChannelGeneralName;
    }
  }

  static String _androidChannelDescForId(String channelId) {
    switch (channelId) {
      case _androidChannelCallId:
        return _androidChannelCallDesc;
      case _androidChannelIssuanceId:
        return _androidChannelIssuanceDesc;
      case _androidChannelScheduleId:
        return _androidChannelScheduleDesc;
      default:
        return _androidChannelGeneralDesc;
    }
  }

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

  static bool _shouldSuppressCallDetailNavigation() {
    final nav = navigatorKey.currentState;
    if (nav == null) return false;
    var onCreate = false;
    nav.popUntil((route) {
      if (route.settings.name == kSalesCallCreateRouteName) {
        onCreate = true;
      }
      return true;
    });
    return onCreate;
  }

  static Future<void> _consumeStoredNotificationPayload() async {
    if (_shouldSuppressCallDetailNavigation()) return;
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
    // 권한 다이얼로그가 첫 프레임을 막지 않도록 비동기로 요청 (결과는 로그만).
    unawaited(
      FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true)
          .then(
            (settings) =>
                _log('FCM permission status=${settings.authorizationStatus}'),
          )
          .catchError((Object e) => _log('FCM permission request failed: $e')),
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        _onForegroundLocalNotificationTap(details);
      },
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundLocalNotificationTap,
    );

    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _pendingLaunchPayload = launchPayload;
    }

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      const ids = <String>[
        _androidChannelCallId,
        _androidChannelIssuanceId,
        _androidChannelScheduleId,
        _androidChannelGeneralId,
      ];
      for (final id in ids) {
        await androidPlugin.createNotificationChannel(
          AndroidNotificationChannel(
            id,
            _androidChannelNameForId(id),
            description: _androidChannelDescForId(id),
            importance: Importance.max,
          ),
        );
      }
    }
    if (androidPlugin != null) {
      // Android 13+ 권한 다이얼로그도 시작 흐름을 막지 않게 비동기 처리.
      unawaited(
        androidPlugin.requestNotificationsPermission().catchError((Object e) {
          _log('Android notifications permission request failed: $e');
          return null;
        }),
      );
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _log(
        'onMessage id=${message.messageId} dataKeys=${message.data.keys.toList()}',
      );
      // iOS: APNs alert는 setForegroundNotificationPresentationOptions로 이미 표시됨.
      // 로컬 알림을 또 띄우면 포그라운드에서 배너가 중복된다.
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          message.notification != null) {
        return;
      }
      // Android 포그라운드: 알림만 표시하고, 상세 이동은 사용자 탭 시에만 처리합니다.
      // (수신 즉시 자동 이동하면 탭 이벤트·pending 재시도와 겹쳐 다른 접수로 가거나 이동이 무시됨)
      unawaited(
        showRemoteMessageNotification(message, plugin: _localNotifications),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _log('onMessageOpenedApp data=${message.data}');
      _scheduleNotificationHandling(
        () => _handleMessageData(Map<String, dynamic>.from(message.data)),
      );
    });
  }

  /// Called from [MainTabScreen] when the user is logged in and the navigator is mounted.
  static Future<void> handleInitialMessage() async {
    await _consumeStoredNotificationPayload();

    final launchPayload = _pendingLaunchPayload;
    if (!_coldStartLaunchHandled &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _coldStartLaunchHandled = true;
      _pendingLaunchPayload = null;
      _scheduleNotificationHandling(
        () => _handleNotificationClick(launchPayload),
      );
    }

    if (_pendingMessageData != null) {
      _scheduleNotificationHandling(
        () => _handleMessageData(_pendingMessageData!),
      );
    }

    for (var attempt = 0; attempt < 8; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      }
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial == null || initial.data.isEmpty) continue;
      if (kDebugMode) {
        print(
          '[FCM] getInitialMessage (attempt $attempt) data=${initial.data}',
        );
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
    if (_shouldSuppressCallDetailNavigation()) return;
    unawaited(_consumeStoredNotificationPayload());
    final data = _pendingMessageData;
    if (data == null) return;
    final type = (data['type'] ?? '').toString();
    if (type == 'issuance_request' || type == 'issuance_completed') return;
    _scheduleNotificationHandling(() => _handleMessageData(data));
  }

  /// 발급 알림 deep link 소비 완료 시 pending 제거.
  static void clearPendingIssuanceNavigation() {
    final type = (_pendingMessageData?['type'] ?? '').toString();
    if (type == 'issuance_request' || type == 'issuance_completed') {
      _pendingMessageData = null;
    }
    unawaited(_clearStoredNotificationPayload());
  }

  static Future<void> _clearStoredNotificationPayload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.pendingNotificationPayload);
    } catch (_) {}
  }

  static String _issuanceDetailKey({
    required IssuanceDomain domain,
    required String masterId,
    required String issueId,
  }) => '${domain.name}:$masterId:$issueId';

  static bool _recentlyOpenedIssuanceDetail({
    required IssuanceDomain domain,
    required String masterId,
    required String issueId,
  }) {
    final key = _issuanceDetailKey(
      domain: domain,
      masterId: masterId,
      issueId: issueId,
    );
    final openedAt = _lastOpenedIssuanceDetailAt;
    if (_lastOpenedIssuanceDetailKey != key || openedAt == null) return false;
    return DateTime.now().difference(openedAt) < const Duration(seconds: 8);
  }

  static void _markIssuanceDetailOpened({
    required IssuanceDomain domain,
    required String masterId,
    required String issueId,
  }) {
    _lastOpenedIssuanceDetailKey = _issuanceDetailKey(
      domain: domain,
      masterId: masterId,
      issueId: issueId,
    );
    _lastOpenedIssuanceDetailAt = DateTime.now();
  }

  /// Android 포그라운드 로컬 알림 탭.
  static void _onForegroundLocalNotificationTap(NotificationResponse details) {
    final payload = details.payload;
    if (payload == null || payload.isEmpty) return;
    if (kDebugMode) {
      print(
        '[FCM] local notification tap payload=$payload action=${details.actionId}',
      );
    }
    // Android 포그라운드 탭은 콜백 누락 가능성을 대비해 백업 저장
    // (실제 이동은 schedule 흐름 하나로만 처리해 경합을 줄임)
    unawaited(persistNotificationPayload(payload));
    _scheduleNotificationHandling(() => _handleNotificationClick(payload));
  }

  /// navigator·로그인 준비 후 알림 탭 처리 (cold start / 백그라운드 탭).
  static void _scheduleNotificationHandling(VoidCallback handle) {
    final generation = ++_handlingGeneration;

    void run() {
      if (generation != _handlingGeneration) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (generation != _handlingGeneration) return;
        handle();
      });
    }

    run();
    const retryDelaysMs = <int>[100, 300, 600, 1200];
    for (final ms in retryDelaysMs) {
      Future<void>.delayed(Duration(milliseconds: ms), run);
    }
  }

  /// 앱 재개 시 보류 payload 소비. launch details는 cold start에서만 1회 처리.
  static Future<void> onAppResumed() async {
    if (_shouldSuppressCallDetailNavigation()) return;
    await _consumeStoredNotificationPayload();
    retryPendingNavigation();
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

    if (!await _isCategoryEnabled(data)) {
      _log('notification suppressed by user setting: data=${data['type']}');
      return;
    }

    final titleBody = _titleAndBodyFromMessage(message);
    var title = titleBody.$1;
    var body = titleBody.$2;
    if (_isGeneralScheduleNotification(data) ||
        _isDaeguScheduleNotification(data)) {
      body = body.replaceAll(r'\n', '\n');
    }
    if (title.isEmpty && body.isEmpty) {
      if (_isDaeguScheduleNotification(data)) {
        title = (data['title'] ?? '[대구지사] 일정').toString();
        body = (data['body'] ?? '알림을 탭하면 대구지사 일정으로 이동합니다.').toString();
      } else if (_isGeneralScheduleNotification(data)) {
        title = (data['title'] ?? '[본사일반] 일정').toString();
        body = (data['body'] ?? '알림을 탭하면 본사일반 일정으로 이동합니다.').toString();
      } else if (_isAsReceptionNotification(data)) {
        title = '새 A/S 접수';
        body = '알림을 탭하면 접수 상세로 이동합니다.';
      } else {
        final callId = _extractCallIdFromData(data);
        if (callId != null) {
          title = '새 통화 접수';
          body = '알림을 탭하면 접수 상세로 이동합니다.';
        } else {
          return;
        }
      }
    }

    if (initializePlugin) {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundLocalNotificationTap,
      );
    }

    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final channelId = _androidChannelIdForData(data);
      final channel = AndroidNotificationChannel(
        channelId,
        _androidChannelNameForId(channelId),
        description: _androidChannelDescForId(channelId),
        importance: Importance.max,
      );
      await androidPlugin.createNotificationChannel(channel);
    }

    final callId = _extractCallIdFromData(data);
    final asId = _extractAsReceptionId(data);
    final notificationId = _isDaeguScheduleNotification(data)
        ? ('daegu_schedule:${data['action'] ?? 'open'}').hashCode & 0x7fffffff
        : _isGeneralScheduleNotification(data)
        ? ('general_schedule:${data['action'] ?? 'open'}').hashCode & 0x7fffffff
        : asId != null
        ? asId.hashCode & 0x7fffffff
        : _notificationIdFor(callId, message);
    final tag = _isDaeguScheduleNotification(data)
        ? 'daegu_schedule'
        : _isGeneralScheduleNotification(data)
        ? 'general_schedule'
        : asId ?? callId;
    _log(
      'showRemoteMessageNotification callId=$callId titleLen=${title.length} bodyLen=${body.length}',
    );
    await plugin.show(
      id: notificationId,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelIdForData(data),
          _androidChannelNameForId(_androidChannelIdForData(data)),
          channelDescription: _androidChannelDescForId(
            _androidChannelIdForData(data),
          ),
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
          tag: tag,
          autoCancel: true,
          category: AndroidNotificationCategory.message,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
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
      return jsonEncode({'type': 'app_update', 'store_url': storeUrl});
    }
    if (_isAsReceptionNotification(data)) {
      final asId = _extractAsReceptionId(data);
      if (asId == null) return null;
      return jsonEncode({'type': 'as_reception', 'as_id': asId});
    }
    if (_isIssuanceCompletedNotification(data)) {
      return jsonEncode(_issuancePayloadFromData(data, completed: true));
    }
    if (_isIssuanceRequestNotification(data)) {
      return jsonEncode(_issuancePayloadFromData(data, completed: false));
    }
    if (_isDaeguScheduleNotification(data)) {
      return jsonEncode({
        'type': 'daegu_schedule',
        'action': 'open_daegu_schedule',
      });
    }
    if (_isGeneralScheduleNotification(data)) {
      return jsonEncode({
        'type': 'general_schedule',
        'action': 'open_general_schedule',
      });
    }
    final callId = _extractCallIdFromData(data);
    if (callId == null) return null;
    return jsonEncode({'type': 'sales_call', 'call_id': callId});
  }

  static Map<String, dynamic> _issuancePayloadFromData(
    Map<String, dynamic> data, {
    required bool completed,
  }) {
    final domain = _parseIssuanceDomain(
      data['issuance_domain'] ?? data['domain'],
    );
    final masterId = (data['master_id'] ?? data['masterId'] ?? '').toString();
    final issueId = (data['issue_id'] ?? data['issueId'] ?? '').toString();
    return {
      'type': completed ? 'issuance_completed' : 'issuance_request',
      'issuance_domain': domain.name,
      'show_completed': completed,
      if (masterId.isNotEmpty) 'master_id': masterId,
      if (issueId.isNotEmpty) 'issue_id': issueId,
    };
  }

  static String? _extractCallIdFromData(Map<String, dynamic> data) {
    const keys = ['call_id', 'callId', 'sales_call_id', 'salesCallId', 'id'];
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
    final rawRecord = data['record'];
    if (rawRecord is Map<String, dynamic>) {
      return _extractCallIdFromData(rawRecord);
    }
    if (rawRecord is Map) {
      return _extractCallIdFromData(
        rawRecord.map((key, value) => MapEntry('$key', value)),
      );
    }
    return null;
  }

  static int _notificationIdFor(String? callId, RemoteMessage message) {
    if (callId != null && callId.isNotEmpty) {
      return callId.hashCode & 0x7fffffff;
    }
    return message.hashCode & 0x7fffffff;
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
        _handleMessageData(
          decoded.map((key, value) => MapEntry('$key', value)),
        );
        return;
      }
    } catch (_) {
      // Legacy payload compatibility: raw call_id string.
    }
    final id = _normalizeCallId(rawPayload);
    if (id == null) return;
    _log('local notification tap legacy callId=$id');
    _navigateToCallDetail(id);
  }

  static void _handleMessageData(Map<String, dynamic> data) {
    if (_isAppUpdateNotification(data)) {
      _openUpdateFlow(data);
      return;
    }
    if (_isAsReceptionNotification(data)) {
      final asId = _extractAsReceptionId(data);
      if (asId == null) {
        _log('tap ignored: as_reception without as_id data=$data');
        return;
      }
      _navigateToAsReceptionDetail(asId);
      return;
    }
    if (_isIssuanceCompletedNotification(data)) {
      _openIssuanceCompleted(data);
      return;
    }
    if (_isIssuanceRequestNotification(data)) {
      _openIssuanceRequest(data);
      return;
    }
    if (_isDaeguScheduleNotification(data)) {
      _openDaeguScheduleHub(data);
      return;
    }
    if (_isGeneralScheduleNotification(data)) {
      _openGeneralScheduleHub(data);
      return;
    }
    final id = _extractCallIdFromData(data);
    if (id != null) {
      _navigateToCallDetail(id);
      return;
    }
    _log('tap ignored: no call_id in data=$data');
  }

  static bool _isAsReceptionNotification(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['notification_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final action = (data['action'] ?? '').toString().trim().toLowerCase();
    return type == 'as_reception' ||
        type == 'as-reception' ||
        action == 'open_as_reception';
  }

  static String? _extractAsReceptionId(Map<String, dynamic> data) {
    const keys = ['as_id', 'asId', 'call_log_id', 'callLogId'];
    for (final k in keys) {
      if (!data.containsKey(k)) continue;
      final n = _normalizeCallId(data[k]);
      if (n != null) return n;
    }
    return null;
  }

  static bool _isIssuanceCompletedNotification(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['notification_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final action = (data['action'] ?? '').toString().trim().toLowerCase();
    return type == 'issuance_completed' || action == 'open_issuance_completed';
  }

  static bool _isIssuanceRequestNotification(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['notification_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final action = (data['action'] ?? '').toString().trim().toLowerCase();
    return type == 'issuance_request' || action == 'open_issuance_request';
  }

  static bool _isGeneralScheduleNotification(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['notification_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final action = (data['action'] ?? '').toString().trim().toLowerCase();
    return type == 'general_schedule' || action == 'open_general_schedule';
  }

  static bool _isDaeguScheduleNotification(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['notification_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final action = (data['action'] ?? '').toString().trim().toLowerCase();
    return type == 'daegu_schedule' || action == 'open_daegu_schedule';
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
    _openIssuanceHub(
      data,
      showCompleted: true,
      queueType: 'issuance_completed',
    );
  }

  static void _openIssuanceRequest(Map<String, dynamic> data) {
    _openIssuanceHub(data, showCompleted: false, queueType: 'issuance_request');
  }

  static void _openGeneralScheduleHub(Map<String, dynamic> data) {
    const payload = {
      'type': 'general_schedule',
      'action': 'open_general_schedule',
    };
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      _queuePendingData(payload);
      return;
    }
    try {
      final container = ProviderScope.containerOf(ctx);
      if (container.read(authControllerProvider) == null) {
        _queuePendingData(payload);
        return;
      }
      container.read(pendingGeneralScheduleLaunchProvider.notifier).state =
          true;
      _log('queue general schedule launch');
    } catch (_) {
      _queuePendingData(payload);
    }
  }

  static void _openDaeguScheduleHub(Map<String, dynamic> data) {
    const payload = {'type': 'daegu_schedule', 'action': 'open_daegu_schedule'};
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      _queuePendingData(payload);
      return;
    }
    try {
      final container = ProviderScope.containerOf(ctx);
      if (container.read(authControllerProvider) == null) {
        _queuePendingData(payload);
        return;
      }
      container.read(pendingDaeguScheduleLaunchProvider.notifier).state = true;
      _log('queue daegu schedule launch');
    } catch (_) {
      _queuePendingData(payload);
    }
  }

  static void clearPendingGeneralScheduleNavigation() {
    final type = (_pendingMessageData?['type'] ?? '').toString();
    if (type == 'general_schedule') {
      _pendingMessageData = null;
    }
    unawaited(_clearStoredNotificationPayload());
  }

  static void clearPendingDaeguScheduleNavigation() {
    final type = (_pendingMessageData?['type'] ?? '').toString();
    if (type == 'daegu_schedule') {
      _pendingMessageData = null;
    }
    unawaited(_clearStoredNotificationPayload());
  }

  static void _openIssuanceHub(
    Map<String, dynamic> data, {
    required bool showCompleted,
    required String queueType,
  }) {
    final domain = _parseIssuanceDomain(
      data['issuance_domain'] ?? data['domain'],
    );
    final masterId = (data['master_id'] ?? data['masterId'] ?? '').toString();
    final issueId = (data['issue_id'] ?? data['issueId'] ?? '').toString();
    final payload = {
      'type': queueType,
      'issuance_domain': domain.name,
      'show_completed': showCompleted,
      if (masterId.isNotEmpty) 'master_id': masterId,
      if (issueId.isNotEmpty) 'issue_id': issueId,
    };
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      _queuePendingData(payload);
      return;
    }
    try {
      final container = ProviderScope.containerOf(ctx);
      final user = container.read(authControllerProvider);
      if (user == null) {
        _queuePendingData(payload);
        return;
      }
      container.read(pendingIssuanceLaunchProvider.notifier).state = (
        domain: domain,
        showCompleted: showCompleted,
        masterId: masterId.isEmpty ? null : masterId,
        issueId: issueId.isEmpty ? null : issueId,
        listKind: showCompleted ? null : IssuanceListKind.request,
      );
      _log(
        'queue issuance launch domain=${domain.name} masterId=$masterId issueId=$issueId',
      );
    } catch (_) {
      _queuePendingData(payload);
      return;
    }
    if (masterId.isEmpty) return;
    if (_recentlyOpenedIssuanceDetail(
      domain: domain,
      masterId: masterId,
      issueId: issueId,
    )) {
      clearPendingIssuanceNavigation();
      return;
    }
    _scheduleIssuanceDetailNavigation(
      domain: domain,
      masterId: masterId,
      issueId: issueId,
    );
  }

  static void _scheduleIssuanceDetailNavigation({
    required IssuanceDomain domain,
    required String masterId,
    required String issueId,
  }) {
    if (_recentlyOpenedIssuanceDetail(
      domain: domain,
      masterId: masterId,
      issueId: issueId,
    )) {
      return;
    }
    final requestSeq = ++_issuanceNavigationRequestSeq;
    _navigateToIssuanceDetailInternal(
      domain: domain,
      masterId: masterId,
      issueId: issueId,
      authAttempt: 0,
      dataAttempt: 0,
      requestSeq: requestSeq,
    );
  }

  static void _navigateToIssuanceDetailInternal({
    required IssuanceDomain domain,
    required String masterId,
    required String issueId,
    required int authAttempt,
    required int dataAttempt,
    required int requestSeq,
  }) {
    if (requestSeq != _issuanceNavigationRequestSeq) return;

    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      try {
        final user = ProviderScope.containerOf(
          ctx,
        ).read(authControllerProvider);
        if (user == null) {
          if (authAttempt < 20) {
            final ms = 200 + authAttempt * 150;
            Future<void>.delayed(Duration(milliseconds: ms), () {
              _navigateToIssuanceDetailInternal(
                domain: domain,
                masterId: masterId,
                issueId: issueId,
                authAttempt: authAttempt + 1,
                dataAttempt: dataAttempt,
                requestSeq: requestSeq,
              );
            });
          }
          return;
        }
      } catch (_) {
        if (authAttempt < 20) {
          final ms = 200 + authAttempt * 150;
          Future<void>.delayed(Duration(milliseconds: ms), () {
            _navigateToIssuanceDetailInternal(
              domain: domain,
              masterId: masterId,
              issueId: issueId,
              authAttempt: authAttempt + 1,
              dataAttempt: dataAttempt,
              requestSeq: requestSeq,
            );
          });
        }
        return;
      }
    }

    unawaited(
      _openIssuanceDetailWithData(
        domain: domain,
        masterId: masterId,
        issueId: issueId,
        dataAttempt: dataAttempt,
        requestSeq: requestSeq,
      ),
    );
  }

  static Future<void> _openIssuanceDetailWithData({
    required IssuanceDomain domain,
    required String masterId,
    required String issueId,
    required int dataAttempt,
    required int requestSeq,
  }) async {
    if (requestSeq != _issuanceNavigationRequestSeq) return;

    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      if (dataAttempt < 20) {
        final ms = 100 + dataAttempt * 80;
        Future<void>.delayed(Duration(milliseconds: ms), () {
          _navigateToIssuanceDetailInternal(
            domain: domain,
            masterId: masterId,
            issueId: issueId,
            authAttempt: dataAttempt,
            dataAttempt: dataAttempt + 1,
            requestSeq: requestSeq,
          );
        });
      }
      return;
    }

    try {
      final container = ProviderScope.containerOf(ctx);
      if (dataAttempt == 0) {
        container.invalidate(issuanceAllRowsProvider(domain));
      }
      final rows = await container.read(issuanceAllRowsProvider(domain).future);
      final target = findIssuanceRowByIds(
        rows,
        masterId: masterId,
        issueId: issueId.isEmpty ? null : issueId,
      );
      if (target != null && ctx.mounted) {
        if (_recentlyOpenedIssuanceDetail(
          domain: domain,
          masterId: masterId,
          issueId: issueId,
        )) {
          clearPendingIssuanceNavigation();
          container.read(pendingIssuanceLaunchProvider.notifier).state = null;
          return;
        }
        _markIssuanceDetailOpened(
          domain: domain,
          masterId: masterId,
          issueId: issueId,
        );
        showIssuanceRequestDetail(ctx, target);
        clearPendingIssuanceNavigation();
        container.read(pendingIssuanceLaunchProvider.notifier).state = null;
        _log(
          'opened issuance detail domain=${domain.name} masterId=$masterId issueId=$issueId',
        );
        return;
      }
    } catch (e) {
      _log('issuance detail open failed attempt=$dataAttempt: $e');
    }

    if (dataAttempt < 6) {
      final ms = 300 + dataAttempt * 250;
      Future<void>.delayed(Duration(milliseconds: ms), () {
        _navigateToIssuanceDetailInternal(
          domain: domain,
          masterId: masterId,
          issueId: issueId,
          authAttempt: 0,
          dataAttempt: dataAttempt + 1,
          requestSeq: requestSeq,
        );
      });
    }
  }

  static bool _isAppUpdateNotification(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['notification_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
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

  static void _navigateToAsReceptionDetail(String id) {
    _asNavigationRequestSeq += 1;
    final requestSeq = _asNavigationRequestSeq;
    _queuePendingData({'type': 'as_reception', 'as_id': id});
    _pushAsReceptionDetailRoute(id, requestSeq: requestSeq);
  }

  static void _pushAsReceptionDetailRoute(
    String id, {
    int attempt = 0,
    required int requestSeq,
  }) {
    if (requestSeq != _asNavigationRequestSeq) return;
    final nav = navigatorKey.currentState;
    if (nav != null) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        try {
          final user = ProviderScope.containerOf(
            ctx,
          ).read(authControllerProvider);
          if (user == null) {
            if (attempt < 20) {
              Future<void>.delayed(
                Duration(milliseconds: 200 + attempt * 100),
                () {
                  _pushAsReceptionDetailRoute(
                    id,
                    attempt: attempt + 1,
                    requestSeq: requestSeq,
                  );
                },
              );
            }
            return;
          }
        } catch (_) {}
      }
      _pendingMessageData = null;
      final routeName = 'AsReceptionDetail/$id';
      final detailRoute = MaterialPageRoute<void>(
        builder: (_) => CustomerSupportReceptionDetailScreen(logId: id),
        settings: RouteSettings(name: routeName),
      );
      final topName = _topRouteName(nav);
      if (topName == routeName) return;
      if (topName != null && topName.startsWith('AsReceptionDetail/')) {
        nav.pushReplacement(detailRoute);
      } else {
        nav.push(detailRoute);
      }
      try {
        final ctx2 = navigatorKey.currentContext;
        if (ctx2 != null) {
          ProviderScope.containerOf(ctx2).invalidate(supportHomeStatsProvider);
        }
      } catch (_) {}
      return;
    }
    if (attempt < 60) {
      Future<void>.delayed(
        Duration(milliseconds: 50 + attempt * 40),
        () => _pushAsReceptionDetailRoute(
          id,
          attempt: attempt + 1,
          requestSeq: requestSeq,
        ),
      );
    }
  }

  static void _navigateToCallDetail(String id) {
    final requestSeq = ++_callNavigationRequestSeq;
    _navigateToCallDetailInternal(id, authAttempt: 0, requestSeq: requestSeq);
  }

  static void _navigateToCallDetailInternal(
    String id, {
    required int authAttempt,
    required int requestSeq,
  }) {
    if (requestSeq != _callNavigationRequestSeq) return;
    if (_shouldSuppressCallDetailNavigation()) {
      _log('skip call detail navigation: $kSalesCallCreateRouteName active');
      return;
    }
    _queuePendingData({'type': 'sales_call', 'call_id': id});

    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      try {
        final user = ProviderScope.containerOf(
          ctx,
        ).read(authControllerProvider);
        if (user == null) {
          if (authAttempt < 12) {
            final ms = 200 + authAttempt * 150;
            Future<void>.delayed(Duration(milliseconds: ms), () {
              _navigateToCallDetailInternal(
                id,
                authAttempt: authAttempt + 1,
                requestSeq: requestSeq,
              );
            });
          }
          return;
        }
      } catch (_) {
        if (authAttempt < 12) {
          final ms = 200 + authAttempt * 150;
          Future<void>.delayed(Duration(milliseconds: ms), () {
            _navigateToCallDetailInternal(
              id,
              authAttempt: authAttempt + 1,
              requestSeq: requestSeq,
            );
          });
        }
        return;
      }
    }

    _pushDetailRoute(id, requestSeq: requestSeq);
  }

  static void _invalidateHomeSalesCaches() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    try {
      final container = ProviderScope.containerOf(ctx);
      container
          .read(salesCallsRepositoryProvider)
          .invalidateTempManagerCache(forceRevertOnNextFetch: true);
      invalidateHomeSalesCaches(container.invalidate);
    } catch (_) {
      // ProviderScope 미연결(테스트 등) 시 무시
    }
  }

  static void _pushDetailRoute(
    String id, {
    int attempt = 0,
    required int requestSeq,
  }) {
    if (requestSeq != _callNavigationRequestSeq) return;
    final nav = navigatorKey.currentState;
    if (nav != null) {
      _pendingMessageData = null;
      final routeName = 'SalesCallDetail/$id';
      final detailRoute = MaterialPageRoute<void>(
        builder: (context) => SalesCallDetailScreen(id: id),
        settings: RouteSettings(name: routeName),
      );

      final topName = _topRouteName(nav);
      if (topName == routeName) {
        if (kDebugMode) {
          print('[FCM] already on $routeName');
        }
        return;
      }
      if (topName != null && topName.startsWith('SalesCallDetail/')) {
        nav.pushReplacement(detailRoute);
      } else {
        nav.push(detailRoute);
      }
      _invalidateHomeSalesCaches();
      if (kDebugMode) {
        print('[FCM] navigated to $routeName (from top=$topName)');
      }
      return;
    }
    if (attempt < 60) {
      final ms = 50 + attempt * 40;
      Future<void>.delayed(
        Duration(milliseconds: ms),
        () =>
            _pushDetailRoute(id, attempt: attempt + 1, requestSeq: requestSeq),
      );
    } else if (kDebugMode) {
      print(
        '[FCM] NavigatorState still null after retries; keeping pending payload',
      );
    }
  }

  /// Navigator 스택 최상단 route 이름 (currentContext의 ModalRoute는 하위 위젯일 수 있음).
  static String? _topRouteName(NavigatorState nav) {
    Route<dynamic>? top;
    nav.popUntil((route) {
      if (route.isCurrent) top = route;
      return true;
    });
    return top?.settings.name;
  }

  /// 에뮬레이터·GMS 미설치 등으로 FCM 토큰을 받을 수 없을 때 true.
  static bool _fcmUnavailable = false;
  static const String _pushDeviceKeyPref = 'push_device_key_v1';

  static bool get _firebaseReady => Firebase.apps.isNotEmpty;
  static Future<void>? _tokenSyncInFlight;
  static String? _tokenSyncUserId;

  static bool _isFcmUnavailableError(Object e) {
    final message = e.toString();
    return message.contains('SERVICE_NOT_AVAILABLE') ||
        message.contains('MISSING_INSTANCEID_SERVICE') ||
        message.contains('AUTHENTICATION_FAILED');
  }

  /// iOS: APNs 토큰이 준비된 뒤에만 FCM 토큰을 받을 수 있음.
  static Future<void> _ensureApnsTokenReady() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final messaging = FirebaseMessaging.instance;
    for (var i = 0; i < 12; i++) {
      try {
        final apns = await messaging.getAPNSToken();
        if (apns != null && apns.isNotEmpty) {
          _log('APNs token ready (attempt ${i + 1})');
          return;
        }
      } catch (e) {
        _log('getAPNSToken attempt ${i + 1} failed: $e');
      }
      await Future<void>.delayed(Duration(milliseconds: 400 + i * 200));
    }
    _log('APNs token not ready after retries; getToken may fail on iOS');
  }

  static Future<String?> getToken() async {
    if (_fcmUnavailable || !_firebaseReady) return null;
    try {
      await _ensureApnsTokenReady();
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      final msg = e.toString();
      if (_isFcmUnavailableError(e) || msg.contains('core/no-app')) {
        _fcmUnavailable = true;
        if (kDebugMode) {
          print(
            '[NotificationService] FCM unavailable on this device (emulator/no GMS); push token sync skipped',
          );
        }
        return null;
      }
      // iOS: apns-token-not-set 등은 일시적 — unavailable로 고정하지 않음
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
      return null;
    }
  }

  static Future<void> updateTokenInSupabase(String userId) async {
    if (_fcmUnavailable || !_firebaseReady) return;
    final inFlight = _tokenSyncInFlight;
    if (inFlight != null && _tokenSyncUserId == userId) {
      return inFlight;
    }
    final sync = _updateTokenInSupabaseImpl(userId);
    _tokenSyncUserId = userId;
    _tokenSyncInFlight = sync;
    try {
      await sync;
    } finally {
      if (identical(_tokenSyncInFlight, sync)) {
        _tokenSyncInFlight = null;
        _tokenSyncUserId = null;
      }
    }
  }

  static Future<void> _updateTokenInSupabaseImpl(String userId) async {
    if (_fcmUnavailable) return;
    // iOS는 APNs 준비 대기 포함해 재시도 폭을 넓힘
    final retryDelaysMs =
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
        ? const <int>[0, 800, 1600, 3000, 5000, 8000]
        : const <int>[0, 1200, 3000];
    for (var i = 0; i < retryDelaysMs.length; i++) {
      if (_fcmUnavailable) return;
      final delayMs = retryDelaysMs[i];
      if (delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      // 권한 미허용이면 토큰이 안 나오므로 한 번 더 요청(이미 허용이면 즉시 반환)
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        _log('permission before token sync: ${settings.authorizationStatus}');
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          _log('notification permission denied; skip token sync');
          return;
        }
      } catch (e) {
        _log('permission check failed: $e');
      }
      final token = await getToken();
      if (token == null || token.isEmpty) {
        if (_fcmUnavailable) return;
        continue;
      }
      try {
        final deviceKey = await _getOrCreateDeviceKey();
        final platform = _currentPlatformLabel();
        // 동일 FCM 토큰 unique 제약 — 다른 기기/계정 row가 있으면 선삭제 후 upsert
        await Supabase.instance.client
            .from('user_push_tokens')
            .delete()
            .eq('fcm_token', token);
        await Supabase.instance.client.from('user_push_tokens').upsert({
          'user_id': userId,
          'device_key': deviceKey,
          'platform': platform,
          'fcm_token': token,
          'is_active': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,device_key');

        // 레거시 단일 토큰 컬럼도 유지(점진 마이그레이션용)
        await Supabase.instance.client
            .from('users')
            .update({'fcm_token': token})
            .eq('id', userId);
        _log(
          'FCM token sync success user=$userId platform=$platform attempt=${i + 1} tokenLen=${token.length}',
        );
        return;
      } catch (e) {
        _log('FCM token sync failed user=$userId attempt=${i + 1} error=$e');
      }
    }
    _log('FCM token sync gave up user=$userId');
  }

  static void listenToTokenRefresh(String userId) {
    if (_fcmUnavailable || !_firebaseReady) return;
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        if (kDebugMode) {
          print("[NotificationService] FCM Token refreshed: $token");
        }
        try {
          final deviceKey = await _getOrCreateDeviceKey();
          final platform = _currentPlatformLabel();
          await Supabase.instance.client.from('user_push_tokens').upsert({
            'user_id': userId,
            'device_key': deviceKey,
            'platform': platform,
            'fcm_token': token,
            'is_active': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id,device_key');

          await Supabase.instance.client
              .from('users')
              .update({'fcm_token': token})
              .eq('id', userId);
          if (kDebugMode) {
            print(
              "[NotificationService] Refreshed FCM Token synced with Supabase",
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print("[NotificationService] ERROR syncing refreshed token: $e");
          }
        }
      });
    } catch (e) {
      _fcmUnavailable = true;
      if (kDebugMode) {
        print('[NotificationService] skip token refresh listener: $e');
      }
    }
  }

  static Future<String> _getOrCreateDeviceKey() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_pushDeviceKeyPref);
    if (existing != null && existing.isNotEmpty) return existing;

    final seed = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(1 << 32);
    final generated = 'dev_$seed$rand';
    await prefs.setString(_pushDeviceKeyPref, generated);
    return generated;
  }

  static String _currentPlatformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static Future<void> showIssuanceCompletedAlert({
    required String title,
    required String body,
    required IssuanceDomain domain,
    String? masterId,
    String? issueId,
  }) async {
    await _showIssuanceAlert(
      title: title,
      body: body,
      payload: {
        'type': 'issuance_completed',
        'issuance_domain': domain.name,
        'show_completed': true,
        if (masterId != null) 'master_id': masterId,
        if (issueId != null) 'issue_id': issueId,
      },
    );
  }

  static Future<void> showIssuanceRequestAlert({
    required String title,
    required String body,
    required IssuanceDomain domain,
    String? masterId,
    String? issueId,
  }) async {
    await _showIssuanceAlert(
      title: title,
      body: body,
      payload: {
        'type': 'issuance_request',
        'issuance_domain': domain.name,
        'show_completed': false,
        if (masterId != null) 'master_id': masterId,
        if (issueId != null) 'issue_id': issueId,
      },
    );
  }

  static const _issuanceRequestWatchInitKey =
      'issuance_request_watch_initialized_v1';
  static const _issuanceRequestSeenKey = 'issuance_request_seen_keys_v1';

  static String issuanceRequestRowKey({
    required IssuanceDomain domain,
    required String masterId,
    String? issueId,
  }) => '${domain.name}:$masterId:${issueId ?? ''}';

  static Future<void> markIssuanceRequestSeen({
    required SharedPreferences prefs,
    required IssuanceDomain domain,
    required String masterId,
    String? issueId,
  }) async {
    final rowKey = issuanceRequestRowKey(
      domain: domain,
      masterId: masterId,
      issueId: issueId,
    );
    if (!(prefs.getBool(_issuanceRequestWatchInitKey) ?? false)) {
      await prefs.setBool(_issuanceRequestWatchInitKey, true);
    }
    final seen =
        (prefs.getStringList(_issuanceRequestSeenKey) ?? const <String>[])
            .toSet();
    seen.add(rowKey);
    await prefs.setStringList(_issuanceRequestSeenKey, seen.toList());
  }

  static String _issuanceRequestTitle({
    required IssuanceDomain domain,
    required bool isUrgent,
    required bool isPartialRequest,
  }) {
    final urgent = isUrgent ? '🚨 [긴급] ' : '';
    final isTax = domain == IssuanceDomain.taxInvoice;
    if (isPartialRequest) {
      return '${urgent}${isTax ? '세금계산서' : '이행증권'} 부분 발급요청';
    }
    return '${urgent}${isTax ? '세금계산서' : '이행증권'} 발급요청';
  }

  static String _issuanceRequestBody({
    required String displayName,
    required bool isPartialRequest,
    double? issuePercentage,
  }) {
    final name = displayName.trim().isEmpty ? '요청 건' : displayName.trim();
    if (isPartialRequest && issuePercentage != null) {
      return '$name · ${issuePercentage.round()}% 발급요청이 등록되었습니다.';
    }
    return '$name 건의 발급요청이 등록되었습니다.';
  }

  /// 앱/감시에서 발급요청 알림 + seen 키 저장.
  static Future<void> showIssuanceRequestCreatedAlert({
    required SharedPreferences prefs,
    required IssuanceDomain domain,
    required String masterId,
    String? issueId,
    required String displayName,
    bool isUrgent = false,
    bool isPartialRequest = false,
    double? issuePercentage,
    bool markSeen = true,
  }) async {
    await showIssuanceRequestAlert(
      title: _issuanceRequestTitle(
        domain: domain,
        isUrgent: isUrgent,
        isPartialRequest: isPartialRequest,
      ),
      body: _issuanceRequestBody(
        displayName: displayName,
        isPartialRequest: isPartialRequest,
        issuePercentage: issuePercentage,
      ),
      domain: domain,
      masterId: masterId,
      issueId: issueId,
    );

    if (markSeen) {
      await markIssuanceRequestSeen(
        prefs: prefs,
        domain: domain,
        masterId: masterId,
        issueId: issueId,
      );
    }
  }

  /// 발급요청 등록 후 FCM 브로드캐스트 (접수 `notify-new-call`과 동일 패턴).
  static Future<void> invokeIssuanceRequestPush({
    required IssuanceDomain domain,
    required String masterId,
    String? issueId,
    required String displayName,
    bool isUrgent = false,
    bool isPartialRequest = false,
    double? issuePercentage,
  }) async {
    final title = _issuanceRequestTitle(
      domain: domain,
      isUrgent: isUrgent,
      isPartialRequest: isPartialRequest,
    );
    final body = _issuanceRequestBody(
      displayName: displayName,
      isPartialRequest: isPartialRequest,
      issuePercentage: issuePercentage,
    );
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'notify-issuance-request',
        body: {
          'type': 'INSERT',
          'record': {
            'notification_type': 'issuance_request',
            'issuance_domain': domain.name,
            'master_id': masterId,
            if (issueId != null && issueId.isNotEmpty) 'issue_id': issueId,
            'title': title,
            'body': body,
          },
        },
      );
      _log('notify-issuance-request status=${res.status} data=${res.data}');
      if (res.status >= 400) {
        _log('notify-issuance-request push invoke returned error status');
      }
    } catch (e, st) {
      _log('notify-issuance-request invoke failed: $e');
      if (kDebugMode) {
        print(st);
      }
    }
  }

  static Future<void> _showIssuanceAlert({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    final masterId = (payload['master_id'] ?? '').toString();
    final issueId = (payload['issue_id'] ?? '').toString();
    final tag = masterId.isEmpty
        ? null
        : issueId.isEmpty
        ? masterId
        : '$masterId:$issueId';
    final notificationId = tag == null
        ? DateTime.now().millisecondsSinceEpoch.remainder(1 << 31)
        : tag.hashCode & 0x7fffffff;

    await _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      payload: jsonEncode(payload),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelIssuanceId,
          _androidChannelIssuanceName,
          channelDescription: _androidChannelIssuanceDesc,
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
          category: AndroidNotificationCategory.message,
          tag: tag,
          autoCancel: true,
        ),
      ),
    );
  }

  /// A/S 접수 후 관리자만 FCM. 탭하면 접수 상세.
  static Future<void> invokeAsReceptionPush({
    required String asId,
    required String customerName,
    required String phone,
    String? issue,
    String? createdBy,
  }) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'notify-as-reception',
        body: {
          'record': {
            'id': asId,
            'customer_name': customerName,
            'customer_phone': phone,
            if ((issue ?? '').trim().isNotEmpty) 'issue': issue!.trim(),
            if ((createdBy ?? '').trim().isNotEmpty)
              'created_by': createdBy!.trim(),
          },
        },
      );
      _log('notify-as-reception status=${res.status} data=${res.data}');
      if (res.status >= 400) {
        _log('notify-as-reception push invoke returned error status');
      }
    } catch (e, st) {
      _log('notify-as-reception invoke failed: $e');
      if (kDebugMode) {
        print(st);
      }
    }
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
    final payload = jsonEncode({'type': 'sales_call', 'call_id': callId});
    await _localNotifications.show(
      id: callId.hashCode & 0x7fffffff,
      title: '[$assignee] 새 통화 등록 완료',
      body: '$name$phoneText 접수가 등록되었습니다.',
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelCallId,
          _androidChannelCallName,
          channelDescription: _androidChannelCallDesc,
          importance: Importance.max,
          priority: Priority.high,
          tag: callId,
        ),
      ),
    );
  }
}
