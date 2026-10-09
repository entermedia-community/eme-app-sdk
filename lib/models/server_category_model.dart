class ServerCategoryModel {
  final String id;
  final String name;

  const ServerCategoryModel({required this.id, required this.name});

  static const ServerCategoryModel all = ServerCategoryModel(
    id: 'all',
    name: 'All',
  );

  factory ServerCategoryModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'].toString().trim();
    final name = json['name'].toString().trim();
    return ServerCategoryModel(id: id, name: name);
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
