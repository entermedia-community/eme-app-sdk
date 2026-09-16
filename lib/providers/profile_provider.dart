import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_model.dart';
import '../services/api_service.dart';
import 'api_providers.dart';

class ProfileNotifier extends StateNotifier<ProfileModel> {
  final IApiService? apiService;

  ProfileNotifier({this.apiService})
      : super(
        const ProfileModel(
          id: 'usr_001',
          name: 'Christopher.B',
          role: 'CEO',
          bio: 'Cool guy',
          tags: ['Programmer', 'Dude'],
          avatarUrl: 'https://randomuser.me/api/portraits/men/79.jpg',
          portfolioLabel: 'PORTFOLIO',
          totalServers: 8,
          totalConnections: 248,
        ),
      );

  Future<void> loadProfileFromApi({String? userId}) async {
    if (apiService == null) return;
    try {
      final fetched = await apiService!.fetchUserProfile(userId: userId);
      state = fetched;
    } catch (_) {
      // Keep current state on failure
    }
  }

  void updateProfile({
    String? name,
    String? role,
    String? bio,
    List<String>? tags,
  }) {
    state = state.copyWith(name: name, role: role, bio: bio, tags: tags);
  }

  void addTag(String tag) {
    if (tag.trim().isEmpty || state.tags.contains(tag.trim())) return;
    state = state.copyWith(tags: [...state.tags, tag.trim()]);
  }

  void removeTag(String tag) {
    state = state.copyWith(tags: state.tags.where((t) => t != tag).toList());
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileModel>((
  ref,
) {
  final api = ref.watch(apiServiceProvider);
  return ProfileNotifier(apiService: api);
});
