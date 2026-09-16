class ProfileModel {
  final String id;
  final String name;
  final String role;
  final String bio;
  final List<String> tags;
  final String? avatarUrl;
  final String portfolioLabel;
  final int totalServers;
  final int totalConnections;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.role,
    required this.bio,
    required this.tags,
    this.avatarUrl,
    this.portfolioLabel = 'PORTFOLIO',
    this.totalServers = 8,
    this.totalConnections = 142,
  });

  ProfileModel copyWith({
    String? id,
    String? name,
    String? role,
    String? bio,
    List<String>? tags,
    String? avatarUrl,
    String? portfolioLabel,
    int? totalServers,
    int? totalConnections,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      tags: tags ?? this.tags,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      portfolioLabel: portfolioLabel ?? this.portfolioLabel,
      totalServers: totalServers ?? this.totalServers,
      totalConnections: totalConnections ?? this.totalConnections,
    );
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      avatarUrl: json['avatarUrl'] as String?,
      portfolioLabel: json['portfolioLabel'] as String? ?? 'PORTFOLIO',
      totalServers: (json['totalServers'] as num?)?.toInt() ?? 8,
      totalConnections: (json['totalConnections'] as num?)?.toInt() ?? 142,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'bio': bio,
      'tags': tags,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'portfolioLabel': portfolioLabel,
      'totalServers': totalServers,
      'totalConnections': totalConnections,
    };
  }
}
