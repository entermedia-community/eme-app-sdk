import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/push_notification_service.dart';

/// Provider for the PushNotificationService instance
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService.instance;
});

/// Future provider for getting/refreshing FCM token
final fcmTokenProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(pushNotificationServiceProvider);
  return service.fetchFcmToken();
});

/// Stream provider for listening to foreground notifications
final pushNotificationStreamProvider = StreamProvider<PushNotificationMessage>((ref) {
  final service = ref.watch(pushNotificationServiceProvider);
  return service.onMessage;
});

/// Stream provider for notifications that caused the app to open
final pushNotificationOpenedAppStreamProvider = StreamProvider<PushNotificationMessage>((ref) {
  final service = ref.watch(pushNotificationServiceProvider);
  return service.onMessageOpenedApp;
});
