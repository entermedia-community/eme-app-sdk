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

  const McpToolCallResult({
    required this.isSuccess,
    this.result,
    this.errorMessage,
    required this.latencyMs,
  });
}

/// Model Context Protocol Client Service
class McpClientService {
  static final McpClientService _instance = McpClientService._internal();
  factory McpClientService() => _instance;
  McpClientService._internal();

  Dio get _dio => DioUtil.dio;

  int _rpcIdCounter = 1;

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
      List<McpToolDefinition> discoveredTools = [];
      List<McpPromptDefinition> discoveredPrompts = [];
      List<McpResourceDefinition> discoveredResources = [];

      // Attempt actual remote HTTP / SSE / JSON-RPC call
      try {
        final headers = <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/event-stream',
          ...server.headers,
        };

        final response = await _dio.post(
          server.url,
          data: initPayload,
          options: Options(
            headers: headers,
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

          // Fetch tools/list
          final toolsPayload = {
            'jsonrpc': '2.0',
            'id': _rpcIdCounter++,
            'method': 'tools/list',
            'params': {},
          };
          final toolsRes = await _dio.post(
            server.url,
            data: toolsPayload,
            options: Options(headers: headers, validateStatus: (_) => true),
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
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
        ...server.headers,
      };

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
            );
          }
          final result = data['result'] ?? data;
          return McpToolCallResult(
            isSuccess: true,
            result: result,
            latencyMs: stopwatch.elapsedMilliseconds,
          );
        }
      }

      return McpToolCallResult(
        isSuccess: false,
        errorMessage:
            'Remote server returned HTTP ${response.statusCode}: ${response.statusMessage}',
        result: response.data,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return McpToolCallResult(
        isSuccess: false,
        errorMessage: 'Connection error: $e',
        latencyMs: stopwatch.elapsedMilliseconds,
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
