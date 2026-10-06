import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mcp_chat_message.dart';
import '../models/mcp_conversation_model.dart';
import '../models/mcp_server_model.dart';
import '../models/unified_chat_item.dart';
import '../services/mcp_client_service.dart';
import '../services/mcp_storage_service.dart';
import 'api_providers.dart';

/// Provider for McpClientService singleton
final mcpClientServiceProvider = Provider<McpClientService>((ref) {
  return McpClientService();
});

/// StateNotifier managing the list of configured Remote MCP Servers
class McpServersNotifier extends StateNotifier<List<McpServerModel>> {
  final Ref _ref;

  McpServersNotifier(this._ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    final loaded = await McpStorageService.loadServers();
    if (!mounted) return;
    state = loaded;

    // Load initial conversations for each server
    final convNotifier = _ref.read(mcpConversationsProvider.notifier);
    for (final server in loaded) {
      if (!mounted) return;
      await convNotifier.loadConversationForServer(server);
    }
  }

  /// Add a new remote MCP server
  Future<McpServerModel> addServer(McpServerModel newServer) async {
    // Attempt handshake & discovery
    final client = _ref.read(mcpClientServiceProvider);
    final connectedServer = await client.connectAndDiscover(newServer);

    final updated = [...state.where((s) => s.id != connectedServer.id), connectedServer];
    state = updated;
    await McpStorageService.saveServers(updated);

    // Initialize conversation
    final convNotifier = _ref.read(mcpConversationsProvider.notifier);
    await convNotifier.loadConversationForServer(connectedServer);

    return connectedServer;
  }

  /// Update an existing MCP server configuration
  Future<void> updateServer(McpServerModel server) async {
    final updated = state.map((s) => s.id == server.id ? server : s).toList();
    state = updated;
    await McpStorageService.saveServers(updated);
  }

  /// Delete an MCP server and its conversation history
  Future<void> deleteServer(String serverId) async {
    final updated = state.where((s) => s.id != serverId).toList();
    state = updated;
    await McpStorageService.saveServers(updated);
    await McpStorageService.deleteConversation(serverId);

    _ref.read(mcpConversationsProvider.notifier).removeConversation(serverId);
  }

  /// Reconnect and refresh tools for an MCP server
  Future<void> reconnectServer(String serverId) async {
    final index = state.indexWhere((s) => s.id == serverId);
    if (index == -1) return;

    final target = state[index];
    state = [
      ...state.sublist(0, index),
      target.copyWith(status: McpServerStatus.connecting),
      ...state.sublist(index + 1),
    ];

    final client = _ref.read(mcpClientServiceProvider);
    final refreshed = await client.connectAndDiscover(target);

    final updated = state.map((s) => s.id == serverId ? refreshed : s).toList();
    state = updated;
    await McpStorageService.saveServers(updated);

    // Also update server inside conversation model
    _ref.read(mcpConversationsProvider.notifier).updateServerInConversation(refreshed);
  }
}

final mcpServersProvider =
    StateNotifierProvider<McpServersNotifier, List<McpServerModel>>((ref) {
  return McpServersNotifier(ref);
});

/// StateNotifier managing MCP conversation threads
class McpConversationsNotifier extends StateNotifier<List<McpConversationModel>> {
  final Ref _ref;

  McpConversationsNotifier(this._ref) : super([]);

  /// Load or create conversation for a server
  Future<McpConversationModel> loadConversationForServer(McpServerModel server) async {
    final existingIndex = state.indexWhere((c) => c.serverId == server.id);
    if (existingIndex != -1) {
      return state[existingIndex];
    }

    final conv = await McpStorageService.loadConversation(server);
    if (!state.any((c) => c.id == conv.id)) {
      state = [...state, conv];
    }
    return conv;
  }

  void updateServerInConversation(McpServerModel server) {
    state = state.map((c) {
      if (c.serverId == server.id) {
        return c.copyWith(server: server);
      }
      return c;
    }).toList();
  }

  void removeConversation(String serverId) {
    state = state.where((c) => c.serverId != serverId).toList();
  }

  /// Send user message to an MCP server and receive response / tool executions
  Future<void> sendMessage({
    required String serverId,
    required String text,
  }) async {
    final index = state.indexWhere((c) => c.serverId == serverId);
    if (index == -1) return;

    final currentConv = state[index];
    final server = currentConv.server;

    final userMsg = McpChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      serverId: serverId,
      role: McpMessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );

    // Optimistically update conversation with user message
    var updatedMessages = [...currentConv.messages, userMsg];
    var updatedConv = currentConv.copyWith(
      messages: updatedMessages,
      lastMessage: text,
      lastMessageTime: DateTime.now(),
    );

    state = [
      ...state.sublist(0, index),
      updatedConv,
      ...state.sublist(index + 1),
    ];

    // Process via MCP Client Service
    final client = _ref.read(mcpClientServiceProvider);
    final replyMsg = await client.processUserMessage(
      server: server,
      userText: text,
    );

    // Re-check index in case state shifted
    final freshIndex = state.indexWhere((c) => c.serverId == serverId);
    if (freshIndex != -1) {
      final latestConv = state[freshIndex];
      final finalMessages = [...latestConv.messages, replyMsg];
      final finalConv = latestConv.copyWith(
        messages: finalMessages,
        lastMessage: replyMsg.content.replaceAll('\n', ' ').trim(),
        lastMessageTime: DateTime.now(),
      );

      state = [
        ...state.sublist(0, freshIndex),
        finalConv,
        ...state.sublist(freshIndex + 1),
      ];

      await McpStorageService.saveConversation(finalConv);
    }
  }

  /// Execute a specific tool and log to the chat conversation
  Future<McpChatMessage> executeTool({
    required String serverId,
    required String toolName,
    required Map<String, dynamic> arguments,
  }) async {
    final index = state.indexWhere((c) => c.serverId == serverId);
    if (index == -1) {
      throw Exception('Conversation not found for server $serverId');
    }

    final currentConv = state[index];
    final server = currentConv.server;

    // 1. Tool Call request message
    final callMsg = McpChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_call',
      serverId: serverId,
      role: McpMessageRole.toolCall,
      content: 'Calling tool `$toolName`...',
      toolName: toolName,
      toolArguments: arguments,
      timestamp: DateTime.now(),
    );

    var intermediateConv = currentConv.copyWith(
      messages: [...currentConv.messages, callMsg],
      lastMessage: 'Tool Call: $toolName',
      lastMessageTime: DateTime.now(),
    );

    state = [
      ...state.sublist(0, index),
      intermediateConv,
      ...state.sublist(index + 1),
    ];

    // 2. Perform tool execution
    final client = _ref.read(mcpClientServiceProvider);
    final result = await client.callTool(
      server: server,
      toolName: toolName,
      arguments: arguments,
    );

    // 3. Tool Result message
    final resultMsg = McpChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_res',
      serverId: serverId,
      role: McpMessageRole.toolResult,
      content: result.isSuccess
          ? 'Tool `$toolName` completed successfully'
          : 'Tool `$toolName` failed: ${result.errorMessage}',
      toolName: toolName,
      toolArguments: arguments,
      toolResult: result.result ?? result.errorMessage,
      isError: !result.isSuccess,
      latencyMs: result.latencyMs,
      timestamp: DateTime.now(),
    );

    final freshIndex = state.indexWhere((c) => c.serverId == serverId);
    if (freshIndex != -1) {
      final latestConv = state[freshIndex];
      final finalConv = latestConv.copyWith(
        messages: [...latestConv.messages, resultMsg],
        lastMessage: 'Result: $toolName (${result.latencyMs}ms)',
        lastMessageTime: DateTime.now(),
      );

      state = [
        ...state.sublist(0, freshIndex),
        finalConv,
        ...state.sublist(freshIndex + 1),
      ];

      await McpStorageService.saveConversation(finalConv);
    }

    return resultMsg;
  }

  /// Clear messages for a server conversation
  Future<void> clearConversation(String serverId) async {
    final index = state.indexWhere((c) => c.serverId == serverId);
    if (index == -1) return;

    final conv = state[index];
    final resetConv = conv.copyWith(
      messages: [],
      lastMessage: 'Chat history cleared',
      lastMessageTime: DateTime.now(),
    );

    state = [
      ...state.sublist(0, index),
      resetConv,
      ...state.sublist(index + 1),
    ];

    await McpStorageService.saveConversation(resetConv);
  }
}

final mcpConversationsProvider =
    StateNotifierProvider<McpConversationsNotifier, List<McpConversationModel>>((ref) {
  return McpConversationsNotifier(ref);
});

/// Unified Chats Provider merging user chats with MCP server conversations
final unifiedChatsProvider = Provider<AsyncValue<List<UnifiedChatItem>>>((ref) {
  final userChatsAsync = ref.watch(apiChatsProvider);
  final mcpServers = ref.watch(mcpServersProvider);
  final mcpConversations = ref.watch(mcpConversationsProvider);

  List<UnifiedChatItem> buildMcpItems() {
    final List<UnifiedChatItem> items = [];
    for (final server in mcpServers) {
      final conv = mcpConversations.firstWhere(
        (c) => c.serverId == server.id,
        orElse: () => McpConversationModel(
          id: 'mcp_${server.id}',
          server: server,
          lastMessage: 'Ready to run tools and prompts',
          lastMessageTime: server.createdAt,
        ),
      );
      items.add(UnifiedChatItem.fromMcp(conv));
    }
    return items;
  }

  return userChatsAsync.when(
    loading: () {
      if (mcpServers.isNotEmpty) {
        return AsyncValue.data(buildMcpItems());
      }
      return const AsyncValue.loading();
    },
    error: (err, stack) {
      if (mcpServers.isNotEmpty) {
        return AsyncValue.data(buildMcpItems());
      }
      return AsyncValue.error(err, stack);
    },
    data: (userChats) {
      final List<UnifiedChatItem> combined = [];

      // Add MCP chats
      combined.addAll(buildMcpItems());

      // Add user chats
      for (final userChat in userChats) {
        combined.add(UnifiedChatItem.fromUser(userChat));
      }

      // Sort with latest message on top
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return AsyncValue.data(combined);
    },
  );
});
