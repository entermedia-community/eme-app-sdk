import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/chat_socket_service.dart';

/// Provider for the ApiService singleton/instance
final apiServiceProvider = Provider<IApiService>((ref) {
  return ApiService();
});

/// Provider for the ChatSocketService singleton/instance
final chatSocketServiceProvider = Provider<ChatSocketService>((ref) {
  return ChatSocketService();
});

/// FutureProvider to fetch all servers from API
final apiServersProvider = FutureProvider<List<ServerModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchServers();
});

/// FutureProvider to fetch a single server by ID
final serverDetailProvider = FutureProvider.family<ServerModel?, String>((
  ref,
  id,
) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchServerById(id);
});

/// FutureProvider to fetch specialist profiles from API
final apiSpecialistProfilesProvider = FutureProvider<List<EmeProfileModel>>((
  ref,
) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchSpecialistProfiles();
});

/// FutureProvider to fetch users from /services/module/user/users.json
final apiUsersProvider = FutureProvider<List<EmeProfileModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchUsers();
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

/// FutureProvider for the EME Servers the signed-in user has joined.
/// Invalidate it after joining or leaving a server.
final userServersProvider = FutureProvider<List<ServerModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchUserServers();
});

/// Key for [projectCollectionProvider]: the collection id and the mediadb
/// it lives on (empty for the app's own mediadb).
typedef ProjectCollectionKey = ({String collectionId, String baseUrl});

/// FutureProvider for a project's details and team
/// (`librarycollection/data/{id}`).
final projectCollectionProvider =
    FutureProvider.family<LibraryCollectionModel, ProjectCollectionKey>((
      ref,
      key,
    ) async {
      final api = ref.watch(apiServiceProvider);
      return api.fetchProjectCollection(key.collectionId, baseUrl: key.baseUrl);
    });

/// FutureProvider for the projects the signed-in user is on the team of.
final userProjectsProvider = FutureProvider<List<LibraryCollectionModel>>((
  ref,
) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchUserProjects();
});

/// FutureProvider for a project's team chat channel and the user's edit
/// permission, keyed by collection id.
final projectChatConnectionProvider =
    FutureProvider.family<ProjectChatConnection, String>((
      ref,
      collectionId,
    ) async {
      final api = ref.watch(apiServiceProvider);
      return api.connectProjectChat(collectionId);
    });

/// Events the signed-in user answered Interested or Going to (chat list).
final userEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchEvents(rsvpedOnly: true);
});

/// Events matching a search [query] (all events when empty).
final eventSearchProvider = FutureProvider.family<List<EventModel>, String>((
  ref,
  query,
) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchEvents(query: query);
});

/// What a unified search looks for: the [query] text (everything when
/// empty), the [types] to search (all when empty) and an EME server
/// [category] id. Compared by value so it can key [searchProvider].
@immutable
class SearchKey {
  final String query;
  final Set<SearchType> types;
  final String? category;

  const SearchKey({this.query = '', this.types = const {}, this.category});

  @override
  bool operator ==(Object other) =>
      other is SearchKey &&
      other.query == query &&
      other.category == category &&
      other.types.length == types.length &&
      other.types.containsAll(types);

  @override
  int get hashCode =>
      Object.hash(query, category, Object.hashAllUnordered(types));
}

/// People, projects, EME servers and events matching a [SearchKey]
/// (everything when the query is empty).
final searchProvider = FutureProvider.family<SearchResults, SearchKey>((
  ref,
  key,
) async {
  final api = ref.watch(apiServiceProvider);
  return api.search(query: key.query, types: key.types, category: key.category);
});

/// One event with its counts and the user's response.
final eventProvider = FutureProvider.family<EventModel, String>((
  ref,
  eventId,
) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchEvent(eventId);
});

/// An event's chat channel id.
final eventChatChannelProvider = FutureProvider.family<String, String>((
  ref,
  eventId,
) async {
  final api = ref.watch(apiServiceProvider);
  return api.connectEventChat(eventId);
});

/// FutureProvider for the users that can still be added to a project's team,
/// keyed by collection id.
final projectTeamCandidatesProvider =
    FutureProvider.family<List<EmeProfileModel>, String>((
      ref,
      collectionId,
    ) async {
      final api = ref.watch(apiServiceProvider);
      return api.fetchTeamCandidates(collectionId);
    });

/// FutureProvider for the roles a project team member can have.
final projectTeamRolesProvider = FutureProvider<List<ProjectTeamRole>>((
  ref,
) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchTeamRoles();
});

/// FutureProvider to fetch chats from API
final apiChatsProvider = FutureProvider<List<ChatModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchChats();
});

/// FutureProvider to fetch chat message history from API
final apiChatMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, channelId) async {
      final api = ref.watch(apiServiceProvider);
      return api.fetchUserChatMessages(channelId);
    });

/// FutureProvider to fetch server chat message history from API
final apiServerChatMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, channelId) async {
      final api = ref.watch(apiServiceProvider);
      return api.fetchServerChatMessages(channelId);
    });

/// FutureProvider to fetch files from API
final apiFilesProvider = FutureProvider.family<List<FileItemModel>, String?>((
  ref,
  serverId,
) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchFiles(serverId: serverId);
});

/// FutureProvider to fetch goals for a specific server from API
final serverGoalsProvider = FutureProvider.family<List<GoalItemModel>, String>((
  ref,
  serverId,
) async {
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
