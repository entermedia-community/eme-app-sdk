import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../openinsitute_core.dart';
import '../utils/dio.dart';
import '../utils/error_handler.dart';
import 'shared_preferences.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[PushNotificationService] Background Firebase init: $e');
  }
  debugPrint('[PushNotificationService] Background message received: ${message.messageId} | ${message.data}');
}

/// Parsed Notification Payload for EME Apps
class PushNotificationMessage {
  final String? messageId;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final String? type;
  final String? channelId;
  final String? serverId;
  final String? userId;
  final DateTime? sentTime;

  PushNotificationMessage({
    this.messageId,
    this.title,
    this.body,
    this.data = const {},
    this.type,
    this.channelId,
    this.serverId,
    this.userId,
    this.sentTime,
  });

  factory PushNotificationMessage.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;

    return PushNotificationMessage(
      messageId: message.messageId,
      title: notification?.title ?? data['title']?.toString(),
      body: notification?.body ?? data['body']?.toString() ?? data['message']?.toString(),
      data: data,
      type: data['type']?.toString() ?? data['action']?.toString(),
      channelId: data['channel']?.toString() ?? data['channelId']?.toString(),
      serverId: data['server']?.toString() ?? data['serverId']?.toString(),
      userId: data['user']?.toString() ?? data['userId']?.toString(),
      sentTime: message.sentTime,
    );
  }

  factory PushNotificationMessage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    return PushNotificationMessage(
      messageId: json['messageId']?.toString(),
      title: json['title']?.toString(),
      body: json['body']?.toString() ?? json['message']?.toString(),
      data: data,
      type: json['type']?.toString() ?? data['type']?.toString(),
      channelId: json['channel']?.toString() ?? data['channelId']?.toString() ?? data['channel']?.toString(),
      serverId: json['server']?.toString() ?? data['serverId']?.toString() ?? data['server']?.toString(),
      userId: json['user']?.toString() ?? data['userId']?.toString() ?? data['user']?.toString(),
      sentTime: json['sentTime'] != null ? DateTime.tryParse(json['sentTime'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'title': title,
      'body': body,
      'data': data,
      'type': type,
      'channelId': channelId,
      'serverId': serverId,
      'userId': userId,
      'sentTime': sentTime?.toIso8601String(),
    };
  }

  @override
  String toString() => 'PushNotificationMessage(title: $title, body: $body, type: $type, data: $data)';
}

/// Core Push Notification Service for Firebase Cloud Messaging
class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._internal();

  PushNotificationService._internal();

  factory PushNotificationService() => instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  final StreamController<PushNotificationMessage> _onMessageController =
      StreamController<PushNotificationMessage>.broadcast();
  final StreamController<PushNotificationMessage> _onMessageOpenedAppController =
      StreamController<PushNotificationMessage>.broadcast();

  bool _isInitialized = false;
  String? _fcmToken;
  String _channelId = 'eme_high_importance_channel';
  String _channelName = 'EME Notifications';
  String _channelDescription = 'Notifications for chats, updates, and activities';

  /// Streams
  Stream<PushNotificationMessage> get onMessage => _onMessageController.stream;
  Stream<PushNotificationMessage> get onMessageOpenedApp => _onMessageOpenedAppController.stream;
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  String? get currentToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  /// Callback for notification tap
  void Function(PushNotificationMessage message)? onNotificationTapped;

  /// Initialize Firebase Push Notifications and Local Notifications
  Future<bool> initialize({
    FirebaseOptions? firebaseOptions,
    String? defaultChannelId,
    String? defaultChannelName,
    String? defaultChannelDescription,
    bool requestPermissionOnStart = true,
    void Function(PushNotificationMessage message)? onNotificationTap,
  }) async {
    if (_isInitialized) return true;

    if (defaultChannelId != null) _channelId = defaultChannelId;
    if (defaultChannelName != null) _channelName = defaultChannelName;
    if (defaultChannelDescription != null) _channelDescription = defaultChannelDescription;
    if (onNotificationTap != null) onNotificationTapped = onNotificationTap;

    try {
      // 1. Initialize Firebase if not already initialized
      if (Firebase.apps.isEmpty) {
        if (firebaseOptions != null) {
          await Firebase.initializeApp(options: firebaseOptions);
        } else {
          await Firebase.initializeApp();
        }
      }

      // 2. Set Background Message Handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Initialize Local Notifications Plugin
      await _initLocalNotifications();

      // 4. Request Permissions if configured
      if (requestPermissionOnStart) {
        await requestNotificationPermissions();
      }

      // 5. Configure Apple Foreground Presentation Options
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 6. Setup Foreground Message Listener
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 7. Setup App Opened from Background Notification Listener
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final pushMsg = PushNotificationMessage.fromRemoteMessage(message);
        debugPrint('[PushNotificationService] Message opened from background: ${pushMsg.title}');
        _onMessageOpenedAppController.add(pushMsg);
        if (onNotificationTapped != null) {
          onNotificationTapped!(pushMsg);
        }
      });

      // 8. Check Initial Terminated Notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        final pushMsg = PushNotificationMessage.fromRemoteMessage(initialMessage);
        debugPrint('[PushNotificationService] Message opened from terminated: ${pushMsg.title}');
        _onMessageOpenedAppController.add(pushMsg);
        if (onNotificationTapped != null) {
          Future.microtask(() => onNotificationTapped!(pushMsg));
        }
      }

      // 9. Fetch and cache FCM token
      await fetchFcmToken();

      // 10. Listen to token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('[PushNotificationService] FCM Token refreshed: $newToken');
        registerTokenWithBackend(token: newToken);
      });

      _isInitialized = true;
      debugPrint('[PushNotificationService] Initialized successfully. Token: $_fcmToken');
      return true;
    } catch (e, stack) {
      debugPrint('[PushNotificationService] Initialization warning/error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'PushNotificationService.initialize failed',
      );
      return false;
    }
  }

  /// Initialize flutter_local_notifications for foreground display
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> data = jsonDecode(response.payload!);
            final pushMsg = PushNotificationMessage.fromJson(data);
            _onMessageOpenedAppController.add(pushMsg);
            if (onNotificationTapped != null) {
              onNotificationTapped!(pushMsg);
            }
          } catch (e) {
            debugPrint('[PushNotificationService] Error parsing notification payload: $e');
          }
        }
      },
    );

    // Create Android Notification Channel
    if (!kIsWeb && Platform.isAndroid) {
      final androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(androidChannel);
    }
  }

  /// Request push notification permissions (iOS & Android 13+)
  Future<NotificationSettings> requestNotificationPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    debugPrint(
      '[PushNotificationService] Notification permission status: ${settings.authorizationStatus}',
    );
    return settings;
  }

  /// Get current FCM Token
  Future<String?> fetchFcmToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        await SharedPref.saveString('fcm_token', _fcmToken!);
      }
      return _fcmToken;
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to get FCM token: $e');
      return null;
    }
  }

  /// Delete FCM Token
  Future<void> deleteFcmToken() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;
      await SharedPref.remove('fcm_token');
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to delete FCM token: $e');
    }
  }

  /// Subscribe to topic (e.g. 'all', 'announcements', 'server_123')
  Future<void> subscribeToTopic(String topic) async {
    try {
      final cleanTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      await _messaging.subscribeToTopic(cleanTopic);
      debugPrint('[PushNotificationService] Subscribed to topic: $cleanTopic');
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to subscribe to topic $topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      final cleanTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      await _messaging.unsubscribeFromTopic(cleanTopic);
      debugPrint('[PushNotificationService] Unsubscribed from topic: $cleanTopic');
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to unsubscribe from topic $topic: $e');
    }
  }

  /// Handle incoming foreground messages and show local banner
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final pushMsg = PushNotificationMessage.fromRemoteMessage(message);
    debugPrint('[PushNotificationService] Foreground message received: ${pushMsg.title} - ${pushMsg.body}');

    _onMessageController.add(pushMsg);

    // Show local notification so the user sees a banner even inside the app
    if (pushMsg.title != null || pushMsg.body != null) {
      await showLocalNotification(
        id: message.hashCode,
        title: pushMsg.title ?? 'New Notification',
        body: pushMsg.body ?? '',
        payload: jsonEncode(pushMsg.toJson()),
      );
    }
  }

  /// Display a local notification banner
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    String? channelName,
    String? channelDescription,
  }) async {
    final effectiveChannelId = channelId ?? _channelId;
    final effectiveChannelName = channelName ?? _channelName;
    final effectiveDesc = channelDescription ?? _channelDescription;

    final androidDetails = AndroidNotificationDetails(
      effectiveChannelId,
      effectiveChannelName,
      channelDescription: effectiveDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/launcher_icon',
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  /// Register device FCM token with Entermedia backend
  Future<bool> registerTokenWithBackend({
    String? token,
    String? siteroot,
    Map<String, dynamic>? extraData,
  }) async {
    final fcm = token ?? _fcmToken ?? await fetchFcmToken();
    if (fcm == null || fcm.isEmpty) return false;

    final base = (siteroot ?? OpenI.instance?.settings.siteroot ?? '').trim();
    if (base.isEmpty) return false;

    final url = '$base/services/module/user/savedevicetoken.json';
    final userToken = await SharedPref.getEMKey();

    try {
      final dio = DioUtil.dio;
      final payload = {
        'token': fcm,
        'platform': kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'desktop')),
        ...?extraData,
      };

      final response = await dio.post(
        url,
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-tokentype': 'entermedia',
            if (userToken != null && userToken.isNotEmpty) ...{
              'Authorization': 'Bearer $userToken',
              'entermediakey': userToken,
            },
          },
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      debugPrint('[PushNotificationService] Token registered with backend: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to register token with backend: $e');
      return false;
    }
  }

  void dispose() {
    _onMessageController.close();
    _onMessageOpenedAppController.close();
  }
}
