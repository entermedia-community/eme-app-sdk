/// An entity asset (`entityasset`) from `entityasset/assets.json`.
class EntityAssetModel {
  final String id;
  final String name;
  final String description;
  final DateTime? date;
  final String? sourceType;
  final String? imageUrl;

  /// `ready`, `pending` (still converting), `error`; null without an image.
  final String? thumbStatus;

  /// Id of the asset behind [imageUrl], for polling its conversion.
  final String? imageAssetId;
  final String? emeProfileId;
  final String? collectionId;
  final List<String> tags;
  final DateTime? uploadDate;

  /// URL of the original file; null when the entity has no file.
  final String? mediaUrl;

  /// `image`, `video`, `pdf` or `other`.
  final String? mediaType;
  final String? fileName;

  /// Whether the thumbnail is still being generated.
  bool get thumbPending => thumbStatus == 'pending';

  const EntityAssetModel({
    required this.id,
    required this.name,
    this.description = '',
    this.date,
    this.sourceType,
    this.imageUrl,
    this.thumbStatus,
    this.imageAssetId,
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
      thumbStatus: text('thumbstatus'),
      imageAssetId: text('imageassetid'),
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

/// Conversion state of one asset (`entityasset/previewstatus.json`).
class AssetPreviewStatus {
  final String assetId;

  /// `ready`, `pending` or `error`.
  final String state;

  /// Thumbnail URL, once [state] is `ready`.
  final String? url;

  const AssetPreviewStatus({
    required this.assetId,
    required this.state,
    this.url,
  });

  bool get isPending => state == 'pending';
  bool get isReady => state == 'ready';

  factory AssetPreviewStatus.fromJson(Map<String, dynamic> json) {
    final url = json['previewurl']?.toString();
    return AssetPreviewStatus(
      assetId: json['assetid']?.toString() ?? '',
      state: json['previewstate']?.toString() ?? 'pending',
      url: (url == null || url.isEmpty) ? null : url,
    );
  }
}
