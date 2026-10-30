/// Model representing an EnterMedia [librarycollection] (a project).
///
/// Holds only the fields the web project chat page renders
/// (`plugins/community/html/default/project`): the header and menu
/// (name, logo, banner, contact, privacy), and the right sidebar
/// (team, donate box, testimonials, social links). Parsed from
/// `GET /services/module/librarycollection/data/{id}`, whose `hit.json`
/// adds `logo` and `team` to the stored fields.
class LibraryCollectionModel {
  final String id;
  final String name;
  final String? urlName;
  final String? description;

  /// User id of the project's `owner`.
  final String? ownerId;

  /// Search keywords (`collectivetags`).
  final List<String> tags;

  /// `collectiontype` list id. `"5"` is a proposal.
  final String? collectionType;

  /// `priviacylevel` (sic, server spelling): `community`, `commercial`, ...
  final String? privacyLevel;

  /// Asset id of the portrait/logo.
  final String? assetPortrait;

  /// Asset id of the banner image.
  final String? collectiveBanner;

  /// Ready-to-use logo preview URL, provided by the server's `hit.json`.
  final String? logoUrl;
  final String? contactEmail;

  /// The project's web address (community domain + `urlname`), as the web
  /// menu builds it. Relative (`/urlname`) when the server has no community
  /// domain.
  final String? projectLink;
  final String? donateDescription;

  /// HTML from the project's Testimonials settings.
  final String? proposalTestimonials;
  final String? websiteLink;
  final String? facebookLink;
  final String? instagramLink;

  /// Members with `ontheteam=true` ("Agents" in the web sidebar).
  final List<ProjectTeamMember> team;

  /// Enabled `librarycollectionlikes` rows ("Followers" in the web sidebar).
  final int followerCount;

  /// Null when the request was anonymous.
  final bool? followedByUser;

  const LibraryCollectionModel({
    required this.id,
    required this.name,
    this.urlName,
    this.description,
    this.ownerId,
    this.tags = const [],
    this.collectionType,
    this.privacyLevel,
    this.assetPortrait,
    this.collectiveBanner,
    this.logoUrl,
    this.contactEmail,
    this.projectLink,
    this.donateDescription,
    this.proposalTestimonials,
    this.websiteLink,
    this.facebookLink,
    this.instagramLink,
    this.team = const [],
    this.followerCount = 0,
    this.followedByUser,
  });

  /// Image to show for the project. Only [logoUrl] is a URL; the asset ids
  /// are not.
  String? get primaryImageUrl => logoUrl;

  String get displayDescription => description?.trim() ?? '';

  bool get isProposal => collectionType == '5';

  /// Web hides chat for anonymous users and the team list from non-members
  /// on commercial projects.
  bool get isCommercial => privacyLevel == 'commercial';

  /// Web only shows the Donate box on community projects.
  bool get acceptsDonations => privacyLevel == 'community';

  bool isOwnedBy(String? userId) =>
      userId != null && ownerId != null && ownerId == userId;

  bool isOnTeam(String? userId) =>
      userId != null && team.any((m) => m.userId == userId);

  LibraryCollectionModel copyWithFollow(ProjectFollowState follow) {
    return LibraryCollectionModel(
      id: id,
      name: name,
      urlName: urlName,
      description: description,
      ownerId: ownerId,
      tags: tags,
      collectionType: collectionType,
      privacyLevel: privacyLevel,
      assetPortrait: assetPortrait,
      collectiveBanner: collectiveBanner,
      logoUrl: logoUrl,
      contactEmail: contactEmail,
      projectLink: projectLink,
      donateDescription: donateDescription,
      proposalTestimonials: proposalTestimonials,
      websiteLink: websiteLink,
      facebookLink: facebookLink,
      instagramLink: instagramLink,
      team: team,
      followerCount: follow.followerCount,
      followedByUser: follow.following,
    );
  }

  /// Absolute URL of a page under the project's web address, e.g.
  /// `donate/index.html`. Relative links resolve against [siteRoot].
  String? webUrl(String siteRoot, [String path = '']) {
    final link = projectLink ?? (urlName != null ? '/$urlName' : null);
    if (link == null) return null;
    final base = link.startsWith('http')
        ? link
        : '${siteRoot.endsWith('/') ? siteRoot.substring(0, siteRoot.length - 1) : siteRoot}$link';
    return path.isEmpty ? base : '$base/$path';
  }

  bool get hasSocialLinks =>
      _notEmpty(websiteLink) ||
      _notEmpty(facebookLink) ||
      _notEmpty(instagramLink);

  static bool _notEmpty(String? value) => value != null && value.isNotEmpty;

  /// Reads a field as the server's `#json` writes it: plain values, list
  /// fields as `{"id", "name"}` (the id is returned) and translated text as
  /// `{"en": ...}`.
  static String? _string(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return _string(value['id'] ?? value['en'] ?? value.values.firstOrNull);
    }
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  /// Ids of a multi-value field: a list of values or `{"id"}` maps, or a
  /// `,`/`|` separated string.
  static List<String> _ids(dynamic value) {
    if (value is List) {
      return value.map(_string).whereType<String>().toList();
    }
    final str = _string(value);
    if (str == null) return const [];
    return str
        .split(RegExp(r'[,|]'))
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();
  }

  factory LibraryCollectionModel.fromJson(Map<String, dynamic> json) {
    final team = json['team'];
    return LibraryCollectionModel(
      id: json['id']?.toString() ?? '',
      name:
          _string(json['name']) ??
          _string(json['urlname']) ??
          json['id']?.toString() ??
          '',
      urlName: _string(json['urlname']),
      // `description` holds the search keywords, not prose.
      description: _string(json['collectivedescription']),
      ownerId: _string(json['owner']),
      tags: _ids(json['collectivetags']),
      collectionType: _string(json['collectiontype']),
      privacyLevel: _string(json['priviacylevel']),
      assetPortrait: _string(json['assetportrait']),
      collectiveBanner: _string(json['collectivebanner']),
      logoUrl: _string(json['logo']),
      contactEmail: _string(json['contactemail']),
      projectLink: _string(json['projectlink']),
      donateDescription: _string(json['donatedescription']),
      proposalTestimonials: _string(json['proposaltestimonials']),
      websiteLink: _string(json['websitelink']),
      facebookLink: _string(json['facebooklink']),
      instagramLink: _string(json['instagramlink']),
      team: team is List
          ? team
                .whereType<Map<String, dynamic>>()
                .map(ProjectTeamMember.fromJson)
                .toList()
          : const [],
      followerCount: int.tryParse('${json['followercount'] ?? ''}') ?? 0,
      followedByUser: json['followedbyuser'] is bool
          ? json['followedbyuser'] as bool
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (urlName != null) 'urlname': urlName,
      if (description != null) 'description': description,
      if (ownerId != null) 'owner': ownerId,
      if (tags.isNotEmpty) 'collectivetags': tags,
      if (collectionType != null) 'collectiontype': collectionType,
      if (privacyLevel != null) 'priviacylevel': privacyLevel,
      if (assetPortrait != null) 'assetportrait': assetPortrait,
      if (collectiveBanner != null) 'collectivebanner': collectiveBanner,
      if (logoUrl != null) 'logo': logoUrl,
      if (contactEmail != null) 'contactemail': contactEmail,
      if (projectLink != null) 'projectlink': projectLink,
      if (donateDescription != null) 'donatedescription': donateDescription,
      if (proposalTestimonials != null)
        'proposaltestimonials': proposalTestimonials,
      if (websiteLink != null) 'websitelink': websiteLink,
      if (facebookLink != null) 'facebooklink': facebookLink,
      if (instagramLink != null) 'instagramlink': instagramLink,
      if (team.isNotEmpty) 'team': team.map((m) => m.toJson()).toList(),
      'followercount': followerCount,
      if (followedByUser != null) 'followedbyuser': followedByUser,
    };
  }
}

/// A `librarycollectionusers` row on the project's team, as returned in the
/// `team` array of the collection's `hit.json`.
class ProjectTeamMember {
  /// The `librarycollectionusers` row id, used to edit the membership.
  final String? memberId;
  final String userId;
  final String? screenName;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? portraitUrl;

  /// `collectiverole` ids.
  final List<String> teamRoles;

  /// Role names for [teamRoles], as the web sidebar shows them.
  final List<String> teamRoleNames;

  const ProjectTeamMember({
    this.memberId,
    required this.userId,
    this.screenName,
    this.firstName,
    this.lastName,
    this.email,
    this.portraitUrl,
    this.teamRoles = const [],
    this.teamRoleNames = const [],
  });

  /// Role names when the server sent them, else the ids.
  List<String> get roleLabels =>
      teamRoleNames.isNotEmpty ? teamRoleNames : teamRoles;

  String get displayName {
    final full = [
      firstName,
      lastName,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    if (screenName != null && screenName!.isNotEmpty) return screenName!;
    return userId;
  }

  factory ProjectTeamMember.fromJson(Map<String, dynamic> json) {
    final roles = json['teamroles'];
    final roleNames = json['teamrolenames'];
    return ProjectTeamMember(
      memberId: LibraryCollectionModel._string(json['id']),
      userId:
          LibraryCollectionModel._string(json['userid']) ??
          LibraryCollectionModel._string(json['followeruser']) ??
          '',
      screenName: LibraryCollectionModel._string(json['screenname']),
      firstName: LibraryCollectionModel._string(json['firstName']),
      lastName: LibraryCollectionModel._string(json['lastName']),
      email: LibraryCollectionModel._string(json['email']),
      portraitUrl: LibraryCollectionModel._string(json['portrait']),
      teamRoles: LibraryCollectionModel._ids(roles),
      teamRoleNames: roleNames is List
          ? roleNames
                .map((r) => r.toString())
                .where((r) => r.isNotEmpty)
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (memberId != null) 'id': memberId,
      'userid': userId,
      if (screenName != null) 'screenname': screenName,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (email != null) 'email': email,
      if (portraitUrl != null) 'portrait': portraitUrl,
      if (teamRoles.isNotEmpty) 'teamroles': teamRoles,
      if (teamRoleNames.isNotEmpty) 'teamrolenames': teamRoleNames,
    };
  }
}

/// Result of `librarycollection/connectchat.json`: the project's team chat
/// channel and whether the user may edit the project (web `caneditcollection`:
/// administrator or on the team).
class ProjectChatConnection {
  final String channelId;
  final String? topicId;
  final bool canEditCollection;

  /// Web `canviewsettings`: may edit team members' roles and membership.
  final bool canViewSettings;

  const ProjectChatConnection({
    required this.channelId,
    this.topicId,
    this.canEditCollection = false,
    this.canViewSettings = false,
  });

  factory ProjectChatConnection.fromJson(Map<String, dynamic> json) {
    final topic = json['topic']?.toString() ?? '';
    return ProjectChatConnection(
      channelId: json['channel']?.toString() ?? '',
      topicId: topic.isEmpty ? null : topic,
      canEditCollection: json['caneditcollection'] == true,
      canViewSettings: json['canviewsettings'] == true,
    );
  }
}

/// Result of `librarycollection/togglefollow.json`.
class ProjectFollowState {
  final bool following;
  final int followerCount;

  const ProjectFollowState({
    required this.following,
    required this.followerCount,
  });

  factory ProjectFollowState.fromJson(Map<String, dynamic> json) {
    return ProjectFollowState(
      following: json['following'] == true,
      followerCount: int.tryParse('${json['followercount'] ?? ''}') ?? 0,
    );
  }
}

/// A `collectiverole` a team member can have (`teamroles.json`).
class ProjectTeamRole {
  final String id;
  final String name;

  const ProjectTeamRole({required this.id, required this.name});

  factory ProjectTeamRole.fromJson(Map<String, dynamic> json) {
    final id = LibraryCollectionModel._string(json['id']) ?? '';
    return ProjectTeamRole(
      id: id,
      name: LibraryCollectionModel._string(json['name']) ?? id,
    );
  }
}
