import 'dart:async';
import 'package:flutter/material.dart';
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
          profiles: [
            EmeProfileModel(
              id: 'ind_001',
              name: 'Dr. Maya Lin',
              specialistTitle: 'Bio-credit & Hydrology Auditor',
              subtitle: 'SENIOR ECOLOGICAL SCIENTIST',
              description:
                  'Specializing in decentralized freshwater telemetry, watershed validation, and verifiable biodiversity impact certificates.',
              category: ProfileCategory.ecoTourism,
              tags: ['Eco Tourism', 'Research', 'Social Services'],
              iconData: Icons.water_drop_rounded,
              avatarUrl: 'https://randomuser.me/api/portraits/women/44.jpg',
              primaryColor: Color(0xFF0284C7),
              secondaryColor: Color(0xFFF0F9FF),
              memberCount: 42,
              rating: 4.9,
              reviewsCount: 142,
              servicePricing: r'$60/hr • Grants',
              location: 'Panajachel, Guatemala',
              isVerified: true,
              servicesOffered: [
                'Water Quality Certification',
                'Bio-credit Verification',
                'Watershed GIS Analysis',
              ],
            ),
            EmeProfileModel(
              id: 'ind_002',
              name: 'Marcus Chen',
              specialistTitle: 'Autonomous AI Agent Architect',
              subtitle: 'EX-STANFORD AI LAB',
              description:
                  'Builds decentralized multi-agent workflows, model quantization pipelines, and privacy-preserving inference nodes.',
              category: ProfileCategory.artificialIntelligence,
              tags: ['Artificial Intelligence', 'Software Tools'],
              iconData: Icons.psychology_rounded,
              avatarUrl: 'https://randomuser.me/api/portraits/men/32.jpg',
              primaryColor: Color(0xFF8B5CF6),
              secondaryColor: Color(0xFFF5F3FF),
              memberCount: 89,
              rating: 5.0,
              reviewsCount: 89,
              servicePricing: r'$85/hr • Escrow',
              location: 'Singapore • Remote',
              isVerified: true,
              servicesOffered: [
                'Multi-Agent System Architecture',
                'Model Quantization (GGUF/AWQ)',
                'Agentic Tool Calling Integration',
              ],
            ),
            EmeProfileModel(
              id: 'ind_003',
              name: 'Sofia Alcantara',
              specialistTitle: 'Regenerative Finance & Tokenomics Advisor',
              subtitle: 'IMPACT PROTOCOL STRATEGIST',
              description:
                  'Advising communities on micro-credit token design, impact bonds, and decentralized treasury management.',
              category: ProfileCategory.finance,
              tags: ['Finance', 'Startup', 'Social Services'],
              iconData: Icons.account_balance_wallet_rounded,
              avatarUrl: 'https://randomuser.me/api/portraits/women/65.jpg',
              primaryColor: Color(0xFF10B981),
              secondaryColor: Color(0xFFECFDF5),
              memberCount: 76,
              rating: 4.8,
              reviewsCount: 76,
              servicePricing: r'$50/hr • DAO',
              location: 'Berlin, Germany',
              isVerified: true,
              servicesOffered: [
                'DeFi & Impact Tokenomics Design',
                'Micro-lending Mesh Setup',
                'Treasury Multi-sig Governance',
              ],
            ),
            EmeProfileModel(
              id: 'ind_005',
              name: 'Elena Vance',
              specialistTitle: 'Smart Contract & Security Auditor',
              subtitle: 'ZK-SNARK & CONSENSUS AUDITOR',
              description:
                  'Formal verification and vulnerability audits for cross-chain bridges, token contracts, and zero-knowledge identity protocols.',
              category: ProfileCategory.softwareTools,
              tags: ['Software Tools', 'Finance'],
              iconData: Icons.security_rounded,
              avatarUrl: 'https://randomuser.me/api/portraits/women/33.jpg',
              primaryColor: Color(0xFF6366F1),
              secondaryColor: Color(0xFFEEF2FF),
              memberCount: 215,
              rating: 5.0,
              reviewsCount: 215,
              servicePricing: r'$95/hr',
              location: 'Zurich, Switzerland',
              isVerified: true,
              servicesOffered: [
                'Solidity & Rust Contract Audits',
                'ZK Circuit Security Verification',
                'Economic Attack Simulation',
              ],
            ),
          ],
        ),
      );

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> loadProfilesFromApi() async {
    if (apiService == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final fetched = await apiService!.fetchSpecialistProfiles();
      state = state.copyWith(profiles: fetched, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
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
