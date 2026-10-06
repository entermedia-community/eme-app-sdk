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
    if (raw == null || raw.isEmpty) {
      // Seed default sample MCP servers
      final defaultServers = _getDefaultSeedServers();
      await saveServers(defaultServers);
      return defaultServers;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => McpServerModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return _getDefaultSeedServers();
  }

  /// Save the full list of MCP servers
  static Future<void> saveServers(List<McpServerModel> servers) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(servers.map((s) => s.toJson()).toList());
    await prefs.setString(_serversKey, raw);
  }

  /// Load conversation for a specific server
  static Future<McpConversationModel> loadConversation(McpServerModel server) async {
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

  /// Default demo / sample servers to get started immediately
  static List<McpServerModel> _getDefaultSeedServers() {
    return [
      McpServerModel(
        id: 'eme_world_mcp',
        name: 'EnterMedia EME World MCP',
        url: 'https://eme-world-mcp.entermediadb.net/sse',
        transportType: McpTransportType.sse,
        description: 'Access media library, catalog search, user directory, and workflow automation.',
        colorValue: 0xFF0284C7,
        status: McpServerStatus.connected,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        lastConnectedAt: DateTime.now(),
        tools: const [
          McpToolDefinition(
            name: 'search_media_assets',
            description: 'Search images, videos, and documents in the EnterMedia library',
            inputSchema: {
              'type': 'object',
              'properties': {
                'query': {'type': 'string', 'description': 'Keyword search term'},
                'category': {'type': 'string', 'description': 'Optional category filter'},
                'limit': {'type': 'integer', 'description': 'Maximum results to return (default: 10)'},
              },
              'required': ['query'],
            },
          ),
          McpToolDefinition(
            name: 'get_user_profile',
            description: 'Fetch user profile, reputation score, and credentials by username',
            inputSchema: {
              'type': 'object',
              'properties': {
                'username': {'type': 'string', 'description': 'Username or User ID'},
              },
              'required': ['username'],
            },
          ),
          McpToolDefinition(
            name: 'create_catalog_product',
            description: 'Create a new marketplace listing or product entry in EME Catalog',
            inputSchema: {
              'type': 'object',
              'properties': {
                'title': {'type': 'string', 'description': 'Product or service title'},
                'price': {'type': 'number', 'description': 'Price in USD or Tokens'},
                'type': {
                  'type': 'string',
                  'description': 'Product category',
                  'enum': ['ecommerce', 'rideshare', 'rental', 'general'],
                },
              },
              'required': ['title', 'price'],
            },
          ),
          McpToolDefinition(
            name: 'get_server_health',
            description: 'Check EnterMedia server latency, cluster nodes, and background workers',
            inputSchema: {
              'type': 'object',
              'properties': {
                'serverId': {'type': 'string', 'description': 'Target Server ID'},
              },
            },
          ),
        ],
        prompts: const [
          McpPromptDefinition(
            name: 'summarize_assets',
            description: 'Generates an executive summary of newly uploaded media assets',
            arguments: [
              McpPromptArgument(name: 'date_range', description: 'e.g. today, this_week', required: false),
            ],
          ),
          McpPromptDefinition(
            name: 'audit_security_logs',
            description: 'Analyzes user access logs for suspicious activity',
          ),
        ],
        resources: const [
          McpResourceDefinition(
            uri: 'eme://schemas/catalog.json',
            name: 'Catalog Schema',
            description: 'JSON Schema definition for EME marketplace products',
            mimeType: 'application/json',
          ),
        ],
      ),
      McpServerModel(
        id: 'remote_ai_tools_mcp',
        name: 'AI Agent & Web Tools MCP',
        url: 'https://mcp-agent.cloud/v1/sse',
        transportType: McpTransportType.sse,
        description: 'Web scraping, live weather forecast, code runner, and mathematical computation.',
        colorValue: 0xFF8B5CF6,
        status: McpServerStatus.connected,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        lastConnectedAt: DateTime.now(),
        tools: const [
          McpToolDefinition(
            name: 'get_weather_forecast',
            description: 'Get real-time weather and temperature for a city',
            inputSchema: {
              'type': 'object',
              'properties': {
                'city': {'type': 'string', 'description': 'City name (e.g. San Francisco, Tokyo, London)'},
                'units': {'type': 'string', 'enum': ['celsius', 'fahrenheit'], 'description': 'Temperature unit'},
              },
              'required': ['city'],
            },
          ),
          McpToolDefinition(
            name: 'execute_calculator',
            description: 'Evaluate mathematical expressions accurately',
            inputSchema: {
              'type': 'object',
              'properties': {
                'expression': {'type': 'string', 'description': 'e.g. 12 * 45 + sqrt(144)'},
              },
              'required': ['expression'],
            },
          ),
          McpToolDefinition(
            name: 'fetch_web_page',
            description: 'Fetches clean markdown text content from any public webpage',
            inputSchema: {
              'type': 'object',
              'properties': {
                'url': {'type': 'string', 'description': 'URL to fetch'},
              },
              'required': ['url'],
            },
          ),
        ],
      ),
    ];
  }
}
