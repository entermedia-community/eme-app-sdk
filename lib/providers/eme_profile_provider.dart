import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_service.dart';
import '../models/eme_profile_model.dart';
import '../services/api_service.dart';
import 'api_providers.dart';

final List<String> kEmeProfileCategories = [
  'All',
  ...ProfileCategory.values.map((c) => c.label),
];

class EmeProfileState {
  final List<EmeProfileModel> profiles;
  final List<EmeProfileModel> searchResults;
  final String selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final bool isSearching;
  final String? error;

  const EmeProfileState({
    required this.profiles,
    this.searchResults = const [],
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.isLoading = false,
    this.isSearching = false,
    this.error,
  });

  int get totalCount => profiles.length;

  List<EmeProfileModel> get filteredProfiles {
    final List<EmeProfileModel> sourceList;
    if (searchQuery.isNotEmpty) {
      if (searchResults.isNotEmpty) {
        sourceList = searchResults;
      } else if (!isSearching) {
        // If search completed and returned empty, or before remote response
        sourceList = _filterLocal(profiles, searchQuery);
      } else {
        sourceList = searchResults;
      }
    } else {
      sourceList = profiles;
    }

    return sourceList.where((item) {
      // Category Filter
      final matchesCategory =
          selectedCategory == 'All' ||
          item.category.label == selectedCategory ||
          item.tags.contains(selectedCategory);

      return matchesCategory;
    }).toList();
  }

  static List<EmeProfileModel> _filterLocal(
    List<EmeProfileModel> list,
    String query,
  ) {
    final q = query.toLowerCase();
    return list.where((item) {
      final nameMatch = item.name.toLowerCase().contains(q);
      final subtitleMatch =
          item.subtitle?.toLowerCase().contains(q) ?? false;
      final specialistMatch =
          item.specialistTitle?.toLowerCase().contains(q) ?? false;
      final descMatch = item.description.toLowerCase().contains(q);
      final tagMatch = item.tags.any(
        (tag) => tag.toLowerCase().contains(q),
      );
      final serviceMatch = item.servicesOffered.any(
        (srv) => srv.toLowerCase().contains(q),
      );
      final locationMatch =
          item.location?.toLowerCase().contains(q) ?? false;

      return nameMatch ||
          subtitleMatch ||
          specialistMatch ||
          descMatch ||
          tagMatch ||
          serviceMatch ||
          locationMatch;
    }).toList();
  }

  EmeProfileState copyWith({
    List<EmeProfileModel>? profiles,
    List<EmeProfileModel>? searchResults,
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    bool? isSearching,
    String? error,
  }) {
    return EmeProfileState(
      profiles: profiles ?? this.profiles,
      searchResults: searchResults ?? this.searchResults,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      error: error,
    );
  }
}

class EmeProfileNotifier extends StateNotifier<EmeProfileState> {
  final IApiService? apiService;
  final IAuthService? authService;
  Timer? _debounceTimer;

  EmeProfileNotifier({this.apiService, this.authService})
      : super(
        const EmeProfileState(
          profiles: [],
        ),
      ) {
    loadUsers();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final fetched =
          await (apiService?.fetchUsers() ??
              Future.value(<EmeProfileModel>[]));
      state = state.copyWith(profiles: fetched, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadProfilesFromApi() async {
    await loadUsers();
  }

  Future<void> searchUsers(String query) async {
    state = state.copyWith(searchQuery: query);
    _debounceTimer?.cancel();

    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      state = state.copyWith(
        searchResults: const [],
        isSearching: false,
        error: null,
      );
      return;
    }

    state = state.copyWith(isSearching: true, error: null);

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        List<EmeProfileModel> fetchedResults = [];

        // 1. First try authService / Dio client to hit EnterMedia backend
        if (authService != null) {
          final users = await authService!.searchUsers(cleanQuery);
          if (users.isNotEmpty) {
            fetchedResults = users
                .map((u) => EmeProfileModel.fromEmUser(u))
                .toList();
          }
        }

        // 2. If empty, try apiService
        if (fetchedResults.isEmpty && apiService != null) {
          final results = await apiService!.searchUsers(cleanQuery);
          if (results.isNotEmpty) {
            fetchedResults = results;
          }
        }

        state = state.copyWith(
          searchResults: fetchedResults,
          isSearching: false,
        );
      } catch (e) {
        state = state.copyWith(
          isSearching: false,
          error: e.toString(),
        );
      }
    });
  }

  void setSearchQuery(String query) {
    searchUsers(query);
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    state = state.copyWith(
      searchQuery: '',
      searchResults: const [],
      isSearching: false,
      error: null,
    );
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void addProfile(EmeProfileModel profile) {
    state = state.copyWith(profiles: [profile, ...state.profiles]);
  }
}

final emeProfileProvider =
    StateNotifierProvider<EmeProfileNotifier, EmeProfileState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final authService = ref.watch(authServiceProvider);
  return EmeProfileNotifier(apiService: api, authService: authService);
});
