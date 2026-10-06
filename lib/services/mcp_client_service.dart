import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/mcp_chat_message.dart';
import '../models/mcp_server_model.dart';
import '../utils/dio.dart';
import '../utils/error_handler.dart';

/// Result returned from an MCP tool call or message invocation
class McpToolCallResult {
  final bool isSuccess;
  final dynamic result;
  final String? errorMessage;
  final int latencyMs;
  final String? sessionId;

  const McpToolCallResult({
    required this.isSuccess,
    this.result,
    this.errorMessage,
    required this.latencyMs,
    this.sessionId,
  });
}

/// Model Context Protocol Client Service
class McpClientService {
  static final McpClientService _instance = McpClientService._internal();
  factory McpClientService() => _instance;
  McpClientService._internal();

  Dio get _dio => DioUtil.dio;

  int _rpcIdCounter = 1;

  /// Extracts the MCP Session ID from either the response header or response body
  String? _extractSessionId(Response response) {
    // 1. Check HTTP response headers (standard Mcp-Session-Id header)
    final headerVal = response.headers.value('mcp-session-id') ??
        response.headers.value('Mcp-Session-Id');
    if (headerVal != null && headerVal.trim().isNotEmpty) {
      return headerVal.trim();
    }

    // 2. Check JSON-RPC response body if present
    if (response.data is Map) {
      final data = response.data as Map;
      final res = data['result'];
      if (res is Map) {
        final sId = res['sessionId'] ?? res['session_id'];
        if (sId != null && sId.toString().trim().isNotEmpty) {
          return sId.toString().trim();
        }
      }
      final sId = data['sessionId'] ?? data['session_id'];
      if (sId != null && sId.toString().trim().isNotEmpty) {
        return sId.toString().trim();
      }
    }
    return null;
  }

  /// Builds request headers including Authorization and standard Mcp-Session-Id
  Map<String, dynamic> _buildHeaders(
    McpServerModel server, {
    String? overrideSessionId,
    bool includeEventStream = false,
  }) {
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
      if (includeEventStream) 'Accept': 'application/json, text/event-stream',
      ...server.headers,
    };

    final effectiveSessionId = overrideSessionId ?? server.sessionId;
    if (effectiveSessionId != null && effectiveSessionId.isNotEmpty) {
      headers['Mcp-Session-Id'] = effectiveSessionId;
    }
    return headers;
  }

  /// Test connection and discover server capabilities and tools
  Future<McpServerModel> connectAndDiscover(McpServerModel server) async {
    try {
      // 1. Initialize MCP Protocol Handshake
      final initPayload = {
        'jsonrpc': '2.0',
        'id': _rpcIdCounter++,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2024-11-05',
          'capabilities': {
            'roots': {'listChanged': true},
            'sampling': {},
            'experimental': {},
          },
          'clientInfo': {'name': 'EME-Mobile-MCP-Client', 'version': '1.0.0'},
        },
      };

      Map<String, dynamic>? initResponse;
      String? discoveredSessionId = server.sessionId;
      List<McpToolDefinition> discoveredTools = [];
      List<McpPromptDefinition> discoveredPrompts = [];
      List<McpResourceDefinition> discoveredResources = [];

      // Attempt actual remote HTTP / SSE / JSON-RPC call
      try {
        final initHeaders = _buildHeaders(server, includeEventStream: true);

        final response = await _dio.post(
          server.url,
          data: initPayload,
          options: Options(
            headers: initHeaders,
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
            validateStatus: (status) => true,
          ),
        );

        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300 &&
            response.data is Map<String, dynamic>) {
          initResponse = response.data as Map<String, dynamic>;

          // Extract session id returned during initialize
          final sid = _extractSessionId(response);
          if (sid != null) {
            discoveredSessionId = sid;
          }

          final authenticatedHeaders = _buildHeaders(
            server,
            overrideSessionId: discoveredSessionId,
            includeEventStream: true,
          );

          // Standard MCP handshake notification (notifications/initialized)
          if (discoveredSessionId != null) {
            try {
              final notifPayload = {
                'jsonrpc': '2.0',
                'method': 'notifications/initialized',
                'params': {},
              };
              await _dio.post(
                server.url,
                data: notifPayload,
                options: Options(
                  headers: authenticatedHeaders,
                  sendTimeout: const Duration(seconds: 3),
                  validateStatus: (_) => true,
                ),
              );
            } catch (_) {}
          }

          // Fetch tools/list with session id
          final toolsPayload = {
            'jsonrpc': '2.0',
            'id': _rpcIdCounter++,
            'method': 'tools/list',
            'params': {},
          };
          final toolsRes = await _dio.post(
            server.url,
            data: toolsPayload,
            options: Options(
              headers: authenticatedHeaders,
              validateStatus: (_) => true,
            ),
          );
          if (toolsRes.data is Map &&
              toolsRes.data['result']?['tools'] is List) {
            for (final t in toolsRes.data['result']['tools']) {
              if (t is Map<String, dynamic>) {
                discoveredTools.add(McpToolDefinition.fromJson(t));
              }
            }
          }
        } else {
          return server.copyWith(
            status: McpServerStatus.error,
            errorMessage:
                'Server returned HTTP ${response.statusCode}: ${response.statusMessage}',
          );
        }
      } catch (networkErr) {
        return server.copyWith(
          status: McpServerStatus.error,
          errorMessage: 'Connection failed: $networkErr',
        );
      }

      // If remote returned tools, use them; otherwise preserve pre-configured tools
      if (discoveredTools.isEmpty) {
        discoveredTools = server.tools;
      }

      if (discoveredPrompts.isEmpty) {
        discoveredPrompts = server.prompts;
      }

      if (discoveredResources.isEmpty) {
        discoveredResources = server.resources;
      }

      return server.copyWith(
        status: McpServerStatus.connected,
        errorMessage: null,
        sessionId: discoveredSessionId,
        tools: discoveredTools,
        prompts: discoveredPrompts,
        resources: discoveredResources,
        serverInfo:
            initResponse['result']?['serverInfo'] is Map<String, dynamic>
            ? initResponse['result']['serverInfo'] as Map<String, dynamic>
            : {'name': server.name, 'version': '1.0.0'},
        capabilities:
            initResponse['result']?['capabilities'] is Map<String, dynamic>
            ? initResponse['result']['capabilities'] as Map<String, dynamic>
            : {
                'tools': {'listChanged': true},
              },
        lastConnectedAt: DateTime.now(),
      );
    } catch (e, stack) {
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'Error connecting to MCP server ${server.name}',
      );
      return server.copyWith(
        status: McpServerStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Query tools/list from remote MCP server
  Future<List<McpToolDefinition>> listTools(McpServerModel server) async {
    final toolsPayload = {
      'jsonrpc': '2.0',
      'id': _rpcIdCounter++,
      'method': 'tools/list',
      'params': {},
    };

    final headers = _buildHeaders(server, includeEventStream: true);

    final response = await _dio.post(
      server.url,
      data: toolsPayload,
      options: Options(
        headers: headers,
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        validateStatus: (_) => true,
      ),
    );

    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300 &&
        response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      if (data['result']?['tools'] is List) {
        final List<McpToolDefinition> tools = [];
        for (final t in data['result']['tools']) {
          if (t is Map<String, dynamic>) {
            tools.add(McpToolDefinition.fromJson(t));
          }
        }
        return tools;
      }
    }

    final errorMsg =
        response.data is Map && response.data['error']?['message'] != null
        ? response.data['error']['message'].toString()
        : 'HTTP ${response.statusCode}: ${response.statusMessage ?? 'Unknown error'}';
    throw Exception('tools/list failed: $errorMsg');
  }

  /// Call an MCP tool on the remote server
  Future<McpToolCallResult> callTool({
    required McpServerModel server,
    required String toolName,
    required Map<String, dynamic> arguments,
  }) async {
    final stopwatch = Stopwatch()..start();

    final rpcPayload = {
      'jsonrpc': '2.0',
      'id': _rpcIdCounter++,
      'method': 'tools/call',
      'params': {'name': toolName, 'arguments': arguments},
    };

    try {
      final headers = _buildHeaders(server);

      final response = await _dio.post(
        server.url,
        data: rpcPayload,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (status) => true,
        ),
      );

      stopwatch.stop();

      final responseSessionId = _extractSessionId(response) ?? server.sessionId;

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data['error'] != null) {
            return McpToolCallResult(
              isSuccess: false,
              errorMessage:
                  data['error']['message']?.toString() ?? 'Tool error',
              result: data['error'],
              latencyMs: stopwatch.elapsedMilliseconds,
              sessionId: responseSessionId,
            );
          }
          final result = data['result'] ?? data;
          return McpToolCallResult(
            isSuccess: true,
            result: result,
            latencyMs: stopwatch.elapsedMilliseconds,
            sessionId: responseSessionId,
          );
        }
      }

      return McpToolCallResult(
        isSuccess: false,
        errorMessage:
            'Remote server returned HTTP ${response.statusCode}: ${response.statusMessage}',
        result: response.data,
        latencyMs: stopwatch.elapsedMilliseconds,
        sessionId: responseSessionId,
      );
    } catch (e) {
      stopwatch.stop();
      return McpToolCallResult(
        isSuccess: false,
        errorMessage: 'Connection error: $e',
        latencyMs: stopwatch.elapsedMilliseconds,
        sessionId: server.sessionId,
      );
    }
  }

  /// Process natural language user prompt in MCP Client Chat
  Future<McpChatMessage> processUserMessage({
    required McpServerModel server,
    required String userText,
  }) async {
    final clean = userText.trim();

    // Check if user is invoking a direct tool syntax like: /tool tool_name {"arg": "val"}
    if (clean.startsWith('/tool ') || clean.startsWith('/run ')) {
      final parts = clean.split(' ');
      if (parts.length >= 2) {
        final toolName = parts[1];
        Map<String, dynamic> args = {};
        if (parts.length >= 3) {
          final jsonPart = clean.substring(clean.indexOf(parts[2]));
          try {
            args = jsonDecode(jsonPart) as Map<String, dynamic>;
          } catch (_) {}
        }
        final result = await callTool(
          server: server,
          toolName: toolName,
          arguments: args,
        );
        return McpChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          serverId: server.id,
          role: McpMessageRole.toolResult,
          content: result.isSuccess
              ? 'Executed tool: `$toolName`'
              : 'Error executing `$toolName`: ${result.errorMessage}',
          toolName: toolName,
          toolArguments: args,
          toolResult: result.result ?? result.errorMessage,
          isError: !result.isSuccess,
          latencyMs: result.latencyMs,
          timestamp: DateTime.now(),
        );
      }
    }

    // Default assistant response with tool suggestions
    final toolListStr = server.tools.isNotEmpty
        ? server.tools
              .map(
                (t) =>
                    '• **${t.name}**: ${t.description.isNotEmpty ? t.description : 'Tool action'}',
              )
              .join('\n')
        : '• No tools currently advertised by this server.';

    return McpChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      serverId: server.id,
      role: McpMessageRole.assistant,
      content:
          'Connected to **${server.name}**.\n\nYou can run tools using `/tool <name> <json_args>`:\n\n$toolListStr',
      timestamp: DateTime.now(),
    );
  }
}
