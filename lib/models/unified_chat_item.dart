import 'package:flutter/material.dart';
import 'chat_model.dart';
import 'mcp_conversation_model.dart';
import 'mcp_server_model.dart';
import 'server_model.dart';

enum ChatItemType {
  user,
  mcp,
  server,
}

/// A unified wrapper model for a row in the Chats list: a User Chat, an MCP
/// Server Chat, or a joined EME Server.
class UnifiedChatItem {
  final ChatItemType type;
  final ChatModel? userChat;
  final McpConversationModel? mcpConversation;
  final ServerModel? emeServer;

  const UnifiedChatItem.fromUser(ChatModel chat)
      : type = ChatItemType.user,
        userChat = chat,
        mcpConversation = null,
        emeServer = null;

  const UnifiedChatItem.fromMcp(McpConversationModel conversation)
      : type = ChatItemType.mcp,
        userChat = null,
        mcpConversation = conversation,
        emeServer = null;

  const UnifiedChatItem.fromServer(ServerModel server)
      : type = ChatItemType.server,
        userChat = null,
        mcpConversation = null,
        emeServer = server;

  bool get isMcp => type == ChatItemType.mcp;
  bool get isUser => type == ChatItemType.user;
  bool get isServer => type == ChatItemType.server;

  String get id {
    if (isServer) return 'server_${emeServer!.id}';
    return isMcp
        ? mcpConversation!.id
        : (userChat!.channelId ?? userChat!.username);
  }

  String get displayName {
    if (isServer) return emeServer!.name;
    return isMcp ? mcpConversation!.server.name : userChat!.displayName;
  }

  String get subtitle {
    if (isServer) return emeServer!.subtitle ?? emeServer!.category.name;
    return isMcp ? mcpConversation!.server.url : userChat!.username;
  }

  String get lastMessage {
    if (isServer) {
      final note = emeServer!.lastNotification;
      return note != null && note.isNotEmpty ? note : emeServer!.description;
    }
    if (isMcp) {
      return mcpConversation!.lastMessage.isNotEmpty
          ? mcpConversation!.lastMessage
          : 'Ready to run tools and prompts';
    }
    return userChat!.lastMessage.isNotEmpty
        ? userChat!.lastMessage
        : 'No message yet';
  }

  String get time {
    if (isServer) return emeServer!.lastNotificationTime ?? '';
    if (isMcp) {
      return ChatModel.formatChatDate(mcpConversation!.lastMessageTime);
    }
    return userChat!.time;
  }

  DateTime get timestamp {
    // Servers have no last-message time; keep them below active chats.
    if (isServer) return DateTime.fromMillisecondsSinceEpoch(0);
    if (isMcp) {
      return mcpConversation!.lastMessageTime;
    }
    // Attempt to parse or default to now
    return DateTime.now();
  }

  int get unreadCount {
    if (isServer) return 0;
    return isMcp ? mcpConversation!.unreadCount : userChat!.unreadCount;
  }

  Color get avatarColor {
    if (isServer) return emeServer!.primaryColor;
    return isMcp ? mcpConversation!.server.color : userChat!.avatarColor;
  }

  String get avatarInitials {
    if (isServer) return emeServer!.displayInitials;
    return isMcp
        ? mcpConversation!.server.displayInitials
        : (userChat!.avatarInitials ?? 'EM');
  }

  String? get avatarUrl {
    if (isServer) return emeServer!.avatarUrl;
    return isMcp ? null : userChat!.avatarUrl;
  }

  bool get isOnline {
    if (isServer) return false;
    return isMcp
        ? mcpConversation!.server.status == McpServerStatus.connected
        : userChat!.isOnline;
  }

  McpServerModel? get mcpServer => mcpConversation?.server;
}
