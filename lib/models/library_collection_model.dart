/// Model representing an EnterMedia [librarycollection] data entity.
///
/// Corresponds to `/catalog/data/fields/librarycollection.xml` in EnterMedia.
class LibraryCollectionModel {
  final String id;
  final String name;
  final String? urlName;
  final String? description;
  final String? collectiveDescription;
  final String? manifesto;
  final String? vision;
  final String? libraryId;
  final String? collectionType;
  final String? visibility;
  final String? projectStatus;
  final String? projectType;
  final String? privacyLevel;
  final String? communityTag;
  final List<String> keywords;
  final List<String> collectiveTags;
  final String? assetPortrait;
  final String? assetBanner;
  final String? collectiveBanner;
  final String? collectionImage;
  final String? invoiceLogo;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String? websiteLink;
  final String? facebookLink;
  final String? twitterLink;
  final String? githubLink;
  final String? linkedInLink;
  final String? instagramLink;
  final String? city;
  final String? country;
  final String? street;
  final String? formattedAddress;
  final String? streamUrl;
  final String? chatParentId;
  final String? timeZone;
  final String? serverStatus;
  final String? organizationStatus;
  final bool featuredCollection;
  final bool automaticTagging;
  final int? revisions;
  final int? totalSessionsUsed;
  final int? remainingSessions;
  final int? totalSessionsPurchased;
  final DateTime? creationDate;
  final DateTime? startDate;
  final DateTime? deliveryDate;
  final DateTime? recordDate;
  final DateTime? lastModifiedDate;
  final Map<String, dynamic> rawProperties;

  const LibraryCollectionModel({
    required this.id,
    required this.name,
    this.urlName,
    this.description,
    this.collectiveDescription,
    this.manifesto,
    this.vision,
    this.libraryId,
    this.collectionType,
    this.visibility,
    this.projectStatus,
    this.projectType,
    this.privacyLevel,
    this.communityTag,
    this.keywords = const [],
    this.collectiveTags = const [],
    this.assetPortrait,
    this.assetBanner,
    this.collectiveBanner,
    this.collectionImage,
    this.invoiceLogo,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.websiteLink,
    this.facebookLink,
    this.twitterLink,
    this.githubLink,
    this.linkedInLink,
    this.instagramLink,
    this.city,
    this.country,
    this.street,
    this.formattedAddress,
    this.streamUrl,
    this.chatParentId,
    this.timeZone,
    this.serverStatus,
    this.organizationStatus,
    this.featuredCollection = false,
    this.automaticTagging = false,
    this.revisions,
    this.totalSessionsUsed,
    this.remainingSessions,
    this.totalSessionsPurchased,
    this.creationDate,
    this.startDate,
    this.deliveryDate,
    this.recordDate,
    this.lastModifiedDate,
    this.rawProperties = const {},
  });

  /// The primary image for display (prioritizes collectionImage, then assetPortrait, then assetBanner).
  String? get primaryImageUrl =>
      collectionImage ?? assetPortrait ?? assetBanner ?? collectiveBanner;

  /// The primary description text available for this collection.
  String get displayDescription =>
      (description?.trim().isNotEmpty ?? false)
          ? description!.trim()
          : ((collectiveDescription?.trim().isNotEmpty ?? false)
              ? collectiveDescription!.trim()
              : (manifesto?.trim().isNotEmpty ?? false
                  ? manifesto!.trim()
                  : (vision?.trim().isNotEmpty ?? false ? vision!.trim() : '')));

  factory LibraryCollectionModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic value) {
      if (value == null) return const [];
      if (value is List) {
        return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      if (value is String) {
        if (value.trim().isEmpty) return const [];
        return value
            .split(RegExp(r'[,|]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value.trim());
      }
      return null;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim());
      return null;
    }

    bool parseBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      final str = value.toString().toLowerCase().trim();
      return str == 'true' || str == '1' || str == 'yes';
    }

    return LibraryCollectionModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ??
          json['name_en']?.toString() ??
          json['urlname']?.toString() ??
          json['id']?.toString() ??
          '',
      urlName: json['urlname']?.toString(),
      description: json['description']?.toString() ?? json['storedescription']?.toString(),
      collectiveDescription: json['collectivedescription']?.toString(),
      manifesto: json['manifesto']?.toString(),
      vision: json['vision']?.toString(),
      libraryId: json['library']?.toString(),
      collectionType: json['collectiontype']?.toString(),
      visibility: json['visibility']?.toString(),
      projectStatus: json['projectstatus']?.toString(),
      projectType: json['projecttype']?.toString(),
      privacyLevel: json['priviacylevel']?.toString(),
      communityTag: json['communitytag']?.toString(),
      keywords: parseList(json['keywords']),
      collectiveTags: parseList(json['collectivetags']),
      assetPortrait: json['assetportrait']?.toString(),
      assetBanner: json['assetbanner']?.toString(),
      collectiveBanner: json['collectivebanner']?.toString(),
      collectionImage: json['collectionimage']?.toString(),
      invoiceLogo: json['invoicelogo']?.toString(),
      contactName: json['contactname']?.toString(),
      contactEmail: json['contactemail']?.toString(),
      contactPhone: json['contactphone']?.toString(),
      websiteLink: json['websitelink']?.toString(),
      facebookLink: json['facebooklink']?.toString(),
      twitterLink: json['twitterlink']?.toString(),
      githubLink: json['githublink']?.toString(),
      linkedInLink: json['linkedinlink']?.toString(),
      instagramLink: json['instagramlink']?.toString(),
      city: json['city']?.toString(),
      country: json['country']?.toString(),
      street: json['street']?.toString(),
      formattedAddress: json['geo_point_formatedaddress']?.toString(),
      streamUrl: json['streamurl']?.toString(),
      chatParentId: json['chatparentid']?.toString(),
      timeZone: json['timezone']?.toString(),
      serverStatus: json['serverstatus']?.toString(),
      organizationStatus: json['organizationstatus']?.toString(),
      featuredCollection: parseBool(json['featuredcollection']),
      automaticTagging: parseBool(json['automatictagging']),
      revisions: parseInt(json['revisions']),
      totalSessionsUsed: parseInt(json['totalsessionsused']),
      remainingSessions: parseInt(json['remainingsessions']),
      totalSessionsPurchased: parseInt(json['totalsessionspurchased']),
      creationDate: parseDate(json['creationdate']),
      startDate: parseDate(json['startdate']),
      deliveryDate: parseDate(json['deliverydate']),
      recordDate: parseDate(json['recorddate']),
      lastModifiedDate: parseDate(json['lastmodifieddate']),
      rawProperties: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (urlName != null) 'urlname': urlName,
      if (description != null) 'description': description,
      if (collectiveDescription != null)
        'collectivedescription': collectiveDescription,
      if (manifesto != null) 'manifesto': manifesto,
      if (vision != null) 'vision': vision,
      if (libraryId != null) 'library': libraryId,
      if (collectionType != null) 'collectiontype': collectionType,
      if (visibility != null) 'visibility': visibility,
      if (projectStatus != null) 'projectstatus': projectStatus,
      if (projectType != null) 'projecttype': projectType,
      if (privacyLevel != null) 'priviacylevel': privacyLevel,
      if (communityTag != null) 'communitytag': communityTag,
      if (keywords.isNotEmpty) 'keywords': keywords,
      if (collectiveTags.isNotEmpty) 'collectivetags': collectiveTags,
      if (assetPortrait != null) 'assetportrait': assetPortrait,
      if (assetBanner != null) 'assetbanner': assetBanner,
      if (collectiveBanner != null) 'collectivebanner': collectiveBanner,
      if (collectionImage != null) 'collectionimage': collectionImage,
      if (invoiceLogo != null) 'invoicelogo': invoiceLogo,
      if (contactName != null) 'contactname': contactName,
      if (contactEmail != null) 'contactemail': contactEmail,
      if (contactPhone != null) 'contactphone': contactPhone,
      if (websiteLink != null) 'websitelink': websiteLink,
      if (facebookLink != null) 'facebooklink': facebookLink,
      if (twitterLink != null) 'twitterlink': twitterLink,
      if (githubLink != null) 'githublink': githubLink,
      if (linkedInLink != null) 'linkedinlink': linkedInLink,
      if (instagramLink != null) 'instagramlink': instagramLink,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
      if (street != null) 'street': street,
      if (formattedAddress != null)
        'geo_point_formatedaddress': formattedAddress,
      if (streamUrl != null) 'streamurl': streamUrl,
      if (chatParentId != null) 'chatparentid': chatParentId,
      if (timeZone != null) 'timezone': timeZone,
      if (serverStatus != null) 'serverstatus': serverStatus,
      if (organizationStatus != null)
        'organizationstatus': organizationStatus,
      'featuredcollection': featuredCollection,
      'automatictagging': automaticTagging,
      if (revisions != null) 'revisions': revisions,
      if (totalSessionsUsed != null) 'totalsessionsused': totalSessionsUsed,
      if (remainingSessions != null) 'remainingsessions': remainingSessions,
      if (totalSessionsPurchased != null)
        'totalsessionspurchased': totalSessionsPurchased,
      if (creationDate != null) 'creationdate': creationDate!.toIso8601String(),
      if (startDate != null) 'startdate': startDate!.toIso8601String(),
      if (deliveryDate != null) 'deliverydate': deliveryDate!.toIso8601String(),
      if (recordDate != null) 'recorddate': recordDate!.toIso8601String(),
      if (lastModifiedDate != null)
        'lastmodifieddate': lastModifiedDate!.toIso8601String(),
    };
  }

  LibraryCollectionModel copyWith({
    String? id,
    String? name,
    String? urlName,
    String? description,
    String? collectiveDescription,
    String? manifesto,
    String? vision,
    String? libraryId,
    String? collectionType,
    String? visibility,
    String? projectStatus,
    String? projectType,
    String? privacyLevel,
    String? communityTag,
    List<String>? keywords,
    List<String>? collectiveTags,
    String? assetPortrait,
    String? assetBanner,
    String? collectiveBanner,
    String? collectionImage,
    String? invoiceLogo,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
    String? websiteLink,
    String? facebookLink,
    String? twitterLink,
    String? githubLink,
    String? linkedInLink,
    String? instagramLink,
    String? city,
    String? country,
    String? street,
    String? formattedAddress,
    String? streamUrl,
    String? chatParentId,
    String? timeZone,
    String? serverStatus,
    String? organizationStatus,
    bool? featuredCollection,
    bool? automaticTagging,
    int? revisions,
    int? totalSessionsUsed,
    int? remainingSessions,
    int? totalSessionsPurchased,
    DateTime? creationDate,
    DateTime? startDate,
    DateTime? deliveryDate,
    DateTime? recordDate,
    DateTime? lastModifiedDate,
    Map<String, dynamic>? rawProperties,
  }) {
    return LibraryCollectionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      urlName: urlName ?? this.urlName,
      description: description ?? this.description,
      collectiveDescription:
          collectiveDescription ?? this.collectiveDescription,
      manifesto: manifesto ?? this.manifesto,
      vision: vision ?? this.vision,
      libraryId: libraryId ?? this.libraryId,
      collectionType: collectionType ?? this.collectionType,
      visibility: visibility ?? this.visibility,
      projectStatus: projectStatus ?? this.projectStatus,
      projectType: projectType ?? this.projectType,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      communityTag: communityTag ?? this.communityTag,
      keywords: keywords ?? this.keywords,
      collectiveTags: collectiveTags ?? this.collectiveTags,
      assetPortrait: assetPortrait ?? this.assetPortrait,
      assetBanner: assetBanner ?? this.assetBanner,
      collectiveBanner: collectiveBanner ?? this.collectiveBanner,
      collectionImage: collectionImage ?? this.collectionImage,
      invoiceLogo: invoiceLogo ?? this.invoiceLogo,
      contactName: contactName ?? this.contactName,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      websiteLink: websiteLink ?? this.websiteLink,
      facebookLink: facebookLink ?? this.facebookLink,
      twitterLink: twitterLink ?? this.twitterLink,
      githubLink: githubLink ?? this.githubLink,
      linkedInLink: linkedInLink ?? this.linkedInLink,
      instagramLink: instagramLink ?? this.instagramLink,
      city: city ?? this.city,
      country: country ?? this.country,
      street: street ?? this.street,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      streamUrl: streamUrl ?? this.streamUrl,
      chatParentId: chatParentId ?? this.chatParentId,
      timeZone: timeZone ?? this.timeZone,
      serverStatus: serverStatus ?? this.serverStatus,
      organizationStatus: organizationStatus ?? this.organizationStatus,
      featuredCollection: featuredCollection ?? this.featuredCollection,
      automaticTagging: automaticTagging ?? this.automaticTagging,
      revisions: revisions ?? this.revisions,
      totalSessionsUsed: totalSessionsUsed ?? this.totalSessionsUsed,
      remainingSessions: remainingSessions ?? this.remainingSessions,
      totalSessionsPurchased:
          totalSessionsPurchased ?? this.totalSessionsPurchased,
      creationDate: creationDate ?? this.creationDate,
      startDate: startDate ?? this.startDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      recordDate: recordDate ?? this.recordDate,
      lastModifiedDate: lastModifiedDate ?? this.lastModifiedDate,
      rawProperties: rawProperties ?? this.rawProperties,
    );
  }
}
