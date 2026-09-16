import 'package:flutter/material.dart';

class ChatModel {
  final String id;
  final String userName;
  final String userRole;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final Color avatarColor;
  final bool isOnline;
  final String? avatarInitials;

  const ChatModel({
    required this.id,
    required this.userName,
    required this.userRole,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    required this.avatarColor,
    this.isOnline = false,
    this.avatarInitials,
  });

  ChatModel copyWith({
    String? id,
    String? userName,
    String? userRole,
    String? lastMessage,
    String? time,
    int? unreadCount,
    Color? avatarColor,
    bool? isOnline,
    String? avatarInitials,
  }) {
    return ChatModel(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      avatarColor: avatarColor ?? this.avatarColor,
      isOnline: isOnline ?? this.isOnline,
      avatarInitials: avatarInitials ?? this.avatarInitials,
    );
  }

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      userRole: json['userRole'] as String? ?? '',
      lastMessage: json['lastMessage'] as String? ?? '',
      time: json['time'] as String? ?? '',
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      avatarColor: json['avatarColor'] != null
          ? Color(json['avatarColor'] as int)
          : const Color(0xFF2563EB),
      isOnline: json['isOnline'] as bool? ?? false,
      avatarInitials: json['avatarInitials'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userName': userName,
      'userRole': userRole,
      'lastMessage': lastMessage,
      'time': time,
      'unreadCount': unreadCount,
      'avatarColor': avatarColor.toARGB32(),
      'isOnline': isOnline,
      if (avatarInitials != null) 'avatarInitials': avatarInitials,
    };
  }
}
