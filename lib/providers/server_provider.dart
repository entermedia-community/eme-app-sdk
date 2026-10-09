import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/server_category_model.dart';
import '../models/server_model.dart';
import '../services/api_service.dart';
import '../services/shared_preferences.dart';
import 'api_providers.dart';

/// Initial/fallback server categories.
final List<ServerCategoryModel> kServerCategories = [];

class ServerState {
  final List<ServerModel> servers;
  final List<ServerCategoryModel> categories;
  final String selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  const ServerState({
    required this.servers,
    this.categories = const [],
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.isLoading = true,
    this.error,
  });

  /// Servers that the user has already joined (for the Profile page)
  List<ServerModel> get joinedServers {
    return servers.where((s) => s.isJoined).toList();
  }

  int get joinedCount => joinedServers.length;

  int get serverCount => servers.length;

  /// Servers filtered for Server Picker & Catalog
  List<ServerModel> get filteredServers {
    return servers.where((item) {
      // Category Filter
      final matchesCategory =
          selectedCategory == 'All' ||
          selectedCategory == 'all' ||
          selectedCategory.isEmpty ||
          item.category == selectedCategory;

      if (!matchesCategory) return false;

      // Search Query Filter
      if (searchQuery.isEmpty) return true;

      final query = searchQuery.toLowerCase();
      final titleMatch = item.name.toLowerCase().contains(query);
      final subtitleMatch =
          item.subtitle?.toLowerCase().contains(query) ?? false;
      final descMatch = item.description.toLowerCase().contains(query);
      final serviceMatch = item.servicesOffered.any(
        (srv) => srv.toLowerCase().contains(query),
      );

      return titleMatch || subtitleMatch || descMatch || serviceMatch;
    }).toList();
  }

  ServerState copyWith({
    List<ServerModel>? servers,
    List<ServerCategoryModel>? categories,
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    String? error,
  }) {
    return ServerState(
      servers: servers ?? this.servers,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ServerNotifier extends StateNotifier<ServerState> {
  final IApiService? apiService;

  ServerNotifier({this.apiService})
    : super(const ServerState(servers: [], isLoading: true)) {
    loadServersFromApi();
    _initCategories();
  }

  Future<void> _initCategories() async {
    await _loadCachedCategories();
    await reloadCategories(force: false);
  }

  Future<void> _loadCachedCategories() async {
    try {
      final cached = await SharedPref.getCachedServerCategories();
      if (cached != null && cached.isNotEmpty) {
        state = state.copyWith(categories: cached);
      }
    } catch (_) {}
  }

  /// Silently reloads categories once a day (if force is false) or unconditionally (if force is true).
  Future<void> reloadCategories({bool force = false}) async {
    if (apiService == null) return;
    if (!force) {
      final lastFetch = await SharedPref.getServerCategoriesLastFetchTime();
      if (lastFetch != null &&
          DateTime.now().difference(lastFetch) < const Duration(days: 1)) {
        return;
      }
    }

    try {
      final fetched = await apiService!.fetchServerCategories();
      if (fetched.isNotEmpty) {
        final categoriesWithAll = fetched.any(
              (c) => c.id == 'all' || c.name.toLowerCase() == 'all',
            )
            ? fetched
            : [ServerCategoryModel.all, ...fetched];
        await SharedPref.saveServerCategories(categoriesWithAll);
        state = state.copyWith(categories: categoriesWithAll);
      }
    } catch (e) {
      debugPrint('[ServerNotifier] Silently failed to reload categories: $e');
    }
  }

  /// Reloads both servers and categories when user pulls to refresh.
  Future<void> refresh() async {
    await Future.wait([loadServersFromApi(), reloadCategories(force: true)]);
  }

  Future<void> loadServersFromApi({
    String? query,
    String? category,
    bool forceRefreshCategories = false,
  }) async {
    if (forceRefreshCategories) {
      unawaited(reloadCategories(force: true));
    }
    if (apiService == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    final effectiveQuery =
        query ?? (state.searchQuery.isNotEmpty ? state.searchQuery : null);
    final effectiveCategory =
        category ??
        (state.selectedCategory != 'All' && state.selectedCategory != 'all'
            ? state.selectedCategory
            : null);

    state = state.copyWith(
      isLoading: true,
      error: null,
      searchQuery: query ?? state.searchQuery,
      selectedCategory: category ?? state.selectedCategory,
    );
    try {
      final fetched = await apiService!.fetchServers(
        query: effectiveQuery,
        category: effectiveCategory,
      );
      state = state.copyWith(servers: fetched, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setCategory(String category) {
    loadServersFromApi(category: category);
  }

  void setSearchQuery(String query) {
    loadServersFromApi(query: query);
  }

  void addServer(ServerModel server) {
    state = state.copyWith(servers: [server, ...state.servers]);
  }

  Future<void> toggleJoin(String id) async {
    final server = state.servers.cast<ServerModel?>().firstWhere(
      (s) => s?.id == id,
      orElse: () => null,
    );
    if (server == null) return;

    final targetJoined = !server.isJoined;
    // Optimistic update
    final updated = state.servers.map((s) {
      if (s.id == id) {
        return s.copyWith(isJoined: targetJoined);
      }
      return s;
    }).toList();
    state = state.copyWith(servers: updated);

    // Call backend API
    if (apiService != null) {
      try {
        final success = targetJoined
            ? await apiService!.joinServer(id)
            : await apiService!.leaveServer(id);
        if (!success) {
          // Revert on failure
          final reverted = state.servers.map((s) {
            if (s.id == id) {
              return s.copyWith(isJoined: !targetJoined);
            }
            return s;
          }).toList();
          state = state.copyWith(servers: reverted);
        }
      } catch (e) {
        final reverted = state.servers.map((s) {
          if (s.id == id) {
            return s.copyWith(isJoined: !targetJoined);
          }
          return s;
        }).toList();
        state = state.copyWith(servers: reverted);
      }
    }
  }
}

final serverProvider = StateNotifierProvider<ServerNotifier, ServerState>((
  ref,
) {
  final api = ref.watch(apiServiceProvider);
  return ServerNotifier(apiService: api);
});
