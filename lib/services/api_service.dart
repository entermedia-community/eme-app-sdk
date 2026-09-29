import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  final bool useMockFallback;
  final Duration simulatedDelay;

  const ApiConfig({
    this.baseUrl = 'http://localhost.com:8080/site/mediadb',
    this.timeout = const Duration(seconds: 10),
    this.useMockFallback = false,
    this.simulatedDelay = const Duration(milliseconds: 350),
  });
}

/// Abstract contract for EME World API operations
abstract class IApiService {
  Future<List<ServerModel>> fetchServers();
  Future<ServerModel?> fetchServerById(String id);
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
  final HttpClient _httpClient;

  ApiService({ApiConfig? config})
    : config = config ?? const ApiConfig(),
      _httpClient = HttpClient() {
    _httpClient.connectionTimeout = (config ?? const ApiConfig()).timeout;
  }

  /// Helper to perform HTTP GET requests with fallback to mock data
  Future<dynamic> _get(
    String path, {
    Map<String, dynamic>? mockFallback,
  }) async {
    if (config.simulatedDelay > Duration.zero) {
      await Future.delayed(config.simulatedDelay);
    }

    if (config.useMockFallback) {
      return mockFallback;
    }

    try {
      final uri = Uri.parse('${config.baseUrl}$path');
      final request = await _httpClient.getUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      final response = await request.close().timeout(config.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = await response.transform(utf8.decoder).join();
        return jsonDecode(responseBody);
      } else {
        throw HttpException(
          'API error ${response.statusCode}: ${response.reasonPhrase}',
          uri: uri,
        );
      }
    } catch (e) {
      if (config.useMockFallback && mockFallback != null) {
        return mockFallback;
      }
      rethrow;
    }
  }

  // ==========================================
  // 1. SERVERS
  // ==========================================

  @override
  Future<List<ServerModel>> fetchServers() async {
    final mock = {
      'data': [
        {
          'id': 'srv_008',
          'title': 'Lakeview Stays & House Rentals',
          'subtitle': 'HOUSE RENTALS',
          'description':
              'Verified off-grid eco-villas, lakefront sanctuaries, private docks, and long-term stays secured by decentralized escrow.',
          'category': 'rentalAndGear',
          'tags': ['Rental & Gear', 'Eco Tourism', 'Startup'],
          'iconCodePoint': 0xf0289, // Icons.villa_rounded
          'primaryColor': 0xFF0D9488,
          'secondaryColor': 0xFFCCFBF1,
          'memberCount': 530,
          'bannerSvgOrType': 'gear_eco',
          'isJoined': true,
          'location': 'Lake Atitlan Basin & Highlands',
          'servicePricing': 'Nightly & Weekly Escrow',
          'servicesOffered': [
            'Lakefront Solar Eco-Villas',
            'Cliffside Artist Retreats',
            'Private Boat Dock Access',
          ],
          'lastNotification':
              'Lakeview Solar Eco-Villa added for weekend booking',
          'lastNotificationTime': '15m ago',
          'statusColor': 0xFF0D9488,
        },
        {
          'id': 'srv_009',
          'title': 'EcoTransit Mobility & Rides',
          'subtitle': 'ZERO-EMISSION RIDESHARE',
          'description':
              'Community-owned ride sharing, electric shuttle routes, and localized micro-transit with zero intermediary platform fees.',
          'category': 'mobilityAndRides',
          'tags': ['Mobility & Rides', 'Eco Tourism', 'Social Services'],
          'iconCodePoint': 0xf07a8, // Icons.electric_car_rounded
          'primaryColor': 0xFF0284C7,
          'secondaryColor': 0xFFE0F2FE,
          'memberCount': 1120,
          'bannerSvgOrType': 'dev_forge',
          'isJoined': true,
          'location': 'Guatemala City Corridor',
          'servicePricing': 'Per-Km Tokenized Fare',
          'servicesOffered': [
            'On-Demand EV Rides',
            'Daily Intercity Carpool',
            'Eco-Cargo Delivery',
          ],
          'lastNotification': '14 electric shuttles active in lake loop',
          'lastNotificationTime': '10m ago',
          'statusColor': 0xFF0284C7,
        },
        {
          'id': 'srv_010',
          'title': 'Artisan Goods & Organic Market',
          'subtitle': 'PRODUCER-DIRECT COMMERCE',
          'description':
              'Direct-to-consumer marketplace for single-origin shade coffee, handwoven indigenous textiles, and organic bio-goods.',
          'category': 'marketplaceAndGoods',
          'tags': ['Marketplace & Goods', 'Social Services', 'Startup'],
          'iconCodePoint': 0xf0204, // Icons.storefront_rounded
          'primaryColor': 0xFFD97706,
          'secondaryColor': 0xFFFEF3C7,
          'memberCount': 1680,
          'bannerSvgOrType': 'tree_canopy',
          'isJoined': true,
          'location': 'Highlands & Lake Basin Cooperatives',
          'servicePricing': 'Direct Producer Price',
          'servicesOffered': [
            'Single-Origin Shade Coffee',
            'Handwoven Indigenous Textiles',
            'Organic Seedling Kits',
          ],
          'lastNotification': 'Fresh harvest batch roasted and packaged',
          'lastNotificationTime': '20m ago',
          'statusColor': 0xFFD97706,
        },
      ],
    };

    final res = await _get('/servers', mockFallback: mock);
    final list = res['data'] as List<dynamic>? ?? [];
    return list
        .map((item) => ServerModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ServerModel?> fetchServerById(String id) async {
    final servers = await fetchServers();
    return servers.cast<ServerModel?>().firstWhere(
      (s) => s?.id == id,
      orElse: () => null,
    );
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
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final oi = OpenI.instance;
    final base = (oi != null && oi.settings.mediadb.isNotEmpty)
        ? oi.settings.mediadb
        : 'http://localhost.com:8080/site/mediadb';
    var cleanBase = base.trim();
    if (cleanBase.endsWith('/')) {
      cleanBase = cleanBase.substring(0, cleanBase.length - 1);
    }
    final primaryUrl = '$cleanBase/services/module/user/users.json';

    debugPrint('[ApiService] fetchUsers GET URL: $primaryUrl');
    try {
      final dio = DioUtil.dio;
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
        if (usersList.isNotEmpty) {
          return usersList
              .map(
                (item) =>
                    EmeProfileModel.fromUserJson(item as Map<String, dynamic>),
              )
              .toList();
        }
      }
    } catch (e, stack) {
      debugPrint('[ApiService] fetchUsers network error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.fetchUsers failed, falling back',
        customKeys: {'url': primaryUrl},
      );
    }
    return [];
  }

  @override
  Future<List<EmeProfileModel>> searchUsers(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final mock = {
      'response': {'status': 'ok'},
      'users': [
        {
          'id': 'admin',
          'firstname': 'The',
          'lastname': 'Administrator',
          'email': 'support@entermediadb.org',
          'assetportrait':
              'http://localhost.com:8080/site/mediadb/services/module/asset/generated/Users/The.A/jefferson-santos-9SoCnyQmkzI-unsplash.jpg/image200x200.webp',
        },
      ],
    };

    final res = await _get(
      '/services/module/user/usersearch.json?term=${Uri.encodeQueryComponent(cleanQuery)}',
      mockFallback: mock,
    );

    final usersList = (res['users'] as List<dynamic>?) ?? [];
    return usersList
        .map(
          (item) => EmeProfileModel.fromUserJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  // ==========================================
  // 3. USER PROFILE
  // ==========================================

  @override
  Future<ProfileModel> fetchUserProfile({String? userId}) async {
    final mock = {
      'data': {
        'id': userId ?? 'usr_001',
        'name': 'Christopher.B',
        'role': 'CEO & Node Architect',
        'bio':
            'Pioneering regenerative mesh networks, peer-to-peer commerce, and decentralized intelligence.',
        'tags': ['Programmer', 'Decentralization', 'AI Specialist'],
        'avatarUrl': 'https://randomuser.me/api/portraits/men/79.jpg',
        'portfolioLabel': 'PORTFOLIO',
        'totalServers': 8,
        'totalConnections': 248,
      },
    };

    final res = await _get('/users/${userId ?? "me"}', mockFallback: mock);
    return ProfileModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  // ==========================================
  // 4. PRODUCTS & SERVICES CATALOG
  // ==========================================

  @override
  Future<List<ProductMessageModel>> fetchProducts({
    String? serverId,
    ProductType? type,
  }) async {
    final mock = {
      'data': ProductMessageModel.sampleCatalog.map((p) => p.toJson()).toList(),
    };

    final res = await _get('/products', mockFallback: mock);
    final list = res['data'] as List<dynamic>? ?? [];
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
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final oi = OpenI.instance;
    final base = (oi != null && oi.settings.mediadb.isNotEmpty)
        ? oi.settings.mediadb
        : 'http://localhost.com:8080/site/mediadb';
    var cleanBase = base.trim();
    if (cleanBase.endsWith('/')) {
      cleanBase = cleanBase.substring(0, cleanBase.length - 1);
    }
    final primaryUrl = '$cleanBase/services/module/user/chats.json';

    debugPrint('[ApiService] fetchChats GET URL: $primaryUrl');
    try {
      final dio = DioUtil.dio;
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
      return [];
    } catch (e, stack) {
      debugPrint('[ApiService] fetchChats network error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.fetchChats failed, falling back',
        customKeys: {'url': primaryUrl},
      );

      rethrow;
    }
  }

  @override
  Future<List<ChatMessage>> fetchChatMessages(String channelId) async {
    final token = await SharedPref.getEMKey() ?? AuthService.token;
    final oi = OpenI.instance;
    final base = (oi != null && oi.settings.mediadb.isNotEmpty)
        ? oi.settings.mediadb
        : 'http://localhost.com:8080/site/mediadb';
    var cleanBase = base.trim();
    if (cleanBase.endsWith('/')) {
      cleanBase = cleanBase.substring(0, cleanBase.length - 1);
    }
    final primaryUrl = '$cleanBase/services/module/user/chat.json';

    debugPrint('[ApiService] fetchChatMessages GET URL: $primaryUrl?channel=$channelId');
    try {
      final dio = DioUtil.dio;
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
      return [];
    } catch (e, stack) {
      debugPrint('[ApiService] fetchChatMessages error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'ApiService.fetchChatMessages failed',
        customKeys: {'url': primaryUrl, 'channelId': channelId},
      );
      return [];
    }
  }

  // ==========================================
  // 6. FILES & ASSETS
  // ==========================================

  @override
  Future<List<FileItemModel>> fetchFiles({String? serverId}) async {
    final mock = {
      'data': [
        {
          'id': 'f_2',
          'name': 'Impact_Tokenomics_v2.xlsx',
          'category': 'Spreadsheet',
          'size': '1.2 MB',
          'updatedAt': 'Yesterday',
          'iconCodePoint': 0xf0221,
          'color': 0xFF10B981,
          'isFolder': false,
        },
        {
          'id': 'f_3',
          'name': 'Circular_Bioeconomy_Blueprint.docx',
          'category': 'Research',
          'size': '8.4 MB',
          'updatedAt': 'Sep 8, 2026',
          'iconCodePoint': 0xe1fa,
          'color': 0xFF3B82F6,
          'isFolder': false,
        },
        {
          'id': 'f_4',
          'name': 'Smart_Contract_Audit_Report.pdf',
          'category': 'Audit',
          'size': '2.1 MB',
          'updatedAt': 'Sep 4, 2026',
          'iconCodePoint': 0xe6bb,
          'color': 0xFF8B5CF6,
          'isFolder': false,
        },
        {
          'id': 'f_5',
          'name': 'Brand_Assets_Pack.zip',
          'category': 'Design',
          'size': '42.5 MB',
          'updatedAt': 'Aug 28, 2026',
          'iconCodePoint': 0xf0741,
          'color': 0xFFF59E0B,
          'isFolder': false,
        },
      ],
    };

    final res = await _get('/files', mockFallback: mock);
    final list = res['data'] as List<dynamic>? ?? [];
    return list
        .map((item) => FileItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  // 7. SERVER GOALS
  // ==========================================

  @override
  Future<List<GoalItemModel>> fetchServerGoals(String serverId) async {
    final mock = {
      'data': [
        {
          'id': '2300',
          'title': "Make sure all SSL certificates don't expire",
          'dueDate': '2026-05-29',
          'createdAgo': '113d:20h:33m ago',
          'createdBy': 'Reana N',
          'ticketType': 'Chat',
          'isResolved': false,
          'tasks': [
            {
              'id': 't-1',
              'title': "Make sure all SSL certificates don't expire",
              'assignedRole': 'Java Developer - Cristobal.M',
              'addedBy': 'Reana N',
              'addedAgo': '113d 20h 33m ago',
              'isResolved': false,
            },
          ],
        },
        {
          'id': '2304',
          'title': 'Launch Cross-Node Sync & P2P Data Bridge',
          'dueDate': '2026-06-15',
          'createdAgo': '42d:12h:10m ago',
          'createdBy': 'Alex K',
          'ticketType': 'Milestone',
          'isResolved': false,
          'tasks': [
            {
              'id': 't-2',
              'title': 'Deploy low-latency gossip sub-network for node syncing',
              'assignedRole': 'Core Engineer - Alex.K',
              'addedBy': 'Alex K',
              'addedAgo': '42d 12h 10m ago',
              'isResolved': false,
            },
            {
              'id': 't-3',
              'title': 'Verify state consistency across backup validators',
              'assignedRole': 'DevOps Lead - Jordan.P',
              'addedBy': 'Jordan P',
              'addedAgo': '38d 06h 15m ago',
              'isResolved': false,
            },
          ],
        },
        {
          'id': '2289',
          'title': 'Community Governance & Tokenized Voting',
          'dueDate': '2026-07-01',
          'createdAgo': '18d:04h:22m ago',
          'createdBy': 'Sarah T',
          'ticketType': 'Proposal',
          'isResolved': false,
          'tasks': [
            {
              'id': 't-4',
              'title': 'Implement quadratic voting contracts for node grants',
              'assignedRole': 'Smart Contract Dev - Sarah.T',
              'addedBy': 'Sarah T',
              'addedAgo': '18d 04h 22m ago',
              'isResolved': false,
            },
          ],
        },
      ],
    };

    final res = await _get('/servers/$serverId/goals', mockFallback: mock);
    final list = res['data'] as List<dynamic>? ?? [];
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
    final mock = {
      'data': [
        {
          'id': 'tx_01',
          'title': 'Community DAO Ecosystem Grant',
          'date': 'Today, 2:15 PM',
          'amount': '+ \$5,000.00',
          'isCredit': true,
          'category': 'Grant',
        },
        {
          'id': 'tx_02',
          'title': 'Compute Cluster Hosting Node #04',
          'date': 'Yesterday',
          'amount': '- \$240.00',
          'isCredit': false,
          'category': 'Infrastructure',
        },
        {
          'id': 'tx_03',
          'title': 'Biometric Verification Bounty Payout',
          'date': 'Sep 12, 2026',
          'amount': '- \$1,200.00',
          'isCredit': false,
          'category': 'Bounty',
        },
        {
          'id': 'tx_04',
          'title': 'Cross-Border FX Micro-Settlement Fee Pool',
          'date': 'Sep 10, 2026',
          'amount': '+ \$890.50',
          'isCredit': true,
          'category': 'Revenue',
        },
      ],
    };

    final res = await _get(
      '/servers/$serverId/transactions',
      mockFallback: mock,
    );
    final list = res['data'] as List<dynamic>? ?? [];
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
    final mock = {
      'data': [
        {
          'id': 'post_01',
          'title':
              'Decentralized Collective Intelligence: State of the Node in 2026',
          'author': 'Lead Architect',
          'date': 'Sep 14, 2026',
          'readTime': '4 min read',
          'excerpt':
              'How distributed compute, local governance, and verifiable data pipelines scale across 12 countries.',
          'tag': 'Architecture',
          'likes': 128,
        },
        {
          'id': 'post_02',
          'title': 'Community Roadmap Update: What to Expect in Q4',
          'author': 'Ecosystem Core',
          'date': 'Sep 08, 2026',
          'readTime': '3 min read',
          'excerpt':
              'A breakdown of newly funded bounties, protocol upgrades, and upcoming integrations in the EME network.',
          'tag': 'Announcements',
          'likes': 94,
        },
        {
          'id': 'post_03',
          'title': 'Zero-Knowledge Privacy and Humanitarian Impact Passports',
          'author': 'Security Research Group',
          'date': 'Aug 29, 2026',
          'readTime': '6 min read',
          'excerpt':
              'Ensuring identity self-sovereignty without sacrificing cryptographic proof-of-humanity.',
          'tag': 'Research',
          'likes': 215,
        },
      ],
    };

    final res = await _get('/servers/$serverId/posts', mockFallback: mock);
    final list = res['data'] as List<dynamic>? ?? [];
    return list
        .map((item) => BlogPostModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
