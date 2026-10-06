import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eme_app_sdk/eme_app_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MCP Models and Serialization Tests', () {
    test('McpServerModel serializes and deserializes properly', () {
      final server = McpServerModel(
        id: 'test_mcp_1',
        name: 'PostgreSQL DB MCP',
        url: 'https://db-mcp.cloud/sse',
        transportType: McpTransportType.sse,
        description: 'Query and manage relational database',
        headers: const {'Authorization': 'Bearer test_key'},
        colorValue: 0xFF10B981,
        tools: const [
          McpToolDefinition(
            name: 'execute_sql',
            description: 'Run SQL query against database',
            inputSchema: {
              'type': 'object',
              'properties': {
                'query': {'type': 'string', 'description': 'SQL statement'},
                'limit': {'type': 'integer'},
              },
              'required': ['query'],
            },
          ),
        ],
        prompts: const [
          McpPromptDefinition(
            name: 'analyze_slow_queries',
            description: 'Identifies query bottlenecks',
          ),
        ],
        sessionId: 'test_session_abc123',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(server.id, 'test_mcp_1');
      expect(server.displayInitials, 'PD');
      expect(server.sessionId, 'test_session_abc123');
      expect(server.tools.length, 1);
      expect(server.tools.first.name, 'execute_sql');
      expect(server.tools.first.properties.containsKey('query'), true);
      expect(server.tools.first.requiredFields.contains('query'), true);

      final json = server.toJson();
      expect(json['sessionId'], 'test_session_abc123');
      final restored = McpServerModel.fromJson(json);
      expect(restored.id, server.id);
      expect(restored.name, server.name);
      expect(restored.url, server.url);
      expect(restored.sessionId, 'test_session_abc123');
      expect(restored.tools.length, 1);
      expect(restored.tools.first.name, 'execute_sql');
    });

    test('McpChatMessage serializes roles, arguments, and results', () {
      final msg = McpChatMessage(
        id: 'msg_mcp_1',
        serverId: 'test_mcp_1',
        role: McpMessageRole.toolResult,
        content: 'Executed tool',
        toolName: 'execute_sql',
        toolArguments: const {'query': 'SELECT * FROM users'},
        toolResult: const {'rows_affected': 4},
        latencyMs: 85,
        timestamp: DateTime(2026, 1, 1, 12, 0),
      );

      expect(msg.role.isToolResult, true);
      expect(msg.formattedArguments, contains('SELECT * FROM users'));
      expect(msg.formattedResult, contains('rows_affected'));

      final json = msg.toJson();
      final restored = McpChatMessage.fromJson(json);
      expect(restored.id, msg.id);
      expect(restored.role, McpMessageRole.toolResult);
      expect(restored.latencyMs, 85);
    });

    test('UnifiedChatItem wraps User Chat and MCP Chat seamlessly', () {
      const userChat = ChatModel(
        channelId: 'ch_1',
        username: 'alice',
        displayName: 'Alice User',
        lastMessage: 'Hello there',
        time: '12:30 PM',
        avatarColor: Color(0xFF2563EB),
      );

      final mcpServer = McpServerModel(
        id: 'srv_1',
        name: 'EnterMedia MCP',
        url: 'https://mcp.entermediadb.net/sse',
        createdAt: DateTime.now(),
      );

      final mcpConv = McpConversationModel(
        id: 'mcp_srv_1',
        server: mcpServer,
        lastMessage: 'Tool executed',
        lastMessageTime: DateTime.now(),
      );

      final userItem = UnifiedChatItem.fromUser(userChat);
      expect(userItem.isUser, true);
      expect(userItem.isMcp, false);
      expect(userItem.displayName, 'Alice User');

      final mcpItem = UnifiedChatItem.fromMcp(mcpConv);
      expect(mcpItem.isMcp, true);
      expect(mcpItem.isUser, false);
      expect(mcpItem.displayName, 'EnterMedia MCP');
    });
  });

  group('McpClientService Tests', () {
    test('McpClientService fails transparently on unreachable endpoints and returns assistant help', () async {
      final client = McpClientService();
      final server = McpServerModel(
        id: 'srv_weather',
        name: 'Weather MCP',
        url: 'https://weather-mcp.invalid/sse',
        tools: const [
          McpToolDefinition(
            name: 'get_weather_forecast',
            description: 'Get weather for a city',
            inputSchema: {
              'type': 'object',
              'properties': {'city': {'type': 'string'}},
              'required': ['city'],
            },
          ),
        ],
        createdAt: DateTime.now(),
      );

      // 1. Tool call against unreachable endpoint should fail transparently, not fake a simulation
      final toolResult = await client.callTool(
        server: server,
        toolName: 'get_weather_forecast',
        arguments: {'city': 'Tokyo'},
      );

      expect(toolResult.isSuccess, false);
      expect(toolResult.errorMessage, isNotNull);

      // 2. Natural language user prompt should return assistant message listing available tools
      final assistantMsg = await client.processUserMessage(
        server: server,
        userText: 'What is the weather in Paris?',
      );

      expect(assistantMsg.role, McpMessageRole.assistant);
      expect(assistantMsg.content, contains('Connected to **Weather MCP**'));
      expect(assistantMsg.content, contains('get_weather_forecast'));
    });
  });

  group('Mcp Riverpod Providers State Tests', () {
    test('McpServersNotifier and McpConversationsNotifier manage state and execution', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mcpServersProvider.notifier);
      final server = await notifier.addServer(
        McpServerModel(
          id: 'test_srv_custom',
          name: 'Custom Test MCP',
          url: 'https://test-mcp.cloud/sse',
          tools: const [
            McpToolDefinition(
              name: 'test_query_tool',
              description: 'Test query tool',
              inputSchema: {'type': 'object'},
            ),
          ],
          createdAt: DateTime.now(),
        ),
      );

      final servers = container.read(mcpServersProvider);
      expect(servers.isNotEmpty, true);
      final firstServer = server;
      expect(firstServer.tools.isNotEmpty, true);

      // Send a message
      await container.read(mcpConversationsProvider.notifier).sendMessage(
            serverId: firstServer.id,
            text: 'Hello MCP server!',
          );

      final conversations = container.read(mcpConversationsProvider);
      final activeConv = conversations.firstWhere((c) => c.serverId == firstServer.id);
      expect(activeConv.messages.length >= 2, true);
      expect(activeConv.messages.any((m) => m.role == McpMessageRole.user), true);

      // Execute a tool directly
      final tool = firstServer.tools.first;
      final toolResultMsg = await container.read(mcpConversationsProvider.notifier).executeTool(
            serverId: firstServer.id,
            toolName: tool.name,
            arguments: {'query': 'test query'},
          );

      expect(toolResultMsg.role, McpMessageRole.toolResult);
      expect(toolResultMsg.toolName, tool.name);
    });
  });
}
