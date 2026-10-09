import 'package:flutter/material.dart';

class ServerModel {
  final String id;
  final String name;
  final String? subtitle;
  final String description;
  final String? category;
  final Color primaryColor;
  final Color secondaryColor;
  final int memberCount;
  final bool isJoined;
  final List<String> servicesOffered;
  final String? avatarUrl;
  final String? lastNotification;
  final String? lastNotificationTime;
  final Color? statusColor;
  final String serverMediaDBUrl;
  final String serverFunction;

  String get displayInitials {
    if (name.isNotEmpty) {
      final words = name.trim().split(RegExp(r'\s+'));
      if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
        return (words[0][0] + words[1][0]).toUpperCase();
      }
      return name.substring(0, name.length.clamp(1, 2)).toUpperCase();
    }
    return id.substring(0, id.length.clamp(1, 2)).toUpperCase();
  }

  String get categoryLabel =>
      (category != null && category!.isNotEmpty) ? category! : 'General';

  const ServerModel({
    required this.id,
    required this.name,
    this.subtitle,
    required this.description,
    required this.category,
    this.primaryColor = const Color(0xFF2563EB),
    this.secondaryColor = const Color(0xFFEFF6FF),
    this.memberCount = 120,
    this.isJoined = false,
    this.servicesOffered = const [],
    this.avatarUrl,
    this.lastNotification,
    this.lastNotificationTime,
    this.statusColor,
    this.serverMediaDBUrl = '',
    this.serverFunction = '',
  });

  ServerModel copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? description,
    String? category,
    Color? primaryColor,
    Color? secondaryColor,
    int? memberCount,
    bool? isJoined,
    List<String>? servicesOffered,
    String? avatarUrl,
    String? lastNotification,
    String? lastNotificationTime,
    Color? statusColor,
    String? serverMediaDBUrl,
    String? serverFunction,
  }) {
    return ServerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      category: category ?? this.category,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      memberCount: memberCount ?? this.memberCount,
      isJoined: isJoined ?? this.isJoined,
      servicesOffered: servicesOffered ?? this.servicesOffered,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastNotification: lastNotification ?? this.lastNotification,
      lastNotificationTime: lastNotificationTime ?? this.lastNotificationTime,
      statusColor: statusColor ?? this.statusColor,
      serverMediaDBUrl: serverMediaDBUrl ?? this.serverMediaDBUrl,
      serverFunction: serverFunction ?? this.serverFunction,
    );
  }

  factory ServerModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['serverid'] ?? json['_id'] ?? '').toString();
    final subtitle =
        json['subtitle'] as String? ?? json['shortdescription'] as String?;
    final description =
        (json['description'] ??
                json['serverdescription'] ??
                json['details'] ??
                '')
            .toString();
    final category = (json['category'] ?? json['servercategory'] ?? '')
        .toString();
    final primaryColor = _parseColor(
      json['primaryColor'] ?? json['primarycolor'],
      const Color(0xFF2563EB),
    );
    final secondaryColor = _parseColor(
      json['secondaryColor'] ?? json['secondarycolor'],
      const Color(0xFFEFF6FF),
    );
    final memberCount =
        int.tryParse(
          (json['memberCount'] ?? json['membercount'] ?? json['members'] ?? '')
              .toString(),
        ) ??
        0;
    final isJoined = _parseBool(
      json['isJoined'] ?? json['joined'] ?? json['is_joined'],
    );
    final servicesOffered = _parseList(
      json['servicesOffered'] ??
          json['servicesoffered'] ??
          json['services'] ??
          json['tags'],
    );
    final avatarUrl =
        (json['avatarUrl'] ??
                json['avatarurl'] ??
                json['iconasset'] ??
                json['iconurl'] ??
                json['icon'])
            as String?;
    final lastNotification =
        (json['lastNotification'] ??
                json['lastnotification'] ??
                json['notification'])
            as String?;
    final lastNotificationTime =
        (json['lastNotificationTime'] ?? json['lastnotificationtime'])
            as String?;
    final statusColor =
        json['statusColor'] != null || json['statuscolor'] != null
        ? _parseColor(json['statusColor'] ?? json['statuscolor'], primaryColor)
        : null;
    final serverMediaDBUrl =
        (json['serverMediaDBUrl'] ??
                json['servermediadburl'] ??
                json['mediadburl'] ??
                json['url'] ??
                '')
            .toString();
    final serverFunction =
        (json['serverFunction'] ??
                json['serverfunction'] ??
                json['function'] ??
                '')
            .toString();

    return ServerModel(
      id: id,
      name: json['name'],
      subtitle: subtitle,
      description: description,
      category: category,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      memberCount: memberCount,
      isJoined: isJoined,
      servicesOffered: servicesOffered,
      avatarUrl: avatarUrl,
      lastNotification: lastNotification,
      lastNotificationTime: lastNotificationTime,
      statusColor: statusColor,
      serverMediaDBUrl: serverMediaDBUrl,
      serverFunction: serverFunction,
    );
  }

  static Color _parseColor(dynamic val, Color fallback) {
    if (val == null) return fallback;
    if (val is int) return Color(val);
    if (val is String) {
      var hex = val.trim();
      if (hex.isEmpty) return fallback;
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      } else if (hex.startsWith('0x') || hex.startsWith('0X')) {
        hex = hex.substring(2);
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) {
        return Color(parsed);
      }
    }
    return fallback;
  }

  static bool _parseBool(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      final s = val.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  static List<String> _parseList(dynamic val) {
    if (val == null) return const [];
    if (val is List) {
      return val
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (val is String) {
      if (val.trim().isEmpty) return const [];
      if (val.contains(',')) {
        return val
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (val.contains('|')) {
        return val
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [val.trim()];
    }
    return const [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (subtitle != null) 'subtitle': subtitle,
      'description': description,
      'category': category,
      'primaryColor': primaryColor.toARGB32(),
      'secondaryColor': secondaryColor.toARGB32(),
      'memberCount': memberCount,
      'isJoined': isJoined,
      'servicesOffered': servicesOffered,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (lastNotification != null) 'lastNotification': lastNotification,
      if (lastNotificationTime != null)
        'lastNotificationTime': lastNotificationTime,
      if (statusColor != null) 'statusColor': statusColor!.toARGB32(),
      'serverMediaDBUrl': serverMediaDBUrl,
      'serverFunction': serverFunction,
    };
  }
}
