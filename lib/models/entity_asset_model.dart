/// An entity asset (`entityasset`) from `entityasset/assets.json`.
class EntityAssetModel {
  final String id;
  final String name;
  final String description;
  final DateTime? date;
  final String? sourceType;
  final String? imageUrl;
  final String? emeProfileId;
  final String? collectionId;
  final List<String> tags;
  final DateTime? uploadDate;

  /// URL of the original file; null when the entity has no file.
  final String? mediaUrl;

  /// `image`, `video`, `pdf` or `other`.
  final String? mediaType;
  final String? fileName;

  const EntityAssetModel({
    required this.id,
    required this.name,
    this.description = '',
    this.date,
    this.sourceType,
    this.imageUrl,
    this.emeProfileId,
    this.collectionId,
    this.tags = const [],
    this.uploadDate,
    this.mediaUrl,
    this.mediaType,
    this.fileName,
  });

  factory EntityAssetModel.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final v = json[key]?.toString();
      return (v == null || v.isEmpty) ? null : v;
    }

    return EntityAssetModel(
      id: json['id']?.toString() ?? '',
      name: text('name') ?? '',
      description: text('description') ?? '',
      date: DateTime.tryParse(text('date') ?? ''),
      sourceType: text('sourcetype'),
      imageUrl: text('imageurl'),
      emeProfileId: text('emeprofile'),
      collectionId: text('collectionid'),
      tags: [
        if (json['tags'] is List)
          for (final t in json['tags'] as List)
            if (t.toString().isNotEmpty) t.toString(),
      ],
      uploadDate: DateTime.tryParse(text('uploaddate') ?? ''),
      mediaUrl: text('mediaurl'),
      mediaType: text('mediatype'),
      fileName: text('filename'),
    );
  }
}
