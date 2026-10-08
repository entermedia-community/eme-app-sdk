import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/server_model.dart';
import '../services/api_service.dart';
import 'api_providers.dart';

final List<String> kServerCategories = [
  'All',
  'Rental & Gear',
  'Mobility & Rides',
  'Marketplace & Goods',
  'Eco Tourism',
  'Finance',
  'Artificial Intelligence',
  'Social Services',
  'Software Tools',
  'Research',
  'Education',
  'Healthcare',
  'Startup',
];

class ServerState {
  final List<ServerModel> servers;
  final String selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  const ServerState({
    required this.servers,
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.isLoading = false,
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
          selectedCategory == 'All' || item.category == selectedCategory;

      if (!matchesCategory) return false;

      // Search Query Filter
      if (searchQuery.isEmpty) return true;

      final query = searchQuery.toLowerCase();
      final titleMatch = item.title.toLowerCase().contains(query);
      final subtitleMatch =
          item.subtitle?.toLowerCase().contains(query) ?? false;
      final descMatch = item.description.toLowerCase().contains(query);
      final serviceMatch = item.servicesOffered.any(
        (srv) => srv.toLowerCase().contains(query),
      );

      return titleMatch ||
          subtitleMatch ||
          descMatch ||
          serviceMatch;
    }).toList();
  }

  ServerState copyWith({
    List<ServerModel>? servers,
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    String? error,
  }) {
    return ServerState(
      servers: servers ?? this.servers,
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
  }

  Future<void> loadServersFromApi({String? query, String? category}) async {
    if (apiService == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final fetched = await apiService!.fetchServers(
        query:
            query ??
            (state.searchQuery.isNotEmpty ? state.searchQuery : null),
        category:
            category ??
            (state.selectedCategory != 'All' ? state.selectedCategory : null),
      );
      state = state.copyWith(servers: fetched, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
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
