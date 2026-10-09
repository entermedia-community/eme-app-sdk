class ServerCategoryModel {
  final String id;
  final String name;

  const ServerCategoryModel({required this.id, required this.name});

  static const ServerCategoryModel all = ServerCategoryModel(
    id: 'all',
    name: 'All',
  );

  factory ServerCategoryModel.fromJson(dynamic json) {
    if (json is ServerCategoryModel) return json;
    if (json is Map) {
      final id = json['id'].toString().trim();
      final name = (json['name'] ?? json['id']).toString().trim();
      return ServerCategoryModel(
        id: id.isNotEmpty ? id : 'general',
        name: name.isNotEmpty ? name : 'General',
      );
    }
    if (json is String && json.trim().isNotEmpty) {
      final str = json.trim();
      return ServerCategoryModel(id: str, name: str);
    }
    return const ServerCategoryModel(id: 'general', name: 'General');
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerCategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
