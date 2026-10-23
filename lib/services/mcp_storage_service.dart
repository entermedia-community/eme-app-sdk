import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mcp_conversation_model.dart';
import '../models/mcp_server_model.dart';
import '../models/mcp_chat_message.dart';

class McpStorageService {
  static const String _serversKey = 'eme_mcp_servers_v1';
  static const String _conversationsKeyPrefix = 'eme_mcp_conv_v1_';

  /// Load all saved MCP servers
  static Future<List<McpServerModel>> loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_serversKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map(
              (item) => McpServerModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Save the full list of MCP servers
  static Future<void> saveServers(List<McpServerModel> servers) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(servers.map((s) => s.toJson()).toList());
    await prefs.setString(_serversKey, raw);
  }

  /// Load conversation for a specific server
  static Future<McpConversationModel> loadConversation(
    McpServerModel server,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_conversationsKeyPrefix${server.id}';
    final raw = prefs.getString(key);

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final conv = McpConversationModel.fromJson(decoded);
          // Keep server configuration updated
          return conv.copyWith(server: server);
        }
      } catch (_) {}
    }

    // Default empty conversation with welcome message
    final initialMessages = [
      McpChatMessage(
        id: 'init_${server.id}',
        serverId: server.id,
        role: McpMessageRole.system,
        content:
            'Connected to MCP Server: **${server.name}**\nProtocol: MCP 2024-11-05\nEndpoint: `${server.url}`\nAvailable Tools: ${server.tools.length}',
        timestamp: DateTime.now(),
      ),
    ];

    final defaultConv = McpConversationModel(
      id: 'mcp_${server.id}',
      server: server,
      lastMessage: 'Connected to ${server.name}',
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      messages: initialMessages,
    );

    await saveConversation(defaultConv);
    return defaultConv;
  }

  /// Save conversation for a specific server
  static Future<void> saveConversation(McpConversationModel conv) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_conversationsKeyPrefix${conv.serverId}';
    final raw = jsonEncode(conv.toJson());
    await prefs.setString(key, raw);
  }

  /// Delete conversation for a server
  static Future<void> deleteConversation(String serverId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_conversationsKeyPrefix$serverId';
    await prefs.remove(key);
  }
}
