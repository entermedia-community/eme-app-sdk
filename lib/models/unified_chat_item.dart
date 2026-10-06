import 'package:flutter/material.dart';
import 'chat_model.dart';
import 'mcp_conversation_model.dart';
import 'mcp_server_model.dart';

enum ChatItemType {
  user,
  mcp,
}

/// A unified wrapper model that can represent either a User Chat or an MCP Server Chat
class UnifiedChatItem {
  final ChatItemType type;
  final ChatModel? userChat;
  final McpConversationModel? mcpConversation;

  const UnifiedChatItem.fromUser(ChatModel chat)
      : type = ChatItemType.user,
        userChat = chat,
        mcpConversation = null;

  const UnifiedChatItem.fromMcp(McpConversationModel conversation)
      : type = ChatItemType.mcp,
        userChat = null,
        mcpConversation = conversation;

  bool get isMcp => type == ChatItemType.mcp;
  bool get isUser => type == ChatItemType.user;

  String get id => isMcp ? mcpConversation!.id : (userChat!.channelId ?? userChat!.username);

  String get displayName =>
      isMcp ? mcpConversation!.server.name : userChat!.displayName;

  String get subtitle =>
      isMcp ? mcpConversation!.server.url : userChat!.username;

  String get lastMessage {
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
    if (isMcp) {
      return ChatModel.formatChatDate(mcpConversation!.lastMessageTime);
    }
    return userChat!.time;
  }

  DateTime get timestamp {
    if (isMcp) {
      return mcpConversation!.lastMessageTime;
    }
    // Attempt to parse or default to now
    return DateTime.now();
  }

  int get unreadCount =>
      isMcp ? mcpConversation!.unreadCount : userChat!.unreadCount;

  Color get avatarColor =>
      isMcp ? mcpConversation!.server.color : userChat!.avatarColor;

  String get avatarInitials =>
      isMcp ? mcpConversation!.server.displayInitials : (userChat!.avatarInitials ?? 'EM');

  String? get avatarUrl => isMcp ? null : userChat!.avatarUrl;

  bool get isOnline => isMcp
      ? mcpConversation!.server.status == McpServerStatus.connected
      : userChat!.isOnline;

  McpServerModel? get mcpServer => mcpConversation?.server;
}
