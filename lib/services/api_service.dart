import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import '../models/models.dart';
import '../openinsitute_core.dart';
import '../utils/dio.dart';
import '../utils/error_handler.dart';
import 'shared_preferences.dart';

/// Configuration for the API Service
class ApiConfig {
  final String baseUrl;
  final Duration timeout;
  final Duration simulatedDelay;

  const ApiConfig({
    this.baseUrl = '',
    this.timeout = const Duration(seconds: 30),
    this.simulatedDelay = Duration.zero,
  });
}

/// Abstract contract for EME World API operations
abstract class IApiService {
  Future<List<ServerModel>> fetchServers({String? query, String? category});
  Future<ServerModel?> fetchServerById(String id);
  Future<bool> joinServer(String serverId);
  Future<bool> leaveServer(String serverId);
  Future<List<ServerModel>> fetchUserServers();
  Future<List<EmeProfileModel>> fetchSpecialistProfiles();
  Future<ProfileModel> fetchUserProfile({String? userId});
  Future<List<ProductMessageModel>> fetchProducts({
    String? serverId,
    ProductType? type,
  });
  Future<List<ChatModel>> fetchChats();
  Future<List<ChatMessage>> fetchChatMessages(String channelId);
  Future<List<FileItemModel>> fetchFiles({String? serverId});
  Future<List<GoalItemModel>> fetchServerGoals(String serverId);
  Future<List<TransactionItemModel>> fetchServerTransactions(String serverId);
  Future<List<BlogPostModel>> fetchServerBlogPosts(String serverId);
  Future<List<EmeProfileModel>> searchUsers(String query);
  Future<List<EmeProfileModel>> fetchUsers();
}

/// Concrete implementation of the API Service
class ApiService implements IApiService {
  final ApiConfig config;
  final Dio _dio;

  ApiService({ApiConfig? config, Dio? dio})
    : config = config ?? const ApiConfig(),
      _dio = dio ?? DioUtil.dio;

  String get _cleanBaseUrl {
    var base = config.baseUrl.trim();
    if (base.isEmpty) {
      base = (OpenI.instance?.settings.mediadb ?? '').trim();
    }
    if (base.isEmpty) {
      base = 'http://localhost:8080/site/mediadb';
    }
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  /// Helper to perform HTTP GET requests
  Future<dynamic> _get(String path) async {
    if (config.simulatedDelay > Duration.zero) {
      await Future.delayed(config.simulatedDelay);
    }

    final base = _cleanBaseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final url = '$base$cleanPath';
    final response = await _dio.get(
      url,
      options: Options(
        headers: {'Content-Type': 'application/json'},
        sendTimeout: config.timeout,
        receiveTimeout: config.timeout,
      ),
    );

    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      return data;
    } else {
      throw Exception(
        'API error ${response.statusCode}: ${response.statusMessage}',
      );
    }
  }

  // ==========================================
  // 1. SERVERS
  // ==========================================

  @override
  Future<List<ServerModel>> fetchServers({
    String? query,
    String? category,
  }) async {
    final cleanBase = _cleanBaseUrl;
    if (cleanBase.isEmpty) return [];
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final primaryUrl =
        '$cleanBase/services/module/emeserver/getemeservers.json';

    final queryParams = <String, dynamic>{
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      if (category != null && category.trim().isNotEmpty && category != 'All')
        'category': category.trim(),
    };

    debugPrint(
      '[ApiService] fetchServers GET URL: $primaryUrl params: $queryParams',
    );
    try {
      final dio = _dio;
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
        'X-tokentype': 'entermedia',
        if (token != null && token.isNotEmpty) ...{
          'Authorization': 'Bearer $token',
          'entermediakey': token,
        },
      };

      final response = await dio.get(
        primaryUrl,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint(
        '[ApiService] fetchServers response [${response.statusCode}]: ${response.data}',
      );

      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      List<dynamic>? serverList;
      if (data is Map<String, dynamic>) {
        serverList = data['emeservers'] as List<dynamic>?;
      } else if (data is List<dynamic>) {
        serverList = data;
      }

      if (serverList != null) {
        return serverList
            .map((item) => ServerModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e, stack) {
      debugPrint('[ApiService] fetchServers network error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.fetchServers failed',
        customKeys: {'url': primaryUrl},
      );
    }
    return [];
  }

  @override
  Future<ServerModel?> fetchServerById(String id) async {
    final cleanBase = _cleanBaseUrl;
    if (cleanBase.isEmpty || id.isEmpty) return null;
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final primaryUrl = '$cleanBase/services/module/emeserver/getemeserver.json';

    debugPrint(
      '[ApiService] fetchServerById GET URL: $primaryUrl?serverid=$id',
    );
    try {
      final dio = _dio;
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
        'X-tokentype': 'entermedia',
        if (token != null && token.isNotEmpty) ...{
          'Authorization': 'Bearer $token',
          'entermediakey': token,
        },
      };

      final response = await dio.get(
        primaryUrl,
        queryParameters: {'serverid': id},
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      if (data is Map<String, dynamic>) {
        final serverMap =
            data['emeserver'] ?? data['server'] ?? data['data'] ?? data;
        if (serverMap is Map<String, dynamic>) {
          return ServerModel.fromJson(serverMap);
        }
      }
    } catch (e, stack) {
      debugPrint('[ApiService] fetchServerById network error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.fetchServerById failed',
        customKeys: {'url': primaryUrl, 'serverid': id},
      );
    }
    return null;
  }

  @override
  Future<bool> joinServer(String serverId) async {
    final cleanBase = _cleanBaseUrl;
    if (cleanBase.isEmpty || serverId.isEmpty) return false;
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final primaryUrl = '$cleanBase/services/module/emeserver/join.json';

    debugPrint(
      '[ApiService] joinServer POST URL: $primaryUrl?serverid=$serverId',
    );
    try {
      final dio = _dio;
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
        'X-tokentype': 'entermedia',
        if (token != null && token.isNotEmpty) ...{
          'Authorization': 'Bearer $token',
          'entermediakey': token,
        },
      };

      final response = await dio.post(
        primaryUrl,
        queryParameters: {'serverid': serverId},
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        if (data is Map<String, dynamic>) {
          final resp = data['response'];
          if (resp is Map<String, dynamic> && resp['status'] == 'error') {
            return false;
          }
        }
        return true;
      }
    } catch (e, stack) {
      debugPrint('[ApiService] joinServer error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.joinServer failed',
        customKeys: {'url': primaryUrl, 'serverid': serverId},
      );
    }
    return false;
  }

  @override
  Future<bool> leaveServer(String serverId) async {
    final cleanBase = _cleanBaseUrl;
    if (cleanBase.isEmpty || serverId.isEmpty) return false;
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final primaryUrl = '$cleanBase/services/module/emeserver/leave.json';

    debugPrint(
      '[ApiService] leaveServer POST URL: $primaryUrl?serverid=$serverId',
    );
    try {
      final dio = _dio;
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
        'X-tokentype': 'entermedia',
        if (token != null && token.isNotEmpty) ...{
          'Authorization': 'Bearer $token',
          'entermediakey': token,
        },
      };

      final response = await dio.post(
        primaryUrl,
        queryParameters: {'serverid': serverId},
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        if (data is Map<String, dynamic>) {
          final resp = data['response'];
          if (resp is Map<String, dynamic> && resp['status'] == 'error') {
            return false;
          }
        }
        return true;
      }
    } catch (e, stack) {
      debugPrint('[ApiService] leaveServer error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.leaveServer failed',
        customKeys: {'url': primaryUrl, 'serverid': serverId},
      );
    }
    return false;
  }

  @override
  Future<List<ServerModel>> fetchUserServers() async {
    final cleanBase = _cleanBaseUrl;
    if (cleanBase.isEmpty) return [];
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final primaryUrl =
        '$cleanBase/services/module/emeserver/getuseremeservers.json';

    debugPrint('[ApiService] fetchUserServers GET URL: $primaryUrl');
    try {
      final dio = _dio;
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
        'X-tokentype': 'entermedia',
        if (token != null && token.isNotEmpty) ...{
          'Authorization': 'Bearer $token',
          'entermediakey': token,
        },
      };

      final response = await dio.get(
        primaryUrl,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      List<dynamic>? serverList;
      if (data is Map<String, dynamic>) {
        serverList =
            (data['emeservers'] ??
                    data['servers'] ??
                    data['results'] ??
                    data['data'])
                as List<dynamic>?;
      } else if (data is List<dynamic>) {
        serverList = data;
      }

      if (serverList != null) {
        return serverList
            .map((item) => ServerModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e, stack) {
      debugPrint('[ApiService] fetchUserServers error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.fetchUserServers failed',
        customKeys: {'url': primaryUrl},
      );
    }
    return [];
  }

  // ==========================================
  // 2. SPECIALIST PROFILES
  // ==========================================

  @override
  Future<List<EmeProfileModel>> fetchSpecialistProfiles() async {
    return fetchUsers();
  }

  @override
  Future<List<EmeProfileModel>> fetchUsers() async {
    final cleanBase = _cleanBaseUrl;
    if (cleanBase.isEmpty) return [];
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final primaryUrl = '$cleanBase/services/module/user/users.json';

    debugPrint('[ApiService] fetchUsers GET URL: $primaryUrl');
    try {
      final dio = _dio;
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
        'X-tokentype': 'entermedia',
        if (token != null && token.isNotEmpty) ...{
          'Authorization': 'Bearer $token',
          'entermediakey': token,
        },
      };

      Response response = await dio.get(
        primaryUrl,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint(
        '[ApiService] fetchUsers response [${response.statusCode}]: ${response.data}',
      );

      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      if (data is Map<String, dynamic>) {
        final usersList = (data['users'] as List<dynamic>?) ?? [];
        return usersList
            .map(
              (item) =>
                  EmeProfileModel.fromUserJson(item as Map<String, dynamic>),
            )
            .toList();
      } else if (data is List<dynamic>) {
        return data
            .map(
              (item) =>
                  EmeProfileModel.fromUserJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (e, stack) {
      debugPrint('[ApiService] fetchUsers network error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.fetchUsers failed',
        customKeys: {'url': primaryUrl},
      );
    }
    return [];
  }

  @override
  Future<List<EmeProfileModel>> searchUsers(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final res = await _get(
        '/services/module/user/usersearch.json?term=${Uri.encodeQueryComponent(cleanQuery)}',
      );

      final usersList = (res['users'] as List<dynamic>?) ?? [];
      return usersList
          .map(
            (item) =>
                EmeProfileModel.fromUserJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ==========================================
  // 3. USER PROFILE
  // ==========================================

  @override
  Future<ProfileModel> fetchUserProfile({String? userId}) async {
    try {
      final res = await _get(userId != null ? '/users/$userId' : '/profile');
      final map = res is Map<String, dynamic>
          ? (res['data'] is Map<String, dynamic> ? res['data'] : res)
          : <String, dynamic>{};
      return ProfileModel.fromJson(map as Map<String, dynamic>);
    } catch (_) {
      return ProfileModel(
        id: userId ?? 'usr_current',
        name: 'Christopher B',
        role: 'Community Lead',
        bio: 'Open source contributor & community lead.',
        tags: const ['Flutter', 'OpenEdit'],
      );
    }
  }

  // ==========================================
  // 4. PRODUCTS & SERVICES CATALOG
  // ==========================================

  @override
  Future<List<ProductMessageModel>> fetchProducts({
    String? serverId,
    ProductType? type,
  }) async {
    final res = await _get('/products');
    final list = res is Map<String, dynamic>
        ? (res['data'] as List<dynamic>? ?? [])
        : (res is List<dynamic> ? res : []);
    var products = list
        .map(
          (item) => ProductMessageModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();

    if (type != null) {
      products = products.where((p) => p.type == type).toList();
    }
    return products;
  }

  // ==========================================
  // 5. CHATS
  // ==========================================

  @override
  Future<List<ChatModel>> fetchChats() async {
    final cleanBase = _cleanBaseUrl;
    if (cleanBase.isEmpty) return [];
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final primaryUrl = '$cleanBase/services/module/user/chats.json';

    debugPrint('[ApiService] fetchChats GET URL: $primaryUrl');
    try {
      final dio = _dio;
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
        'X-tokentype': 'entermedia',
        if (token != null && token.isNotEmpty) ...{
          'Authorization': 'Bearer $token',
          'entermediakey': token,
        },
      };

      Response response = await dio.get(
        primaryUrl,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint(
        '[ApiService] fetchChats response [${response.statusCode}]: ${response.data}',
      );

      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      if (data is Map<String, dynamic>) {
        final chatsList = (data['chats'] as List<dynamic>?) ?? [];
        return chatsList
            .map((item) => ChatModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (data is List<dynamic>) {
        return data
            .map((item) => ChatModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e, stack) {
      debugPrint('[ApiService] fetchChats network error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.fetchChats failed',
        customKeys: {'url': primaryUrl},
      );
    }
    return [];
  }

  @override
  Future<List<ChatMessage>> fetchChatMessages(String channelId) async {
    final cleanBase = _cleanBaseUrl;
    if (cleanBase.isEmpty) return [];
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final primaryUrl = '$cleanBase/services/module/user/chat.json';

    debugPrint(
      '[ApiService] fetchChatMessages GET URL: $primaryUrl?channel=$channelId',
    );
    try {
      final dio = _dio;
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
        'X-tokentype': 'entermedia',
        if (token != null && token.isNotEmpty) ...{
          'Authorization': 'Bearer $token',
          'entermediakey': token,
        },
      };

      Response response = await dio.get(
        primaryUrl,
        queryParameters: {'channel': channelId},
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint(
        '[ApiService] fetchChatMessages response [${response.statusCode}]: ${response.data}',
      );

      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      if (data is Map<String, dynamic>) {
        final messagesList = (data['messages'] as List<dynamic>?) ?? [];
        return messagesList
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (data is List<dynamic>) {
        return data
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e, stack) {
      debugPrint('[ApiService] fetchChatMessages error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.fetchChatMessages failed',
        customKeys: {'url': primaryUrl, 'channelId': channelId},
      );
    }
    return [];
  }

  // ==========================================
  // 6. FILES & ASSETS
  // ==========================================

  @override
  Future<List<FileItemModel>> fetchFiles({String? serverId}) async {
    final res = await _get('/files');
    final list = res is Map<String, dynamic>
        ? (res['data'] as List<dynamic>? ?? [])
        : (res is List<dynamic> ? res : []);
    return list
        .map((item) => FileItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  // 7. SERVER GOALS
  // ==========================================

  @override
  Future<List<GoalItemModel>> fetchServerGoals(String serverId) async {
    final res = await _get('/servers/$serverId/goals');
    final list = res is Map<String, dynamic>
        ? (res['data'] as List<dynamic>? ?? [])
        : (res is List<dynamic> ? res : []);
    return list
        .map((item) => GoalItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  // 8. SERVER TRANSACTIONS & TREASURY
  // ==========================================

  @override
  Future<List<TransactionItemModel>> fetchServerTransactions(
    String serverId,
  ) async {
    final res = await _get('/servers/$serverId/transactions');
    final list = res is Map<String, dynamic>
        ? (res['data'] as List<dynamic>? ?? [])
        : (res is List<dynamic> ? res : []);
    return list
        .map(
          (item) => TransactionItemModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  // ==========================================
  // 9. SERVER BLOG & POSTS
  // ==========================================

  @override
  Future<List<BlogPostModel>> fetchServerBlogPosts(String serverId) async {
    final res = await _get('/servers/$serverId/posts');
    final list = res is Map<String, dynamic>
        ? (res['data'] as List<dynamic>? ?? [])
        : (res is List<dynamic> ? res : []);
    return list
        .map((item) => BlogPostModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
