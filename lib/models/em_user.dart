import 'dart:convert';

class EmUser {
  final String userid;
  final String? email;
  final String? firstname;
  final String? lastname;
  final String? screenname;
  final String? assetportrait;
  final String? dataconsent;
  final String entermediakey;
  final Map<String, dynamic> properties;

  String get id => userid;

  EmUser({
    required this.userid,
    this.email,
    this.firstname,
    this.lastname,
    this.screenname,
    this.assetportrait,
    this.dataconsent,
    this.entermediakey = '',
    this.properties = const {},
  });

  factory EmUser.fromJson(Map<String, dynamic> json) {
    final rawId = (json['id'] ?? json['userid'] ?? '').toString();
    final rawEmail = json['email']?.toString();
    final rawFirst = (json['firstname'] ?? json['firstName'] ?? json['first_name'])?.toString();
    final rawLast = (json['lastname'] ?? json['lastName'] ?? json['last_name'])?.toString();
    final rawScreen = (json['screenname'] ?? json['screenName'] ?? json['screen_name'])?.toString();
    final rawPortrait = (json['assetportrait'] ?? json['assetPortrait'])?.toString();
    final rawConsent = (json['dataconsent'] ?? json['dataConsent'])?.toString();
    final rawKey = (json['entermediakey'] ?? json['token'] ?? '').toString();

    return EmUser(
      userid: rawId,
      email: rawEmail,
      firstname: rawFirst,
      lastname: rawLast,
      screenname: rawScreen,
      assetportrait: rawPortrait,
      dataconsent: rawConsent,
      entermediakey: rawKey,
      properties: Map<String, dynamic>.from(json),
    );
  }

  String get fullName {
    final first = firstname ?? '';
    final last = lastname ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    return screenname ?? email ?? userid;
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
      'id': userid,
      'userid': userid,
      if (email != null) 'email': email,
      if (firstname != null) 'firstname': firstname,
      if (lastname != null) 'lastname': lastname,
      if (screenname != null) 'screenname': screenname,
      if (assetportrait != null) 'assetportrait': assetportrait,
      if (dataconsent != null) 'dataconsent': dataconsent,
      'entermediakey': entermediakey,
      ...properties,
    };
  }

  String toJson() {
    return jsonEncode(toMap());
  }

  EmUser copyWith({
    String? userid,
    String? email,
    String? firstname,
    String? lastname,
    String? screenname,
    String? assetportrait,
    String? dataconsent,
    String? entermediakey,
    Map<String, dynamic>? properties,
  }) {
    return EmUser(
      userid: userid ?? this.userid,
      email: email ?? this.email,
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      screenname: screenname ?? this.screenname,
      assetportrait: assetportrait ?? this.assetportrait,
      dataconsent: dataconsent ?? this.dataconsent,
      entermediakey: entermediakey ?? this.entermediakey,
      properties: properties ?? this.properties,
    );
  }
}
