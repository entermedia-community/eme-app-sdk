import 'mcp_chat_message.dart';
import 'mcp_server_model.dart';

/// Conversation thread with an MCP Server
class McpConversationModel {
  final String id;
  final McpServerModel server;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final List<McpChatMessage> messages;

  const McpConversationModel({
    required this.id,
    required this.server,
    this.lastMessage = '',
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.messages = const [],
  });

  String get serverId => server.id;
  String get serverName => server.name;

  McpConversationModel copyWith({
    String? id,
    McpServerModel? server,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    List<McpChatMessage>? messages,
  }) {
    return McpConversationModel(
      id: id ?? this.id,
      server: server ?? this.server,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      messages: messages ?? this.messages,
    );
  }

  factory McpConversationModel.fromJson(Map<String, dynamic> json) {
    final serverJson = json['server'] is Map<String, dynamic>
        ? json['server'] as Map<String, dynamic>
        : <String, dynamic>{
            'id': json['serverId'] ?? 'unknown',
            'name': json['serverName'] ?? 'MCP Server',
            'url': json['url'] ?? '',
          };

    final messagesRaw = json['messages'];
    final List<McpChatMessage> msgs = [];
    if (messagesRaw is List) {
      for (final m in messagesRaw) {
        if (m is Map<String, dynamic>) {
          msgs.add(McpChatMessage.fromJson(m));
        }
      }
    }

    return McpConversationModel(
      id: json['id']?.toString() ?? 'mcp_${serverJson['id']}',
      server: McpServerModel.fromJson(serverJson),
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.tryParse(json['lastMessageTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      messages: msgs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server': server.toJson(),
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}
