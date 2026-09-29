import 'dart:convert';

class EmUser {
  final String username;
  final String? email;
  final String? firstname;
  final String? lastname;
  final String? screenname;
  final String? assetportrait;
  final String? dataconsent;
  final Map<String, dynamic> properties;

  EmUser({
    required this.username,
    this.email,
    this.firstname,
    this.lastname,
    this.screenname,
    this.assetportrait,
    this.dataconsent,
    this.properties = const {},
  });

  factory EmUser.fromJson(Map<String, dynamic> json) {
    final rawEmail = json['email']?.toString();
    final rawFirst = (json['firstname'])?.toString();
    final rawLast = (json['lastname'])?.toString();
    final rawScreen = (json['screenname'])?.toString();
    final rawPortrait = (json['assetportrait'])?.toString();
    final rawConsent = (json['dataconsent'])?.toString();

    return EmUser(
      username: json['username'],
      email: rawEmail,
      firstname: rawFirst,
      lastname: rawLast,
      screenname: rawScreen,
      assetportrait: rawPortrait,
      dataconsent: rawConsent,
      properties: Map<String, dynamic>.from(json),
    );
  }

  String get fullName {
    final first = firstname ?? '';
    final last = lastname ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    return screenname ?? email ?? username;
  }

  String get displayName {
    if (screenname != null && screenname!.trim().isNotEmpty) {
      return screenname!.trim();
    }
    return fullName;
  }

  String get avatarInitials {
    final name = displayName.trim();
    if (name.isEmpty) return 'EM';
    final parts = name.split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      if (email != null) 'email': email,
      if (firstname != null) 'firstname': firstname,
      if (lastname != null) 'lastname': lastname,
      if (screenname != null) 'screenname': screenname,
      if (assetportrait != null) 'assetportrait': assetportrait,
      if (dataconsent != null) 'dataconsent': dataconsent,
      ...properties,
    };
  }

  String toJson() {
    return jsonEncode(toMap());
  }

  EmUser copyWith({
    String? username,
    String? email,
    String? firstname,
    String? lastname,
    String? screenname,
    String? assetportrait,
    String? dataconsent,
    Map<String, dynamic>? properties,
  }) {
    return EmUser(
      username: username ?? this.username,
      email: email ?? this.email,
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      screenname: screenname ?? this.screenname,
      assetportrait: assetportrait ?? this.assetportrait,
      dataconsent: dataconsent ?? this.dataconsent,
      properties: properties ?? this.properties,
    );
  }
}
