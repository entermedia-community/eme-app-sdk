import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/server_model.dart';
import '../services/api_service.dart';
import 'api_providers.dart';

final List<String> kServerCategories = [
  'All',
  ...ServerCategory.values.map((c) => c.label),
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
          selectedCategory == 'All' ||
          item.category.label == selectedCategory ||
          item.tags.contains(selectedCategory);

      if (!matchesCategory) return false;

      // Search Query Filter
      if (searchQuery.isEmpty) return true;

      final query = searchQuery.toLowerCase();
      final titleMatch = item.title.toLowerCase().contains(query);
      final subtitleMatch =
          item.subtitle?.toLowerCase().contains(query) ?? false;
      final descMatch = item.description.toLowerCase().contains(query);
      final tagMatch = item.tags.any(
        (tag) => tag.toLowerCase().contains(query),
      );
      final serviceMatch = item.servicesOffered.any(
        (srv) => srv.toLowerCase().contains(query),
      );
      final locationMatch =
          item.location?.toLowerCase().contains(query) ?? false;

      return titleMatch ||
          subtitleMatch ||
          descMatch ||
          tagMatch ||
          serviceMatch ||
          locationMatch;
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
      : super(
        const ServerState(
          servers: [
            ServerModel(
              id: 'srv_008',
              title: 'Lakeview Stays & House Rentals',
              subtitle: 'HOUSE RENTALS',
              description:
                  'Verified off-grid eco-villas, lakefront sanctuaries, private docks, and long-term stays secured by decentralized escrow.',
              category: ServerCategory.rentalAndGear,
              tags: ['Rental & Gear', 'Eco Tourism', 'Startup'],
              iconData: Icons.villa_rounded,
              primaryColor: Color(0xFF0D9488),
              secondaryColor: Color(0xFFCCFBF1),
              memberCount: 530,
              bannerSvgOrType: 'gear_eco',
              isJoined: true,
              location: 'Lake Atitlan Basin & Highlands',
              servicePricing: 'Nightly & Weekly Escrow',
              servicesOffered: [
                'Lakefront Solar Eco-Villas',
                'Cliffside Artist Retreats',
                'Private Boat Dock Access',
              ],
              lastNotification:
                  'Lakeview Solar Eco-Villa added for weekend booking',
              lastNotificationTime: '15m ago',
              statusColor: Color(0xFF0D9488),
            ),
            ServerModel(
              id: 'srv_009',
              title: 'EcoTransit Mobility & Rides',
              subtitle: 'ZERO-EMISSION RIDESHARE',
              description:
                  'Community-owned ride sharing, electric shuttle routes, and localized micro-transit with zero intermediary platform fees.',
              category: ServerCategory.mobilityAndRides,
              tags: ['Mobility & Rides', 'Eco Tourism', 'Social Services'],
              iconData: Icons.electric_car_rounded,
              primaryColor: Color(0xFF0284C7),
              secondaryColor: Color(0xFFE0F2FE),
              memberCount: 1120,
              bannerSvgOrType: 'dev_forge',
              isJoined: true,
              location: 'Guatemala City Corridor',
              servicePricing: 'Per-Km Tokenized Fare',
              servicesOffered: [
                'On-Demand EV Rides',
                'Daily Intercity Carpool',
                'Eco-Cargo Delivery',
              ],
              lastNotification: '14 electric shuttles active in lake loop',
              lastNotificationTime: '10m ago',
              statusColor: Color(0xFF0284C7),
            ),
            ServerModel(
              id: 'srv_010',
              title: 'Artisan Goods & Organic Market',
              subtitle: 'PRODUCER-DIRECT COMMERCE',
              description:
                  'Direct-to-consumer marketplace for single-origin shade coffee, handwoven indigenous textiles, and organic bio-goods.',
              category: ServerCategory.marketplaceAndGoods,
              tags: ['Marketplace & Goods', 'Social Services', 'Startup'],
              iconData: Icons.storefront_rounded,
              primaryColor: Color(0xFFD97706),
              secondaryColor: Color(0xFFFEF3C7),
              memberCount: 1680,
              bannerSvgOrType: 'tree_canopy',
              isJoined: true,
              location: 'Highlands & Lake Basin Cooperatives',
              servicePricing: 'Direct Producer Price',
              servicesOffered: [
                'Single-Origin Shade Coffee',
                'Handwoven Indigenous Textiles',
                'Organic Seedling Kits',
              ],
              lastNotification: 'Fresh harvest batch roasted and packaged',
              lastNotificationTime: '20m ago',
              statusColor: Color(0xFFD97706),
            ),
          ],
        ),
      );

  Future<void> loadServersFromApi() async {
    if (apiService == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final fetched = await apiService!.fetchServers();
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

  void toggleJoin(String id) {
    final updated = state.servers.map((s) {
      if (s.id == id) {
        return s.copyWith(isJoined: !s.isJoined);
      }
      return s;
    }).toList();
    state = state.copyWith(servers: updated);
  }
}

final serverProvider = StateNotifierProvider<ServerNotifier, ServerState>((
  ref,
) {
  final api = ref.watch(apiServiceProvider);
  return ServerNotifier(apiService: api);
});
