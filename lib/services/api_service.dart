import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import '../models/models.dart';
import '../openinsitute_core.dart';
import '../utils/dio.dart';
import '../utils/error_handler.dart';
import 'chat_cache_manager.dart';
import 'chat_socket_service.dart';
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
  Future<List<ServerCategoryModel>> fetchServerCategories();
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
  Future<List<ChatMessage>> fetchUserChatMessages(String channelId);
  Future<List<ChatMessage>> fetchServerChatMessages(
    String channelId, {
    String? serverId,
    String? baseUrl,
  });
  Future<List<FileItemModel>> fetchFiles({String? serverId});
  Future<List<GoalItemModel>> fetchServerGoals(String serverId);
  Future<List<TransactionItemModel>> fetchServerTransactions(String serverId);
  Future<List<BlogPostModel>> fetchServerBlogPosts(String serverId);
  Future<List<EmeProfileModel>> searchUsers(String query);
  Future<List<EmeProfileModel>> fetchUsers();

  /// Loads a project (`librarycollection`) with its team. Throws when the
  /// server is unreachable or the collection is not found.
  Future<LibraryCollectionModel> fetchProjectCollection(
    String collectionId, {
    String? baseUrl,
  });

  /// Projects the signed-in user is on the team of
  /// (`librarycollection/viewprojects.json`).
  Future<List<LibraryCollectionModel>> fetchUserProjects();

  /// Opens the project's team chat channel, the same one the web project chat
  /// page uses (`librarycollection/connectchat.json`). [params] are sent along
  /// (form submissions).
  Future<ProjectChatConnection> connectProjectChat(
    String collectionId, {
    Map<String, dynamic>? params,
  });

  /// Follows or unfollows the project for the signed-in user
  /// (`librarycollection/togglefollow.json`).
  Future<ProjectFollowState> toggleProjectFollow(String collectionId);

  /// Puts a user on the project's team: an existing user by [userId], or by
  /// [email] (creating the user if needed). Editors only
  /// (`librarycollection/addteammember.json`).
  Future<void> addProjectTeamMember(
    String collectionId, {
    String? userId,
    String? email,
    String? firstName,
    String? lastName,
  });

  /// Creates a project owned by the signed-in user, who is put on its team
  /// (`librarycollection/create.json`), and returns it. [logo] becomes the
  /// project's portrait. Throws the server's error when it refuses.
  Future<LibraryCollectionModel> createProject({
    required String name,
    String? description,
    String? urlName,
    List<String> tags = const [],
    MultipartFile? logo,
  });

  /// Saves the project's details (`librarycollection/update.json`) and
  /// returns the project. Only the project's owner (or an administrator) may;
  /// throws the server's error otherwise. An empty [description] or [tags]
  /// clears them.
  Future<LibraryCollectionModel> updateProject(
    String collectionId, {
    required String name,
    String? description,
    String? urlName,
    List<String> tags = const [],
  });

  /// Users that can still be added to the project's team: enabled users not
  /// already on it, optionally narrowed by [query]. Editors only
  /// (`librarycollection/teamcandidates.json`).
  Future<List<EmeProfileModel>> fetchTeamCandidates(
    String collectionId, {
    String? query,
  });

  /// Roles a team member can have (`librarycollection/teamroles.json`).
  Future<List<ProjectTeamRole>> fetchTeamRoles();

  /// Changes a team membership: on/off the team and its roles. Needs
  /// `canviewsettings` (`librarycollection/updateteammember.json`).
  Future<void> updateProjectTeamMember(
    String collectionId, {
    required String memberId,
    bool? onTheTeam,
    List<String>? roleIds,
  });

  /// One search across people, projects, EME servers and events
  /// (`emesearch/search.json`). [types] limits what is searched (all when
  /// null); [category] is an EME server category id, and leaves out projects
  /// and events, which have no category.
  Future<SearchResults> search({
    String? query,
    Set<SearchType>? types,
    String? category,
  });

  /// Entity assets (`entityasset/assets.json`), newest first: those of the
  /// project [collectionId], else of the EME profile owned by the user [userId] (the signed-in
  /// user when both are null). [query] filters by name.
  Future<List<EntityAssetModel>> fetchEntityAssets({
    String? userId,
    String? collectionId,
    String? query,
  });

  /// Conversion state of one asset and, once ready, its [size] thumbnail
  /// URL (`entityasset/previewstatus.json`), for polling after an upload.
  Future<AssetPreviewStatus> fetchAssetPreviewStatus(
    String assetId, {
    String size = 'image200x200',
  });

  /// Uploads [file] as a new entity asset of the project [collectionId], else
  /// of the signed-in user's profile (`entityasset/upload.json`). Throws the
  /// server's error when it refuses the file.
  Future<void> uploadEntityAsset(
    MultipartFile file, {
    String? collectionId,
    String? name,
    String? description,
    List<String> tags = const [],
  });

  /// Events (`emeevent/events.json`), newest start first. [query] filters by
  /// name; [rsvpedOnly] keeps the events the signed-in user answered.
  Future<List<EventModel>> fetchEvents({
    String? query,
    bool rsvpedOnly = false,
  });

  /// One event with its counts and the user's response.
  Future<EventModel> fetchEvent(String eventId);

  /// Sets (or with [EventRsvp.none] clears) the user's response
  /// (`emeevent/rsvp.json`).
  Future<EventRsvpResult> setEventRsvp(String eventId, EventRsvp rsvp);

  /// Opens the EME Server's chat channel and returns its id
  /// (`chat/connect.json`). [params] carry a tapped action's data, which can
  /// move the chat to another channel.
  Future<String> connectServerChat(
    String serverId, {
    Map<String, dynamic>? params,
  });

  /// Opens the event's chat channel and returns its id
  /// (`emeevent/connectchat.json`).
  Future<String> connectEventChat(String eventId);

  /// Creates a public event hosted by the signed-in user
  /// (`emeevent/create.json`) and returns it.
  Future<EventModel> createEvent({
    required String name,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
    String? location,
  });
}

/// Concrete implementation of the API Service
class ApiService implements IApiService {
  final ApiConfig config;
  final Dio _dio;

  ApiService({ApiConfig? config, Dio? dio})
    : config = config ?? const ApiConfig(),
      _dio = dio ?? DioUtil.dio;

  String get _cleanBaseUrl {
    var baseUri = config.baseUrl.trim();
    if (baseUri.isEmpty) {
      baseUri = (OpenI.instance?.settings.mediadb ?? '').trim();
    }
    if (baseUri.isEmpty) {
      baseUri = '/site/mediadb';
    }
    if (baseUri.endsWith('/')) {
      baseUri = baseUri.substring(0, baseUri.length - 1);
    }
    return baseUri;
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
  Future<List<ServerCategoryModel>> fetchServerCategories() async {
    final cleanBase = _cleanBaseUrl;
    if (cleanBase.isEmpty) return [];
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final primaryUrl = '$cleanBase/services/module/emeserver/categories.json';

    debugPrint('[ApiService] fetchServerCategories GET URL: $primaryUrl');
    try {
      final dio = _dio;
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
        'X-tokentype': 'entermedia',
        if (token != null && token.isNotEmpty) ...{
          'Authorization': 'Bearer $token',
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

      debugPrint(
        '[ApiService] fetchServerCategories response [${response.statusCode}]: ${response.data}',
      );

      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      List<dynamic>? rawList;
      if (data is Map<String, dynamic>) {
        rawList = (data['categories'] ?? data['data']) as List<dynamic>?;
      } else if (data is List<dynamic>) {
        rawList = data;
      }

      if (rawList != null) {
        final List<ServerCategoryModel> result = [];
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            final id = item['id']?.toString().trim();
            final name = item['name']?.toString().trim();
            if (name != null && name.isNotEmpty) {
              final cat = ServerCategoryModel(
                id: (id != null && id.isNotEmpty) ? id : name,
                name: name,
              );
              if (!result.any((c) => c.id == cat.id)) {
                result.add(cat);
              }
            }
          } else if (item is String) {
            final trimmed = item.trim();
            if (trimmed.isNotEmpty && !result.any((c) => c.name == trimmed)) {
              result.add(ServerCategoryModel(id: trimmed, name: trimmed));
            }
          }
        }
        return result;
      }
    } catch (e, stack) {
      debugPrint('[ApiService] fetchServerCategories network error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.fetchServerCategories failed',
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
        },
      };

      final response = await dio.post(
        primaryUrl,
        queryParameters: {'serverid': serverId},
        data: {'serverid': serverId},
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

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        if (data is Map<String, dynamic>) {
          final resp = data['response'];
          if (resp is Map<String, dynamic>) {
            final respSuccess = resp['success'];
            final respStatus = resp['status']?.toString().toLowerCase();
            if (respSuccess == false ||
                respSuccess == 'false' ||
                respStatus == 'error') {
              final errMsg =
                  resp['message'] ?? resp['error'] ?? 'Join server failed';
              throw Exception(errMsg);
            }
            if (respSuccess == true ||
                respSuccess == 'true' ||
                respStatus == 'ok') {
              return true;
            }
          }
          final topSuccess = data['success'];
          final topStatus = data['status']?.toString().toLowerCase();
          if (topSuccess == false ||
              topSuccess == 'false' ||
              topStatus == 'error') {
            final errMsg =
                data['message'] ?? data['error'] ?? 'Join server failed';
            throw Exception(errMsg);
          }
          if (topSuccess == true || topSuccess == 'true' || topStatus == 'ok') {
            return true;
          }
        }
        return true;
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e, stack) {
      debugPrint('[ApiService] joinServer error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.joinServer failed',
        customKeys: {'url': primaryUrl, 'serverid': serverId},
      );
      rethrow;
    }
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

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        if (data is Map<String, dynamic>) {
          final resp = data['response'];
          if (resp is Map<String, dynamic>) {
            final respSuccess = resp['success'];
            final respStatus = resp['status']?.toString().toLowerCase();
            if (respSuccess == false ||
                respSuccess == 'false' ||
                respStatus == 'error') {
              final errMsg =
                  resp['message'] ?? resp['error'] ?? 'Leave server failed';
              throw Exception(errMsg);
            }
            if (respSuccess == true ||
                respSuccess == 'true' ||
                respStatus == 'ok') {
              return true;
            }
          }
          final topSuccess = data['success'];
          final topStatus = data['status']?.toString().toLowerCase();
          if (topSuccess == false ||
              topSuccess == 'false' ||
              topStatus == 'error') {
            final errMsg =
                data['message'] ?? data['error'] ?? 'Leave server failed';
            throw Exception(errMsg);
          }
          if (topSuccess == true || topSuccess == 'true' || topStatus == 'ok') {
            return true;
          }
        }
        return true;
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e, stack) {
      debugPrint('[ApiService] leaveServer error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.leaveServer failed',
        customKeys: {'url': primaryUrl, 'serverid': serverId},
      );
      rethrow;
    }
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
    final cacheKey = ChatCacheManager.chatListKey(cleanBase);
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
      String? rawJsonString;
      if (data is String && data.trim().isNotEmpty) {
        rawJsonString = data;
        try {
          data = jsonDecode(data);
        } catch (_) {}
      } else if (data != null) {
        try {
          rawJsonString = jsonEncode(data);
        } catch (_) {}
      }

      List<ChatModel> result = [];
      if (data is Map<String, dynamic>) {
        final chatsList = (data['chats'] as List<dynamic>?) ?? [];
        result = chatsList
            .map((item) => ChatModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (data is List<dynamic>) {
        result = data
            .map((item) => ChatModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      if (rawJsonString != null) {
        unawaited(ChatCacheManager.putJson(cacheKey, rawJsonString));
      }
      return result;
    } catch (e, stack) {
      debugPrint('[ApiService] fetchChats network error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.fetchChats failed',
        customKeys: {'url': primaryUrl},
      );

      // Attempt to load from cache
      final cachedJson = await ChatCacheManager.getJson(cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson);
          if (decoded is Map<String, dynamic>) {
            final chatsList = (decoded['chats'] as List<dynamic>?) ?? [];
            return chatsList
                .map((item) => ChatModel.fromJson(item as Map<String, dynamic>))
                .toList();
          } else if (decoded is List<dynamic>) {
            return decoded
                .map((item) => ChatModel.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        } catch (_) {}
      }
    }
    return [];
  }

  @override
  Future<List<ChatMessage>> fetchUserChatMessages(String channelId) async {
    final cleanBase = _cleanBaseUrl;
    if (cleanBase.isEmpty) return [];
    final cacheKey = ChatCacheManager.userChatHistoryKey(cleanBase, channelId);
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
      String? rawJsonString;
      if (data is String && data.trim().isNotEmpty) {
        rawJsonString = data;
        try {
          data = jsonDecode(data);
        } catch (_) {}
      } else if (data != null) {
        try {
          rawJsonString = jsonEncode(data);
        } catch (_) {}
      }

      List<ChatMessage> result = [];
      if (data is Map<String, dynamic>) {
        final messagesList = (data['messages'] as List<dynamic>?) ?? [];
        result = messagesList
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (data is List<dynamic>) {
        result = data
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      if (rawJsonString != null) {
        unawaited(ChatCacheManager.putJson(cacheKey, rawJsonString));
      }
      return result;
    } catch (e, stack) {
      debugPrint('[ApiService] fetchChatMessages error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.fetchChatMessages failed',
        customKeys: {'url': primaryUrl, 'channelId': channelId},
      );

      // Attempt to load from cache
      final cachedJson = await ChatCacheManager.getJson(cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson);
          if (decoded is Map<String, dynamic>) {
            final messagesList = (decoded['messages'] as List<dynamic>?) ?? [];
            return messagesList
                .map(
                  (item) => ChatMessage.fromJson(item as Map<String, dynamic>),
                )
                .toList();
          } else if (decoded is List<dynamic>) {
            return decoded
                .map(
                  (item) => ChatMessage.fromJson(item as Map<String, dynamic>),
                )
                .toList();
          }
        } catch (_) {}
      }
    }
    return [];
  }

  @override
  Future<List<ChatMessage>> fetchServerChatMessages(
    String channelId, {
    String? serverId,
    String? baseUrl,
  }) async {
    final cleanBase = (baseUrl != null && baseUrl.isNotEmpty)
        ? (baseUrl.endsWith('/')
              ? baseUrl.substring(0, baseUrl.length - 1)
              : baseUrl)
        : _cleanBaseUrl;
    if (cleanBase.isEmpty) return [];
    final cacheKey = ChatCacheManager.serverChatHistoryKey(
      cleanBase,
      channelId,
      serverId: serverId,
    );
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final primaryUrl = '$cleanBase/services/chat/chat.json';

    final queryParams = <String, dynamic>{
      'channel': channelId,
      if (serverId != null && serverId.isNotEmpty) 'serverid': serverId,
    };

    debugPrint(
      '[ApiService] fetchServerChatMessages GET URL: $primaryUrl with params: $queryParams',
    );
    try {
      final dio = _dio;
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
        'X-tokentype': 'entermedia',
        if (token != null && token.isNotEmpty) ...{
          'Authorization': 'Bearer $token',
        },
      };

      Response response = await dio.get(
        primaryUrl,
        queryParameters: queryParams,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint(
        '[ApiService] fetchServerChatMessages response [${response.statusCode}]: ${response.data}',
      );

      dynamic data = response.data;
      String? rawJsonString;
      if (data is String && data.trim().isNotEmpty) {
        rawJsonString = data;
        try {
          data = jsonDecode(data);
        } catch (_) {}
      } else if (data != null) {
        try {
          rawJsonString = jsonEncode(data);
        } catch (_) {}
      }

      List<ChatMessage> result = [];
      if (data is Map<String, dynamic>) {
        final messagesList =
            (data['messages'] as List<dynamic>?) ??
            (data['data'] as List<dynamic>?) ??
            (data['results'] as List<dynamic>?) ??
            [];
        result = messagesList
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (data is List<dynamic>) {
        result = data
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      if (rawJsonString != null) {
        unawaited(ChatCacheManager.putJson(cacheKey, rawJsonString));
      }
      return result;
    } catch (e, stack) {
      debugPrint('[ApiService] fetchServerChatMessages error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.fetchServerChatMessages failed',
        customKeys: {
          'url': primaryUrl,
          'channelId': channelId,
          'serverId': serverId ?? '',
        },
      );

      // Attempt to load from cache
      final cachedJson = await ChatCacheManager.getJson(cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson);
          final messagesList = (decoded is Map<String, dynamic>)
              ? ((decoded['messages'] as List<dynamic>?) ??
                    (decoded['data'] as List<dynamic>?) ??
                    (decoded['results'] as List<dynamic>?) ??
                    [])
              : (decoded is List<dynamic> ? decoded : []);
          return messagesList
              .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
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

  // ==========================================
  // 10. PROJECTS (librarycollection)
  // ==========================================

  /// GETs a `librarycollection` service and returns the decoded JSON map.
  /// Throws on network errors or a non-map response.
  Future<Map<String, dynamic>> _getProjectJson(
    String path, {
    String? baseUrl,
    Map<String, dynamic>? query,
    required String reason,
  }) => _getModuleJson(
    'librarycollection',
    path,
    baseUrl: baseUrl,
    query: query,
    reason: reason,
  );

  /// GETs a `services/module/<module>/<path>` service and returns the decoded
  /// JSON map. Throws on network errors or a non-map response.
  Future<Map<String, dynamic>> _getModuleJson(
    String module,
    String path, {
    String? baseUrl,
    Map<String, dynamic>? query,
    required String reason,
  }) async {
    final cleanBase = (baseUrl != null && baseUrl.isNotEmpty)
        ? (baseUrl.endsWith('/')
              ? baseUrl.substring(0, baseUrl.length - 1)
              : baseUrl)
        : _cleanBaseUrl;
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final primaryUrl = '$cleanBase/services/module/$module/$path';

    debugPrint('[ApiService] $reason GET URL: $primaryUrl $query');
    try {
      final response = await _dio.get(
        primaryUrl,
        queryParameters: query,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) {
        data = jsonDecode(data);
      }
      if (data is Map<String, dynamic>) return data;
      throw Exception('$reason: unexpected response');
    } catch (e, stack) {
      debugPrint('[ApiService] $reason error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.$reason failed',
        customKeys: {'url': primaryUrl, ...?query},
      );
      rethrow;
    }
  }

  static String? _responseStatus(Map<String, dynamic> data) {
    final response = data['response'];
    return response is Map ? response['status']?.toString() : null;
  }

  @override
  Future<LibraryCollectionModel> fetchProjectCollection(
    String collectionId, {
    String? baseUrl,
  }) async {
    final data = await _getProjectJson(
      'data/${Uri.encodeComponent(collectionId)}',
      baseUrl: baseUrl,
      reason: 'fetchProjectCollection',
    );
    final hit = data['data'];
    if (hit is Map<String, dynamic>) {
      return LibraryCollectionModel.fromJson(hit);
    }
    throw Exception(
      'Project $collectionId: ${_responseStatus(data) ?? 'no data'}',
    );
  }

  @override
  Future<List<LibraryCollectionModel>> fetchUserProjects() async {
    final data = await _getProjectJson(
      'viewprojects.json',
      reason: 'fetchUserProjects',
    );
    final results = data['results'];
    if (results is! List) {
      throw Exception('Projects: ${_responseStatus(data) ?? 'no results'}');
    }
    return results
        .whereType<Map<String, dynamic>>()
        .map(LibraryCollectionModel.fromJson)
        .toList();
  }

  @override
  Future<ProjectChatConnection> connectProjectChat(
    String collectionId, {
    Map<String, dynamic>? params,
  }) async {
    final data = await _getProjectJson(
      'connectchat.json',
      query: {...?params, 'collectionid': collectionId},
      reason: 'connectProjectChat',
    );
    final connection = ProjectChatConnection.fromJson(data);
    if (connection.channelId.isEmpty) {
      throw Exception(
        'Project chat $collectionId: ${_responseStatus(data) ?? 'no channel'}',
      );
    }
    return connection;
  }

  @override
  Future<ProjectFollowState> toggleProjectFollow(String collectionId) async {
    final data = await _getProjectJson(
      'togglefollow.json',
      query: {'collectionid': collectionId},
      reason: 'toggleProjectFollow',
    );
    if (_responseStatus(data) != 'ok') {
      throw Exception(
        'Follow $collectionId: ${_responseStatus(data) ?? 'failed'}',
      );
    }
    return ProjectFollowState.fromJson(data);
  }

  @override
  Future<void> addProjectTeamMember(
    String collectionId, {
    String? userId,
    String? email,
    String? firstName,
    String? lastName,
  }) async {
    final data = await _getProjectJson(
      'addteammember.json',
      query: {
        'collectionid': collectionId,
        'userid': ?userId,
        'email': ?email,
        'firstName': ?firstName,
        'lastName': ?lastName,
      },
      reason: 'addProjectTeamMember',
    );
    if (_responseStatus(data) != 'ok') {
      final response = data['response'];
      final error = response is Map ? response['error'] : null;
      throw Exception(error ?? 'Could not add team member');
    }
  }

  @override
  Future<LibraryCollectionModel> createProject({
    required String name,
    String? description,
    String? urlName,
    List<String> tags = const [],
    MultipartFile? logo,
  }) async {
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final url = '$_cleanBaseUrl/services/module/librarycollection/create.json';
    // The server reads `field` names and their `<field>.value`s; the logo is
    // the file named after the asset field it fills.
    final form = FormData();
    void addField(String field, Iterable<String> values) {
      form.fields.add(MapEntry('field', field));
      for (final value in values) {
        form.fields.add(MapEntry('$field.value', value));
      }
    }

    addField('name', [name.trim()]);
    final desc = description?.trim() ?? '';
    if (desc.isNotEmpty) addField('collectivedescription', [desc]);
    final slug = urlName?.trim() ?? '';
    if (slug.isNotEmpty) addField('urlname', [slug]);
    if (tags.isNotEmpty) addField('collectivetags', tags);
    // Not listed as a `field`: the server attaches the uploaded asset itself,
    // and a listed field with no value would blank it again.
    if (logo != null) form.files.add(MapEntry('assetportrait', logo));

    debugPrint('[ApiService] createProject POST URL: $url');
    try {
      final response = await _dio.post(
        url,
        data: form,
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 1),
        ),
      );
      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) data = jsonDecode(data);
      if (data is! Map<String, dynamic>) {
        throw Exception('Create project: unexpected response');
      }
      if (_responseStatus(data) != 'ok') {
        final error = (data['response'] as Map?)?['error'];
        throw Exception('Create project: ${error ?? 'failed'}');
      }
      final id = (data['response'] as Map)['id']?.toString() ?? '';
      if (id.isEmpty) throw Exception('Create project: no project id');
      return await fetchProjectCollection(id);
    } catch (e, stack) {
      debugPrint('[ApiService] createProject error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.createProject failed',
        customKeys: {'url': url},
      );
      rethrow;
    }
  }

  @override
  Future<LibraryCollectionModel> updateProject(
    String collectionId, {
    required String name,
    String? description,
    String? urlName,
    List<String> tags = const [],
  }) async {
    final fields = <String, List<String>>{
      'name': [name.trim()],
      'collectivedescription': [description?.trim() ?? ''],
      if ((urlName?.trim() ?? '').isNotEmpty) 'urlname': [urlName!.trim()],
      'collectivetags': tags,
    };
    final data = await _getProjectJson(
      'update.json',
      query: {
        'collectionid': collectionId,
        'field': fields.keys.toList(),
        for (final e in fields.entries) '${e.key}.value': e.value,
      },
      reason: 'updateProject',
    );
    if (_responseStatus(data) != 'ok') {
      final error = (data['response'] as Map?)?['error'];
      throw Exception('Update project: ${error ?? 'failed'}');
    }
    return fetchProjectCollection(collectionId);
  }

  @override
  Future<List<EmeProfileModel>> fetchTeamCandidates(
    String collectionId, {
    String? query,
  }) async {
    final data = await _getProjectJson(
      'teamcandidates.json',
      query: {
        'collectionid': collectionId,
        if (query != null && query.isNotEmpty) 'query': query,
      },
      reason: 'fetchTeamCandidates',
    );
    final users = data['users'];
    if (users is! List) {
      final response = data['response'];
      final error = response is Map ? response['error'] : null;
      throw Exception(error ?? 'Team candidates: no users');
    }
    return users
        .whereType<Map<String, dynamic>>()
        .map(EmeProfileModel.fromUserJson)
        .toList();
  }

  @override
  Future<List<ProjectTeamRole>> fetchTeamRoles() async {
    final data = await _getProjectJson(
      'teamroles.json',
      reason: 'fetchTeamRoles',
    );
    final roles = data['roles'];
    if (roles is! List) {
      throw Exception('Team roles: ${_responseStatus(data) ?? 'no roles'}');
    }
    return roles
        .whereType<Map<String, dynamic>>()
        .map(ProjectTeamRole.fromJson)
        .toList();
  }

  @override
  Future<void> updateProjectTeamMember(
    String collectionId, {
    required String memberId,
    bool? onTheTeam,
    List<String>? roleIds,
  }) async {
    final data = await _getProjectJson(
      'updateteammember.json',
      query: {
        'collectionid': collectionId,
        'memberid': memberId,
        'ontheteam': ?onTheTeam?.toString(),
        'teamroles': ?roleIds?.join(','),
      },
      reason: 'updateProjectTeamMember',
    );
    if (_responseStatus(data) != 'ok') {
      final response = data['response'];
      final error = response is Map ? response['error'] : null;
      throw Exception(error ?? 'Could not update team member');
    }
  }

  // ==========================================
  // UNIFIED SEARCH
  // ==========================================

  @override
  Future<SearchResults> search({
    String? query,
    Set<SearchType>? types,
    String? category,
  }) async {
    final data = await _getModuleJson(
      'emesearch',
      'search.json',
      query: {
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        if (types != null && types.isNotEmpty)
          'types': types.map((t) => t.name).join(','),
        if (category != null && category.trim().isNotEmpty && category != 'All')
          'category': category.trim(),
      },
      reason: 'search',
    );
    if (_responseStatus(data) != 'ok') {
      throw Exception('Search: ${_responseStatus(data) ?? 'no response'}');
    }
    return SearchResults.fromJson(data);
  }

  // ==========================================
  // EVENTS
  // ==========================================

  @override
  Future<List<EntityAssetModel>> fetchEntityAssets({
    String? userId,
    String? collectionId,
    String? query,
  }) async {
    final data = await _getModuleJson(
      'entityasset',
      'assets.json',
      query: {
        'collectionid': ?collectionId,
        'userid': ?userId,
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      },
      reason: 'fetchEntityAssets',
    );
    final assets = data['assets'];
    if (assets is! List) {
      final response = data['response'];
      final error = response is Map ? response['error'] : null;
      throw Exception(error ?? 'Entity assets: no assets');
    }
    return assets
        .whereType<Map<String, dynamic>>()
        .map(EntityAssetModel.fromJson)
        .toList();
  }

  @override
  Future<AssetPreviewStatus> fetchAssetPreviewStatus(
    String assetId, {
    String size = 'image200x200',
  }) async {
    final data = await _getModuleJson(
      'entityasset',
      'previewstatus.json',
      query: {'assetid': assetId, 'size': size},
      reason: 'fetchAssetPreviewStatus',
    );
    if (_responseStatus(data) != 'ok') {
      final error = (data['response'] as Map?)?['error'];
      throw Exception(error ?? 'Preview status: unexpected response');
    }
    return AssetPreviewStatus.fromJson(data);
  }

  @override
  Future<void> uploadEntityAsset(
    MultipartFile file, {
    String? collectionId,
    String? name,
    String? description,
    List<String> tags = const [],
  }) async {
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final url = '$_cleanBaseUrl/services/module/entityasset/upload.json';
    final form = FormData();
    if (collectionId != null) {
      form.fields.add(MapEntry('collectionid', collectionId));
    }
    if (name != null && name.trim().isNotEmpty) {
      form.fields.add(MapEntry('name', name.trim()));
    }
    if (description != null && description.trim().isNotEmpty) {
      form.fields.add(MapEntry('longdescription', description.trim()));
    }
    for (final tag in tags) {
      form.fields.add(MapEntry('tags', tag));
    }
    form.files.add(MapEntry('file', file));

    debugPrint('[ApiService] uploadEntityAsset POST URL: $url');
    try {
      final response = await _dio.post(
        url,
        data: form,
        // Also in the URL: unlike multipart form fields, query parameters need
        // no parsing on the server, so the target can never be missed.
        queryParameters: {'collectionid': ?collectionId},
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      dynamic data = response.data;
      if (data is String && data.trim().isNotEmpty) data = jsonDecode(data);
      if (data is! Map<String, dynamic>) {
        throw Exception('Upload: unexpected response');
      }
      if (_responseStatus(data) != 'ok') {
        final error = (data['response'] as Map?)?['error'];
        throw Exception(error ?? 'Upload failed');
      }
    } catch (e, stack) {
      debugPrint('[ApiService] uploadEntityAsset error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.uploadEntityAsset failed',
        customKeys: {'url': url},
      );
      rethrow;
    }
  }

  @override
  Future<List<EventModel>> fetchEvents({
    String? query,
    bool rsvpedOnly = false,
  }) async {
    final data = await _getModuleJson(
      'emeevent',
      'events.json',
      query: {
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        if (rsvpedOnly) 'rsvped': 'true',
      },
      reason: 'fetchEvents',
    );
    final events = data['events'];
    if (events is! List) {
      throw Exception('Events: ${_responseStatus(data) ?? 'no events'}');
    }
    return events
        .whereType<Map<String, dynamic>>()
        .map(EventModel.fromJson)
        .toList();
  }

  @override
  Future<EventModel> fetchEvent(String eventId) async {
    final data = await _getModuleJson(
      'emeevent',
      'events.json',
      query: {'eventid': eventId},
      reason: 'fetchEvent',
    );
    final events = data['events'];
    if (events is List && events.isNotEmpty && events.first is Map) {
      return EventModel.fromJson(
        Map<String, dynamic>.from(events.first as Map),
      );
    }
    throw Exception('Event $eventId: not found');
  }

  @override
  Future<EventRsvpResult> setEventRsvp(String eventId, EventRsvp rsvp) async {
    final data = await _getModuleJson(
      'emeevent',
      'rsvp.json',
      query: {'eventid': eventId, 'status': rsvp.name},
      reason: 'setEventRsvp',
    );
    if (_responseStatus(data) != 'ok') {
      final error = (data['response'] as Map?)?['error'];
      throw Exception('RSVP $eventId: ${error ?? 'failed'}');
    }
    return EventRsvpResult.fromJson(data);
  }

  @override
  Future<String> connectServerChat(
    String serverId, {
    Map<String, dynamic>? params,
  }) {
    return ChatSocketService().connectChat(serverId, params: params);
  }

  @override
  Future<String> connectEventChat(String eventId) async {
    final data = await _getModuleJson(
      'emeevent',
      'connectchat.json',
      query: {'eventid': eventId},
      reason: 'connectEventChat',
    );
    final channel = data['channel']?.toString() ?? '';
    if (channel.isEmpty) {
      throw Exception(
        'Event chat $eventId: ${_responseStatus(data) ?? 'no channel'}',
      );
    }
    return channel;
  }

  /// ISO 8601 with the UTC offset, the format `emeevent/create.json` parses.
  static String _isoWithOffset(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
        '${two(local.day)}T${two(local.hour)}:${two(local.minute)}:'
        '${two(local.second)}$sign${two(abs.inHours)}:'
        '${two(abs.inMinutes.remainder(60))}';
  }

  @override
  Future<EventModel> createEvent({
    required String name,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
    String? location,
  }) async {
    final data = await _getModuleJson(
      'emeevent',
      'create.json',
      query: {
        'name': name,
        'startdate': _isoWithOffset(startDate),
        if (endDate != null) 'enddate': _isoWithOffset(endDate),
        if (description != null && description.isNotEmpty)
          'eventdescription': description,
        if (location != null && location.isNotEmpty) 'eventlocation': location,
      },
      reason: 'createEvent',
    );
    if (_responseStatus(data) != 'ok') {
      final error = (data['response'] as Map?)?['error'];
      throw Exception('Create event: ${error ?? 'failed'}');
    }
    final eventId = data['eventid']?.toString() ?? '';
    if (eventId.isEmpty) throw Exception('Create event: no event id');
    return fetchEvent(eventId);
  }
}
