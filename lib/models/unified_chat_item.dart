import 'package:flutter/material.dart';
import 'chat_model.dart';
import 'event_model.dart';
import 'library_collection_model.dart';
import 'mcp_conversation_model.dart';
import 'mcp_server_model.dart';
import 'server_model.dart';

enum ChatItemType { user, mcp, server, project, event }

/// A unified wrapper model for a row in the Chats list: a User Chat, an MCP
/// Server Chat, a joined EME Server, or a Project.
class UnifiedChatItem {
  final ChatItemType type;
  final ChatModel? userChat;
  final McpConversationModel? mcpConversation;
  final ServerModel? emeServer;
  final LibraryCollectionModel? projectCollection;
  final EventModel? event;

  const UnifiedChatItem.fromUser(ChatModel chat)
    : type = ChatItemType.user,
      userChat = chat,
      mcpConversation = null,
      emeServer = null,
      projectCollection = null,
      event = null;

  const UnifiedChatItem.fromMcp(McpConversationModel conversation)
    : type = ChatItemType.mcp,
      userChat = null,
      mcpConversation = conversation,
      emeServer = null,
      projectCollection = null,
      event = null;

  const UnifiedChatItem.fromServer(ServerModel server)
    : type = ChatItemType.server,
      userChat = null,
      mcpConversation = null,
      emeServer = server,
      projectCollection = null,
      event = null;

  /// A project: a `librarycollection` from `viewprojects.json`, or an EME
  /// Server whose category is "project". At least one must be given.
  const UnifiedChatItem.fromProject({
    ServerModel? server,
    LibraryCollectionModel? collection,
  }) : assert(server != null || collection != null),
       type = ChatItemType.project,
       userChat = null,
       mcpConversation = null,
       emeServer = server,
       projectCollection = collection,
       event = null;

  const UnifiedChatItem.fromEvent(EventModel this.event)
    : type = ChatItemType.event,
      userChat = null,
      mcpConversation = null,
      emeServer = null,
      projectCollection = null;

  bool get isMcp => type == ChatItemType.mcp;
  bool get isUser => type == ChatItemType.user;
  bool get isServer => type == ChatItemType.server;
  bool get isProject => type == ChatItemType.project;
  bool get isEvent => type == ChatItemType.event;

  String get id {
    if (isEvent) return 'event_${event!.id}';
    if (isProject) {
      return projectCollection != null
          ? 'project_${projectCollection!.id}'
          : 'project_${emeServer!.id}';
    }
    if (isServer) return 'server_${emeServer!.id}';
    return isMcp
        ? mcpConversation!.id
        : (userChat!.channelId ?? userChat!.username);
  }

  String get displayName {
    if (isEvent) return event!.name;
    if (isProject) {
      if (projectCollection != null && projectCollection!.name.isNotEmpty) {
        return projectCollection!.name;
      }
      return emeServer?.name ?? 'Project';
    }
    if (isServer) return emeServer!.name;
    return isMcp ? mcpConversation!.server.name : userChat!.displayName;
  }

  String get subtitle {
    if (isEvent) return event!.location.isNotEmpty ? event!.location : 'Event';
    if (isProject) {
      return emeServer?.subtitle ?? emeServer?.category.name ?? 'Project';
    }
    if (isServer) return emeServer!.subtitle ?? emeServer!.category.name;
    return isMcp ? mcpConversation!.server.url : userChat!.username;
  }

  String get lastMessage {
    if (isEvent) return event!.description;
    if (isProject) {
      if (projectCollection != null) {
        return projectCollection!.displayDescription;
      }
      final note = emeServer?.lastNotification;
      return note != null && note.isNotEmpty
          ? note
          : (emeServer?.description ?? '');
    }
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
    if (isEvent) return '';
    if (isProject) {
      return emeServer?.lastNotificationTime ?? '';
    }
    if (isServer) return emeServer!.lastNotificationTime ?? '';
    if (isMcp) {
      return ChatModel.formatChatDate(mcpConversation!.lastMessageTime);
    }
    return userChat!.time;
  }

  DateTime get timestamp {
    // Projects and servers have no real-time last-message socket yet; keep below active chats
    if (isProject || isServer || isEvent) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (isMcp) {
      return mcpConversation!.lastMessageTime;
    }
    // Attempt to parse or default to now
    return DateTime.now();
  }

  int get unreadCount {
    if (isProject || isServer || isEvent) return 0;
    return isMcp ? mcpConversation!.unreadCount : userChat!.unreadCount;
  }

  Color get avatarColor {
    if (isEvent) return const Color(0xFFEA580C);
    if (isProject) {
      return emeServer?.primaryColor ?? const Color(0xFF3B82F6);
    }
    if (isServer) return emeServer!.primaryColor;
    return isMcp ? mcpConversation!.server.color : userChat!.avatarColor;
  }

  String get avatarInitials {
    if (isEvent) {
      final words = event!.name.trim().split(RegExp(r'\s+'));
      if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
        return (words[0][0] + words[1][0]).toUpperCase();
      }
      return event!.name.isEmpty
          ? 'EV'
          : event!.name
                .substring(0, event!.name.length.clamp(1, 2))
                .toUpperCase();
    }
    if (isProject) {
      if (projectCollection != null && projectCollection!.name.isNotEmpty) {
        final words = projectCollection!.name.trim().split(RegExp(r'\s+'));
        if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
          return (words[0][0] + words[1][0]).toUpperCase();
        }
        return projectCollection!.name
            .substring(0, projectCollection!.name.length.clamp(1, 2))
            .toUpperCase();
      }
      return emeServer?.displayInitials ?? 'PR';
    }
    if (isServer) return emeServer!.displayInitials;
    return isMcp
        ? mcpConversation!.server.displayInitials
        : (userChat!.avatarInitials ?? 'EM');
  }

  String? get avatarUrl {
    if (isEvent) return event!.imageUrl;
    if (isProject) {
      return projectCollection?.primaryImageUrl ?? emeServer?.avatarUrl;
    }
    if (isServer) return emeServer!.avatarUrl;
    return isMcp ? null : userChat!.avatarUrl;
  }

  bool get isOnline {
    if (isProject || isServer || isEvent) return false;
    return isMcp
        ? mcpConversation!.server.status == McpServerStatus.connected
        : userChat!.isOnline;
  }

  McpServerModel? get mcpServer => mcpConversation?.server;
}
