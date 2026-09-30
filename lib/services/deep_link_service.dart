import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import '../utils/error_handler.dart';

/// Deep Link Types
enum DeepLinkType {
  chat,
  userProfile,
  server,
  unknown,
}

/// Parsed Deep Link Payload
class DeepLinkPayload {
  final Uri rawUri;
  final DeepLinkType type;
  final String? username;
  final String? channelId;
  final String? serverId;
  final Map<String, String> queryParameters;

  DeepLinkPayload({
    required this.rawUri,
    required this.type,
    this.username,
    this.channelId,
    this.serverId,
    this.queryParameters = const {},
  });

  /// Factory method to parse any incoming Uri into a structured DeepLinkPayload
  factory DeepLinkPayload.fromUri(Uri uri) {
    final query = uri.queryParameters;
    final pathSegments = uri.pathSegments
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();

    String? targetUsername = query['username'] ?? query['user'] ?? query['u'] ?? query['chat'];
    String? targetChannelId = query['channel'] ?? query['channelId'];
    String? targetServerId = query['server'] ?? query['serverId'];
    DeepLinkType detectedType = DeepLinkType.unknown;

    // Check host for custom schemes e.g. emeworld://chat/john or emeworld://john
    final host = uri.host.trim().toLowerCase();

    // 1. Custom scheme with host as action (e.g. emeworld://chat/john or emeworld://user/john)
    if (host == 'chat' || host == 'user' || host == 'profile' || host == 'u') {
      detectedType = DeepLinkType.chat;
      if (pathSegments.isNotEmpty) {
        targetUsername ??= pathSegments.first;
      }
    } else if (host == 'server') {
      detectedType = DeepLinkType.server;
      if (pathSegments.isNotEmpty) {
        targetServerId ??= pathSegments.first;
      }
    } else if (uri.scheme == 'emeworld' && host.isNotEmpty && host != 'eme.world' && host != 'localhost') {
      // e.g. emeworld://john or emeworld://@john
      detectedType = DeepLinkType.chat;
      targetUsername ??= host.startsWith('@') ? host.substring(1) : host;
    }

    // 2. Standard Web/Universal Link paths e.g. https://eme.world/chat/john or https://eme.world/@john
    if (pathSegments.isNotEmpty) {
      final firstSegment = pathSegments[0].toLowerCase();

      if (firstSegment == 'chat' || firstSegment == 'user' || firstSegment == 'profile' || firstSegment == 'u') {
        detectedType = DeepLinkType.chat;
        if (pathSegments.length > 1) {
          targetUsername ??= pathSegments[1];
        }
      } else if (firstSegment == 'server' || firstSegment == 'servers') {
        detectedType = DeepLinkType.server;
        if (pathSegments.length > 1) {
          targetServerId ??= pathSegments[1];
        }
      } else if (firstSegment.startsWith('@')) {
        detectedType = DeepLinkType.chat;
        targetUsername ??= pathSegments[0].substring(1);
      } else if (pathSegments.length == 1 &&
          !['api', 'static', 'assets', 'auth', 'login', 'register', 'site', 'mediadb'].contains(firstSegment)) {
        // e.g. https://eme.world/username
        detectedType = DeepLinkType.chat;
        targetUsername ??= pathSegments[0];
      }
    }

    // Clean username (e.g. remove '@' if present)
    if (targetUsername != null) {
      targetUsername = targetUsername.trim();
      if (targetUsername.startsWith('@')) {
        targetUsername = targetUsername.substring(1);
      }
    }

    if (targetUsername != null && targetUsername.isNotEmpty && detectedType == DeepLinkType.unknown) {
      detectedType = DeepLinkType.chat;
    }

    return DeepLinkPayload(
      rawUri: uri,
      type: detectedType,
      username: targetUsername,
      channelId: targetChannelId,
      serverId: targetServerId,
      queryParameters: query,
    );
  }

  @override
  String toString() =>
      'DeepLinkPayload(type: $type, username: $username, channelId: $channelId, serverId: $serverId, uri: $rawUri)';
}

/// Deep Link Service managing incoming app links & routing
class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._internal();

  factory DeepLinkService() => instance;

  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  final StreamController<DeepLinkPayload> _deepLinkController =
      StreamController<DeepLinkPayload>.broadcast();

  bool _isInitialized = false;
  DeepLinkPayload? _pendingDeepLink;

  /// Stream of incoming deep links
  Stream<DeepLinkPayload> get onDeepLink => _deepLinkController.stream;

  /// Current pending deep link (if received before navigation/auth was ready)
  DeepLinkPayload? get pendingDeepLink => _pendingDeepLink;

  /// Clear the pending deep link once handled
  void clearPendingDeepLink() {
    _pendingDeepLink = null;
  }

  /// Initialize Deep Link handling
  Future<void> initialize({
    void Function(DeepLinkPayload payload)? onDeepLinkReceived,
  }) async {
    if (_isInitialized) return;

    try {
      // 1. Listen to incoming links (background & foreground)
      _sub = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          debugPrint('[DeepLinkService] Received deep link URI: $uri');
          final payload = DeepLinkPayload.fromUri(uri);
          _pendingDeepLink = payload;
          _deepLinkController.add(payload);
          if (onDeepLinkReceived != null) {
            onDeepLinkReceived(payload);
          }
        },
        onError: (err, stack) {
          debugPrint('[DeepLinkService] Error in deep link stream: $err');
          AppErrorHandler.recordNonFatal(
            err,
            stack,
            reason: 'DeepLinkService.uriLinkStream error',
          );
        },
      );

      // 2. Check initial link if app opened from cold start / terminated state
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[DeepLinkService] Initial deep link URI: $initialUri');
        final payload = DeepLinkPayload.fromUri(initialUri);
        _pendingDeepLink = payload;
        _deepLinkController.add(payload);
        if (onDeepLinkReceived != null) {
          Future.microtask(() => onDeepLinkReceived(payload));
        }
      }

      _isInitialized = true;
      debugPrint('[DeepLinkService] Initialized successfully.');
    } catch (e, stack) {
      debugPrint('[DeepLinkService] Initialization error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'DeepLinkService.initialize failed',
      );
    }
  }

  /// Generate shareable user chat link
  static String generateUserChatLink(String username, {bool universal = true, String siteRoot = 'https://eme.world'}) {
    final clean = username.trim().replaceAll('@', '');
    if (universal) {
      final base = siteRoot.endsWith('/') ? siteRoot.substring(0, siteRoot.length - 1) : siteRoot;
      return '$base/chat/$clean';
    }
    return 'emeworld://chat/$clean';
  }

  void dispose() {
    _sub?.cancel();
    _deepLinkController.close();
  }
}
