import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// Provider for the ApiService singleton/instance
final apiServiceProvider = Provider<IApiService>((ref) {
  return ApiService();
});

/// FutureProvider to fetch all servers from API
final apiServersProvider = FutureProvider<List<ServerModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchServers();
});

/// FutureProvider to fetch a single server by ID
final serverDetailProvider =
    FutureProvider.family<ServerModel?, String>((ref, id) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchServerById(id);
});

/// FutureProvider to fetch specialist profiles from API
final apiSpecialistProfilesProvider =
    FutureProvider<List<EmeProfileModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchSpecialistProfiles();
});

/// FutureProvider to fetch user profile from API
final apiUserProfileProvider = FutureProvider<ProfileModel>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchUserProfile();
});

/// FutureProvider to fetch products / services catalog from API
final apiProductsProvider =
    FutureProvider.family<List<ProductMessageModel>, ProductType?>((
  ref,
  type,
) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchProducts(type: type);
});

/// FutureProvider to fetch chats from API
final apiChatsProvider = FutureProvider<List<ChatModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchChats();
});

/// FutureProvider to fetch files from API
final apiFilesProvider =
    FutureProvider.family<List<FileItemModel>, String?>((ref, serverId) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchFiles(serverId: serverId);
});

/// FutureProvider to fetch goals for a specific server from API
final serverGoalsProvider =
    FutureProvider.family<List<GoalItemModel>, String>((ref, serverId) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchServerGoals(serverId);
});

/// FutureProvider to fetch transactions / financial data for a specific server from API
final serverTransactionsProvider =
    FutureProvider.family<List<TransactionItemModel>, String>((
  ref,
  serverId,
) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchServerTransactions(serverId);
});

/// FutureProvider to fetch blog posts for a specific server from API
final serverBlogPostsProvider =
    FutureProvider.family<List<BlogPostModel>, String>((ref, serverId) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchServerBlogPosts(serverId);
});
