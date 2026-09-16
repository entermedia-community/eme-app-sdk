import 'package:firebase_core/firebase_core.dart'
    show Firebase, FirebaseOptions;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppErrorHandler {
  static bool _isFirebaseInitialized = false;

  static Future<void> initialize([FirebaseOptions? options]) async {
    if (options != null) {
      await Firebase.initializeApp(options: options);
      _isFirebaseInitialized = true;
    }

    FlutterError.onError = (FlutterErrorDetails details) {
      if (_isFirebaseInitialized) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      } else {
        debugPrint('[Fatal Flutter Error] ${details.exceptionAsString()}');
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (_isFirebaseInitialized) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      if (kDebugMode) {
        debugPrint('Platform error: $error\n$stack');
      } else {
        debugPrint('[Fatal Platform Error] $error\n$stack');
      }
      return true;
    };
  }

  static void recordNonFatal(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    Map<String, Object>? customKeys,
  }) {
    if (_isFirebaseInitialized) {
      FirebaseCrashlytics.instance.recordError(
        exception,
        stackTrace,
        fatal: false,
      );
    }
    if (kDebugMode) {
      debugPrint('[Non-Fatal Error] $reason: $exception');
      if (stackTrace != null) {
        debugPrint('$stackTrace');
      }
      return;
    }

    final buffer = StringBuffer('[Telemetry Log]');
    if (reason != null) buffer.write(' $reason:');
    buffer.write(' $exception');
    if (customKeys != null && customKeys.isNotEmpty) {
      buffer.write(' | metadata: $customKeys');
    }
    debugPrint(buffer.toString());
  }

  static void recordFatal(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    Map<String, Object>? customKeys,
  }) {
    if (_isFirebaseInitialized) {
      FirebaseCrashlytics.instance.recordError(
        exception,
        stackTrace,
        fatal: true,
      );
    }
    if (kDebugMode) {
      debugPrint('[Fatal Error] $reason: $exception');
      if (stackTrace != null) {
        debugPrint('$stackTrace');
      }
      return;
    }

    final buffer = StringBuffer('[Fatal Telemetry Log]');
    if (reason != null) buffer.write(' $reason:');
    buffer.write(' $exception');
    if (customKeys != null && customKeys.isNotEmpty) {
      buffer.write(' | metadata: $customKeys');
    }
    debugPrint(buffer.toString());
  }

  static void showUserError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xffef4444),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static void showUserSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff66bb6a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
