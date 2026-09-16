import 'package:flutter/material.dart';

class FileItemModel {
  final String id;
  final String name;
  final String category;
  final String size;
  final String updatedAt;
  final IconData icon;
  final Color color;
  final bool isFolder;

  const FileItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.size,
    required this.updatedAt,
    required this.icon,
    required this.color,
    this.isFolder = false,
  });

  FileItemModel copyWith({
    String? id,
    String? name,
    String? category,
    String? size,
    String? updatedAt,
    IconData? icon,
    Color? color,
    bool? isFolder,
  }) {
    return FileItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      size: size ?? this.size,
      updatedAt: updatedAt ?? this.updatedAt,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isFolder: isFolder ?? this.isFolder,
    );
  }

  factory FileItemModel.fromJson(Map<String, dynamic> json) {
    return FileItemModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      size: json['size'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      icon: json['iconCodePoint'] != null
          // ignore: non_const_argument_for_const_parameter
          ? IconData(json['iconCodePoint'] as int, fontFamily: 'MaterialIcons')
          : Icons.insert_drive_file_rounded,
      color: json['color'] != null
          ? Color(json['color'] as int)
          : const Color(0xFF3B82F6),
      isFolder: json['isFolder'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'size': size,
      'updatedAt': updatedAt,
      'iconCodePoint': icon.codePoint,
      'color': color.toARGB32(),
      'isFolder': isFolder,
    };
  }
}
