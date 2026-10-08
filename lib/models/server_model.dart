import 'package:flutter/material.dart';

class ServerModel {
  final String id;
  final String title;
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
    if (title.isNotEmpty) {
      final words = title.trim().split(RegExp(r'\s+'));
      if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
        return (words[0][0] + words[1][0]).toUpperCase();
      }
      return title.substring(0, title.length.clamp(1, 2)).toUpperCase();
    }
    return id.substring(0, id.length.clamp(1, 2)).toUpperCase();
  }

  String get categoryLabel =>
      (category != null && category!.isNotEmpty) ? category! : 'General';

  const ServerModel({
    required this.id,
    required this.title,
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
    String? title,
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
      title: title ?? this.title,
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
    return ServerModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      primaryColor: json['primaryColor'] != null
          ? Color(json['primaryColor'] as int)
          : const Color(0xFF2563EB),
      secondaryColor: json['secondaryColor'] != null
          ? Color(json['secondaryColor'] as int)
          : const Color(0xFFEFF6FF),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 120,
      isJoined: json['isJoined'] as bool? ?? false,
      servicesOffered:
          (json['servicesOffered'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      avatarUrl: json['avatarUrl'] as String?,
      lastNotification: json['lastNotification'] as String?,
      lastNotificationTime: json['lastNotificationTime'] as String?,
      statusColor: json['statusColor'] != null
          ? Color(json['statusColor'] as int)
          : null,
      serverMediaDBUrl: json['serverMediaDBUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
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
