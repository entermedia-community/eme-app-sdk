import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:eme_app_sdk/eme_app_sdk.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    hide FileSystem;
import 'package:flutter_test/flutter_test.dart';

class FakeCacheManager implements BaseCacheManager {
  final FileSystem _fs = MemoryFileSystem();
  final Map<String, FileInfo> _store = {};

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async {
    return _store[key];
  }

  @override
  Future<File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    final cacheKey = key ?? url;
    final file = _fs.file('/cache/$cacheKey.$fileExtension')
      ..createSync(recursive: true);
    file.writeAsBytesSync(fileBytes);
    final fileInfo = FileInfo(
      file,
      FileSource.Cache,
      DateTime.now().add(maxAge),
      url,
    );
    _store[cacheKey] = fileInfo;
    return file;
  }

  @override
  Future<void> removeFile(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> emptyCache() async {
    _store.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCacheManager fakeCache;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeCache = FakeCacheManager();
    ChatCacheManager.customInstance = fakeCache;
  });

  tearDown(() {
    ChatCacheManager.customInstance = null;
  });

  group('ChatCacheManager & ApiService Cache Tests', () {
    test('ChatCacheManager generates distinct keys', () {
      final listKey = ChatCacheManager.chatListKey('http://localhost:8080');
      final userKey = ChatCacheManager.userChatHistoryKey(
        'http://localhost:8080',
        'chan_123',
      );
      final serverKey = ChatCacheManager.serverChatHistoryKey(
        'http://localhost:8080',
        'chan_123',
        serverId: 'srv_1',
      );

      expect(listKey, contains('chats_list_'));
      expect(userKey, contains('chat_history_user_'));
      expect(serverKey, contains('chat_history_server_'));
      expect(serverKey, contains('srv_1'));
    });

    test(
      'ApiService falls back to cached chat list when network request fails',
      () async {
        const baseUrl = 'http://mock-cache-test.local';
        final cacheKey = ChatCacheManager.chatListKey(baseUrl);

        final dummyChatJson = jsonEncode({
          'chats': [
            {
              'channel': 'ch_cached_1',
              'username': 'cached_user',
              'firstname': 'Cached',
              'lastname': 'User',
              'lastmessage': {
                'message': 'Hello from cache',
                'date': '2026-01-01T10:00:00Z',
              },
              'unreadmessagecount': 2,
            },
          ],
        });

        // Seed cache
        await ChatCacheManager.putJson(cacheKey, dummyChatJson);

        // Create ApiService with a Dio instance that always rejects/fails network
        final failingDio = Dio();
        failingDio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  error: 'Network offline',
                ),
              );
            },
          ),
        );

        final api = ApiService(
          config: const ApiConfig(baseUrl: baseUrl),
          dio: failingDio,
        );

        // fetchChats should fail over network and load the cached chat list
        final chats = await api.fetchChats();

        expect(chats, isNotEmpty);
        expect(chats.first.channelId, equals('ch_cached_1'));
        expect(chats.first.displayName, equals('Cached User'));
        expect(chats.first.lastMessage, equals('Hello from cache'));
        expect(chats.first.unreadCount, equals(2));
      },
    );

    test(
      'ApiService falls back to cached user chat history when network fails',
      () async {
        const baseUrl = 'http://mock-cache-test.local';
        const channelId = 'ch_user_msg_cached';
        final cacheKey = ChatCacheManager.userChatHistoryKey(
          baseUrl,
          channelId,
        );

        final dummyMessagesJson = jsonEncode({
          'messages': [
            {
              'id': 'msg_cache_1',
              'channel': channelId,
              'user': 'user1',
              'message': 'Saved message in cache',
              'createdat': '2026-01-01T12:00:00Z',
            },
          ],
        });

        await ChatCacheManager.putJson(cacheKey, dummyMessagesJson);

        final failingDio = Dio();
        failingDio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  error: 'Network offline',
                ),
              );
            },
          ),
        );

        final api = ApiService(
          config: const ApiConfig(baseUrl: baseUrl),
          dio: failingDio,
        );

        final messages = await api.fetchUserChatMessages(channelId);

        expect(messages, isNotEmpty);
        expect(messages.first.messageId, equals('msg_cache_1'));
        expect(messages.first.message, equals('Saved message in cache'));
        expect(messages.first.channel, equals(channelId));
      },
    );

    test(
      'ApiService falls back to cached server chat history when network fails',
      () async {
        const baseUrl = 'http://mock-cache-test.local';
        const channelId = 'ch_server_msg_cached';
        const serverId = 'srv_cached';
        final cacheKey = ChatCacheManager.serverChatHistoryKey(
          baseUrl,
          channelId,
          serverId: serverId,
        );

        final dummyMessagesJson = jsonEncode({
          'messages': [
            {
              'id': 'msg_server_1',
              'channel': channelId,
              'user': 'assistant',
              'message': 'Cached server announcement',
              'createdat': '2026-01-01T14:00:00Z',
            },
          ],
        });

        await ChatCacheManager.putJson(cacheKey, dummyMessagesJson);

        final failingDio = Dio();
        failingDio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  error: 'Network offline',
                ),
              );
            },
          ),
        );

        final api = ApiService(
          config: const ApiConfig(baseUrl: baseUrl),
          dio: failingDio,
        );

        final messages = await api.fetchServerChatMessages(
          channelId,
          serverId: serverId,
          baseUrl: baseUrl,
        );

        expect(messages, isNotEmpty);
        expect(messages.first.messageId, equals('msg_server_1'));
        expect(messages.first.message, equals('Cached server announcement'));
        expect(messages.first.channel, equals(channelId));
      },
    );
  });
}
