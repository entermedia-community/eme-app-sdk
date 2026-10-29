import 'eme_profile_model.dart';
import 'event_model.dart';
import 'library_collection_model.dart';
import 'server_model.dart';

/// What a unified search can look through. The [name]s are the `types` the
/// `emesearch/search.json` service takes.
enum SearchType { people, projects, servers, events }

/// The result of one unified search (`emesearch/search.json`). A type that
/// wasn't searched has an empty list.
class SearchResults {
  final List<EmeProfileModel> people;
  final List<LibraryCollectionModel> projects;

  /// Ids of [projects] the signed-in user is on the team of.
  final Set<String> joinedProjectIds;
  final List<ServerModel> servers;
  final List<EventModel> events;

  const SearchResults({
    this.people = const [],
    this.projects = const [],
    this.joinedProjectIds = const {},
    this.servers = const [],
    this.events = const [],
  });

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(String key) {
      final value = json[key];
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }

    final projectRows = maps('projects');
    return SearchResults(
      people: maps('users').map(EmeProfileModel.fromUserJson).toList(),
      projects: [
        for (final row in projectRows)
          if (row['project'] is Map)
            LibraryCollectionModel.fromJson(
              Map<String, dynamic>.from(row['project'] as Map),
            ),
      ],
      joinedProjectIds: {
        for (final row in projectRows)
          if (row['joined'] == true && row['project'] is Map)
            (row['project'] as Map)['id'].toString(),
      },
      servers: maps('emeservers').map(ServerModel.fromJson).toList(),
      events: maps('events').map(EventModel.fromJson).toList(),
    );
  }
}
