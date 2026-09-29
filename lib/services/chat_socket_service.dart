import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/auth_service.dart';
import '../models/chat_model.dart';
import '../openinsitute_core.dart';
import '../utils/dio.dart';
import '../utils/error_handler.dart';

enum SocketConnectionState { disconnected, connecting, connected, reconnecting }

class ChatSocketService {
  static final ChatSocketService _instance = ChatSocketService._internal();
  factory ChatSocketService() => _instance;
  ChatSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  Timer? _keepAliveTimer;
  Timer? _reconnectTimer;

  String _userId = '';
  String _channelId = '';
  String? _channelType;
  String? _sessionId;
  String? _baseUrl;
  String? _entermediakey;
  bool _isDisposed = false;

  String _catalogId = '';

  SocketConnectionState _connectionState = SocketConnectionState.disconnected;

  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();

  // Getters
  Stream<ChatMessage> get messageStream => _messageController.stream;
  bool get isConnected => _connectionState == SocketConnectionState.connected;
  SocketConnectionState get connectionState => _connectionState;
  String get currentChannelId => _channelId;
  String get currentUserId => _userId;

  /// Make a POST request to /services/module/user/connect.json with fromuser and touser payload.
  /// Returns the channel Map with 'id', 'name', etc., or null if unsuccessful.
  Future<String> connectUser({
    required String fromUser,
    required String toUser,
    String? baseUrl,
    String? token,
  }) async {
    final effectiveToken = token ?? _resolveToken();
    final effectiveBase = baseUrl ?? _resolveHttpBaseUrl();

    // Determine target URL path
    final primaryUrl = '$effectiveBase/services/module/user/connect.json';

    final body = <String, dynamic>{'fromuser': fromUser, 'touser': toUser};

    debugPrint(
      'ChatSocketService: connectUser POST to $primaryUrl with payload: $body',
    );

    try {
      final dio = DioUtil.dio;
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
        'X-tokentype': 'entermedia',
        if (effectiveToken != null && effectiveToken.isNotEmpty) ...{
          'Authorization': 'Bearer $effectiveToken',
          'entermediakey': effectiveToken,
        },
      };

      Response response = await dio.post(
        primaryUrl,
        data: body,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint(
        'ChatSocketService: connectUser response [${response.statusCode}]: ${response.data}',
      );

      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) {
        try {
          data = jsonDecode(data);
        } catch (e) {
          debugPrint('ChatSocketService: failed to decode JSON response: $e');
        }
      }

      if (data is Map<String, dynamic>) {
        final channel = data['channel'];
        return channel.toString();
      }
      throw Exception('Failed to get channel from response');
    } catch (e, stack) {
      debugPrint('ChatSocketService: connectUser error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ChatSocketService.connectUser failed',
        customKeys: {'fromUser': fromUser, 'toUser': toUser, 'url': primaryUrl},
      );
      throw Exception('Failed to connect to chat');
    }
  }

  /// Connect to EnterMedia WebSocket Chat
  Future<void> connect({
    required String channel,
    String? channelType,
    String? userId,
    String? token,
    String? baseUrl,
    String? catalogId,
  }) async {
    _isDisposed = false;
    _channelId = channel;
    _channelType = channelType;
    _baseUrl = _resolveWsBaseUrl(baseUrl);
    _sessionId = _generateSessionId();

    _userId = _resolveUserId(userId);
    _entermediakey = _resolveToken(token);
    _catalogId = _resolveCatalogId(catalogId);

    if (_baseUrl == null || _baseUrl!.isEmpty || _userId.isEmpty) {
      debugPrint(
        'ChatSocketService: cannot connect without a valid baseUrl and userId',
      );
      return;
    }

    if (_connectionState == SocketConnectionState.connected ||
        _connectionState == SocketConnectionState.connecting) {
      return;
    }

    _updateState(
      _connectionState == SocketConnectionState.disconnected
          ? SocketConnectionState.connecting
          : SocketConnectionState.reconnecting,
    );

    try {
      final wsUri = _buildWebSocketUri();

      debugPrint('ChatSocketService connecting to: $wsUri');

      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready;

      debugPrint('ChatSocketService connected');

      _updateState(SocketConnectionState.connected);
      _startKeepAlive();

      _streamSubscription = _channel!.stream.listen(
        _onMessageReceived,
        onError: _onSocketError,
        onDone: _onSocketDone,
        cancelOnError: false,
      );
    } catch (e, stack) {
      debugPrint('ChatSocketService connection error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ChatSocketService connection error',
        customKeys: {'channel': channel, 'baseUrl': _baseUrl ?? ''},
      );
      _handleDisconnectAndReconnect();
    }
  }

  /// Send chat message
  void sendMessage({
    required String message,
    required String user,
    required String channel,
    String replyToId = '',
    String command = 'messagereceived',
    String functionName = '',
    String nextFunctionName = '',
    String messageType = 'message',
    Map<String, dynamic>? extraData,
  }) {
    final effectiveCatalogId = _catalogId.isNotEmpty
        ? _catalogId
        : (OpenI.instance?.settings.catalogId ?? '');

    final data = <String, dynamic>{
      'message': message,
      'channel': channel,
      'user': user,
      'catalogid': effectiveCatalogId,
      'command': command,
      'replytoid': replyToId,
      'functionname': functionName,
      'nextfunctionname': nextFunctionName,
      'messagetype': messageType,
      ...?extraData,
    };

    debugPrint('ChatSocketService sendMessage: $data');

    sendRaw(data);
  }

  /// Send raw map data over websocket
  void sendRaw(Map<String, dynamic> data) {
    if (_connectionState != SocketConnectionState.connected ||
        _channel == null) {
      debugPrint(
        'ChatSocketService: Socket not connected. Message dropped: $data',
      );
      return;
    }

    try {
      final jsonStr = json.encode(data);
      _channel!.sink.add(jsonStr);
      debugPrint('ChatSocketService sent: $jsonStr');
    } catch (e, stack) {
      debugPrint('ChatSocketService error sending message: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ChatSocketService sendRaw error',
        customKeys: {'data': data.toString()},
      );
    }
  }

  /// Handle incoming message from socket stream
  void _onMessageReceived(dynamic rawData) {
    try {
      debugPrint('ChatSocketService rawData received: $rawData');
      String strData;
      if (rawData is String) {
        strData = rawData;
      } else if (rawData is List<int>) {
        strData = utf8.decode(rawData);
      } else {
        return;
      }

      final decoded = json.decode(strData);

      void processMessage(Map<String, dynamic> data) {
        final chatMessage = ChatMessage.fromJson(data);
        _messageController.add(chatMessage);
      }

      if (decoded is Map<String, dynamic>) {
        processMessage(decoded);
      } else if (decoded is List) {
        for (var item in decoded) {
          if (item is Map<String, dynamic>) {
            processMessage(item);
          } else if (item is Map) {
            processMessage(Map<String, dynamic>.from(item));
          }
        }
      } else if (decoded is Map) {
        processMessage(Map<String, dynamic>.from(decoded));
      }
    } catch (e, stack) {
      debugPrint(
        'ChatSocketService error parsing incoming message: $e\n$stack',
      );
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ChatSocketService error parsing incoming message',
      );
    }
  }

  /// Periodic KeepAlive every 20 seconds matching chat.js
  void _startKeepAlive() {
    _stopKeepAlive();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (isConnected) {
        final keepAliveData = <String, dynamic>{
          'command': 'keepalive',
          'userid': _userId,
          if (_channelId.isNotEmpty) 'channel': _channelId,
        };
        sendRaw(keepAliveData);
      } else {
        _handleDisconnectAndReconnect();
      }
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  void _onSocketError(dynamic error) {
    debugPrint('ChatSocketService stream error: $error');
    AppErrorHandler.recordNonFatal(
      error,
      null,
      reason: 'ChatSocketService stream error',
      customKeys: {'channel': _channelId},
    );
    _handleDisconnectAndReconnect();
  }

  void _onSocketDone() {
    debugPrint('ChatSocketService connection closed.');
    _handleDisconnectAndReconnect();
  }

  void _handleDisconnectAndReconnect() {
    _stopKeepAlive();
    _streamSubscription?.cancel();
    _streamSubscription = null;

    if (_isDisposed) {
      _updateState(SocketConnectionState.disconnected);
      return;
    }

    _updateState(SocketConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isDisposed &&
          _connectionState != SocketConnectionState.connected &&
          _connectionState != SocketConnectionState.connecting &&
          _channelId.isNotEmpty) {
        connect(channel: _channelId, channelType: _channelType);
      }
    });
  }

  /// Disconnect current session
  void disconnect({bool reconnect = false}) {
    _reconnectTimer?.cancel();
    _stopKeepAlive();
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _channel?.sink.close();
    _channel = null;

    if (!reconnect) {
      _updateState(SocketConnectionState.disconnected);
    } else if (_channelId.isNotEmpty) {
      connect(channel: _channelId, channelType: _channelType);
    }
  }

  /// Clean up resources
  void dispose() {
    _isDisposed = true;
    disconnect();
  }

  void _updateState(SocketConnectionState newState) {
    _connectionState = newState;
  }

  String _generateSessionId() {
    final rand = Random().nextDouble();
    return rand.toString();
  }

  String _resolveUserId([String? explicitUserId]) {
    if (explicitUserId != null && explicitUserId.isNotEmpty) {
      return explicitUserId;
    }
    if (AuthService.userId != null && AuthService.userId!.isNotEmpty) {
      return AuthService.userId!;
    }
    return '';
  }

  String _resolveCatalogId([String? explicitCatalogId]) {
    if (explicitCatalogId != null && explicitCatalogId.isNotEmpty) {
      return explicitCatalogId;
    }
    final oi = OpenI.instance;
    if (oi != null && oi.settings.catalogId.isNotEmpty) {
      return oi.settings.catalogId;
    }
    return '';
  }

  String _resolveHttpBaseUrl([String? explicitBaseUrl]) {
    if (explicitBaseUrl != null && explicitBaseUrl.isNotEmpty) {
      return explicitBaseUrl;
    }
    final oi = OpenI.instance;
    if (oi != null && oi.settings.mediadb.isNotEmpty) {
      return oi.settings.mediadb;
    }
    return '';
  }

  String _resolveWsBaseUrl([String? explicitBaseUrl]) {
    if (explicitBaseUrl != null && explicitBaseUrl.isNotEmpty) {
      return explicitBaseUrl;
    }
    final oi = OpenI.instance;
    if (oi != null && oi.settings.siteroot.isNotEmpty) {
      final url = Uri.parse(oi.settings.siteroot);
      return '${url.scheme == 'https' ? 'wss' : 'ws'}://${url.host}${url.port != 80 && url.port != 443 ? ':${url.port}' : ''}'
          '/entermedia/services/websocket/org/entermediadb/websocket/chat/ChatConnection';
    }
    return '';
  }

  String? _resolveToken([String? explicitToken]) {
    if (explicitToken != null && explicitToken.isNotEmpty) {
      return explicitToken;
    }
    return AuthService.token;
  }

  Uri _buildWebSocketUri() {
    final key = _entermediakey;
    return Uri.parse(_baseUrl!).replace(
      queryParameters: <String, String>{
        'sessionid': _sessionId!,
        'userid': _userId,
        if (_channelId.isNotEmpty) 'channel': _channelId,
        if (_channelType != null && _channelType!.isNotEmpty)
          'channeltype': _channelType!,
        if (key != null && key.isNotEmpty) 'entermedia.key': key,
      },
    );
  }
}
