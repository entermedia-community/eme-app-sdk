import 'package:flutter/material.dart';

/// Categories available for servers/nodes
enum ServerCategory {
  rentalAndGear('Rental & Gear'),
  mobilityAndRides('Mobility & Rides'),
  marketplaceAndGoods('Marketplace & Goods'),
  ecoTourism('Eco Tourism'),
  finance('Finance'),
  artificialIntelligence('Artificial Intelligence'),
  socialServices('Social Services'),
  softwareTools('Software Tools'),
  research('Research'),
  education('Education'),
  healthcare('Healthcare'),
  startup('Startup');

  final String label;
  const ServerCategory(this.label);

  static ServerCategory fromString(String value) {
    return ServerCategory.values.firstWhere(
      (e) =>
          e.name.toLowerCase() == value.toLowerCase() ||
          e.label.toLowerCase() == value.toLowerCase(),
      orElse: () => ServerCategory.softwareTools,
    );
  }
}

class ServerModel {
  final String id;
  final String title;
  final String? subtitle;
  final String description;
  final ServerCategory category;
  final List<String> tags;
  final IconData iconData;
  final Color primaryColor;
  final Color secondaryColor;
  final int memberCount;
  final bool isJoined;
  final String? bannerSvgOrType;
  final double? rating;
  final int? reviewsCount;
  final String? servicePricing;
  final String? location;
  final bool isVerified;
  final List<String> servicesOffered;
  final String? avatarUrl;
  final String? lastNotification;
  final String? lastNotificationTime;
  final Color? statusColor;

  const ServerModel({
    required this.id,
    required this.title,
    this.subtitle,
    required this.description,
    required this.category,
    required this.tags,
    required this.iconData,
    this.primaryColor = const Color(0xFF2563EB),
    this.secondaryColor = const Color(0xFFEFF6FF),
    this.memberCount = 120,
    this.isJoined = false,
    this.bannerSvgOrType,
    this.rating,
    this.reviewsCount,
    this.servicePricing,
    this.location,
    this.isVerified = true,
    this.servicesOffered = const [],
    this.avatarUrl,
    this.lastNotification,
    this.lastNotificationTime,
    this.statusColor,
  });

  ServerModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    ServerCategory? category,
    List<String>? tags,
    IconData? iconData,
    Color? primaryColor,
    Color? secondaryColor,
    int? memberCount,
    bool? isJoined,
    String? bannerSvgOrType,
    double? rating,
    int? reviewsCount,
    String? servicePricing,
    String? location,
    bool? isVerified,
    List<String>? servicesOffered,
    String? avatarUrl,
    String? lastNotification,
    String? lastNotificationTime,
    String? status,
    Color? statusColor,
  }) {
    return ServerModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      iconData: iconData ?? this.iconData,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      memberCount: memberCount ?? this.memberCount,
      isJoined: isJoined ?? this.isJoined,
      bannerSvgOrType: bannerSvgOrType ?? this.bannerSvgOrType,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      servicePricing: servicePricing ?? this.servicePricing,
      location: location ?? this.location,
      isVerified: isVerified ?? this.isVerified,
      servicesOffered: servicesOffered ?? this.servicesOffered,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastNotification: lastNotification ?? this.lastNotification,
      lastNotificationTime: lastNotificationTime ?? this.lastNotificationTime,
      statusColor: statusColor ?? this.statusColor,
    );
  }

  factory ServerModel.fromJson(Map<String, dynamic> json) {
    return ServerModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String? ?? '',
      category: ServerCategory.fromString(json['category'] as String? ?? ''),
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      iconData: json['iconCodePoint'] != null
          // ignore: non_const_argument_for_const_parameter
          ? IconData(json['iconCodePoint'] as int, fontFamily: 'MaterialIcons')
          : Icons.hub_rounded,
      primaryColor: json['primaryColor'] != null
          ? Color(json['primaryColor'] as int)
          : const Color(0xFF2563EB),
      secondaryColor: json['secondaryColor'] != null
          ? Color(json['secondaryColor'] as int)
          : const Color(0xFFEFF6FF),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 120,
      isJoined: json['isJoined'] as bool? ?? false,
      bannerSvgOrType: json['bannerSvgOrType'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewsCount: (json['reviewsCount'] as num?)?.toInt(),
      servicePricing: json['servicePricing'] as String?,
      location: json['location'] as String?,
      isVerified: json['isVerified'] as bool? ?? true,
      servicesOffered: (json['servicesOffered'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      avatarUrl: json['avatarUrl'] as String?,
      lastNotification: json['lastNotification'] as String?,
      lastNotificationTime: json['lastNotificationTime'] as String?,
      statusColor: json['statusColor'] != null
          ? Color(json['statusColor'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      'description': description,
      'category': category.name,
      'tags': tags,
      'iconCodePoint': iconData.codePoint,
      'primaryColor': primaryColor.toARGB32(),
      'secondaryColor': secondaryColor.toARGB32(),
      'memberCount': memberCount,
      'isJoined': isJoined,
      if (bannerSvgOrType != null) 'bannerSvgOrType': bannerSvgOrType,
      if (rating != null) 'rating': rating,
      if (reviewsCount != null) 'reviewsCount': reviewsCount,
      if (servicePricing != null) 'servicePricing': servicePricing,
      if (location != null) 'location': location,
      'isVerified': isVerified,
      'servicesOffered': servicesOffered,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (lastNotification != null) 'lastNotification': lastNotification,
      if (lastNotificationTime != null)
        'lastNotificationTime': lastNotificationTime,
      if (statusColor != null) 'statusColor': statusColor!.toARGB32(),
    };
  }
}
