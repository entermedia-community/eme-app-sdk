import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Dedicated cache manager for Chat data (chat lists, user message history, server message history)
class ChatCacheManager {
  ChatCacheManager._();

  static const String key = 'eme_chat_cache';

  static BaseCacheManager? _customInstance;

  /// CacheManager configured for chat metadata and messages
  static BaseCacheManager get instance => _customInstance ??= CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 200,
    ),
  );

  @visibleForTesting
  static set customInstance(BaseCacheManager? manager) {
    _customInstance = manager;
  }

  /// Key generation helpers
  static String chatListKey(String baseUrl) => 'chats_list_${baseUrl.trim()}';

  static String userChatHistoryKey(String baseUrl, String channelId) =>
      'chat_history_user_${baseUrl.trim()}_$channelId';

  static String serverChatHistoryKey(
    String baseUrl,
    String channelId, {
    String? serverId,
  }) => 'chat_history_server_${baseUrl.trim()}_${serverId ?? ""}_$channelId';

  /// Put raw string (JSON) into cache
  static Future<void> putJson(
    String cacheKey,
    String jsonString, {
    Duration maxAge = const Duration(days: 14),
  }) async {
    try {
      final bytes = utf8.encode(jsonString);
      await instance.putFile(
        cacheKey,
        bytes,
        fileExtension: 'json',
        maxAge: maxAge,
      );
    } catch (_) {
      // Gracefully ignore cache write failures
    }
  }

  /// Get cached JSON string, if available
  static Future<String?> getJson(String cacheKey) async {
    try {
      final fileInfo = await instance.getFileFromCache(cacheKey);
      if (fileInfo != null && await fileInfo.file.exists()) {
        return await fileInfo.file.readAsString();
      }
    } catch (_) {
      // Gracefully ignore cache read failures
    }
    return null;
  }

  /// Invalidate/remove cache item
  static Future<void> remove(String cacheKey) async {
    try {
      await instance.removeFile(cacheKey);
    } catch (_) {}
  }

  /// Clear all cached chats & history
  static Future<void> emptyCache() async {
    try {
      await instance.emptyCache();
    } catch (_) {}
  }
}
