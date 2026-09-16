import 'package:flutter/material.dart';

/// Enum representing the supported product categories in chat.
/// Easily extensible for future categories (events, micro-investments, services, etc.)
enum ProductType {
  ecommerce,
  rideshare,
  rental,
}

/// Subcategory for rental products
enum RentalCategory {
  house,
  vehicle,
  gear,
}

/// Comprehensive model for products sent and rendered in chat conversations.
class ProductMessageModel {
  final String id;
  final ProductType type;
  final String title;
  final String description;
  final double price;
  final String currency; // e.g. '$', 'USDC', 'GTQ'
  final String? priceUnit; // e.g. '/ night', '/ day', '/ seat', '/ item'
  final String? imageUrl;
  final IconData? iconData;
  final double rating;
  final int reviewCount;
  final String sellerOrHostName;
  final String sellerOrHostRole;
  final String? location;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  // Type-specific: Rideshare
  final String? origin;
  final String? destination;
  final String? departureTime;
  final int? availableSeats;
  final int? totalSeats;
  final String? vehicleInfo;
  final String? driverName;
  final double? driverRating;

  // Type-specific: Rental
  final RentalCategory? rentalCategory;
  final List<String> amenitiesOrSpecs;
  final String? depositInfo;
  final String? availability;

  // Type-specific: E-Commerce
  final bool inStock;
  final int? stockQuantity;
  final String? shippingOrPickupInfo;
  final String? brandOrOrigin;

  const ProductMessageModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.price,
    this.currency = '\$',
    this.priceUnit,
    this.imageUrl,
    this.iconData,
    this.rating = 4.9,
    this.reviewCount = 24,
    required this.sellerOrHostName,
    required this.sellerOrHostRole,
    this.location,
    this.tags = const [],
    this.metadata = const {},
    // Rideshare
    this.origin,
    this.destination,
    this.departureTime,
    this.availableSeats,
    this.totalSeats,
    this.vehicleInfo,
    this.driverName,
    this.driverRating,
    // Rental
    this.rentalCategory,
    this.amenitiesOrSpecs = const [],
    this.depositInfo,
    this.availability,
    // E-commerce
    this.inStock = true,
    this.stockQuantity,
    this.shippingOrPickupInfo,
    this.brandOrOrigin,
  });

  /// Formatted full price with unit
  String get formattedPrice {
    final formattedNum =
        price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(2);
    final unit = priceUnit != null ? ' $priceUnit' : '';
    return '$currency$formattedNum$unit';
  }

  /// Primary action label depending on product type
  String get primaryActionLabel {
    switch (type) {
      case ProductType.ecommerce:
        return 'Buy Now';
      case ProductType.rideshare:
        return 'Book Seat';
      case ProductType.rental:
        return rentalCategory == RentalCategory.house ? 'Book Stay' : 'Rent Now';
    }
  }

  /// Type display tag
  String get typeLabel {
    switch (type) {
      case ProductType.ecommerce:
        return 'Product';
      case ProductType.rideshare:
        return 'Rideshare';
      case ProductType.rental:
        switch (rentalCategory) {
          case RentalCategory.house:
            return 'House Rental';
          case RentalCategory.vehicle:
            return 'Vehicle Rental';
          case RentalCategory.gear:
          default:
            return 'Gear Rental';
        }
    }
  }

  /// Sample demo presets
  static List<ProductMessageModel> get sampleCatalog => [
    // 1. E-COMMERCE: Single Origin Coffee
    const ProductMessageModel(
      id: 'prod_ecom_01',
      type: ProductType.ecommerce,
      title: 'Single-Origin Atitlan Gesha Coffee (500g)',
      description:
          'High-altitude volcanic soil shade-grown beans. Floral jasmine aroma, citrus acidity, and honey sweetness roasted by local Mayan cooperatives.',
      price: 18.50,
      currency: '\$',
      priceUnit: '/ bag',
      iconData: Icons.coffee_rounded,
      rating: 4.95,
      reviewCount: 48,
      sellerOrHostName: 'San Marcos Organic Co-op',
      sellerOrHostRole: 'VERIFIED PRODUCER',
      location: 'San Marcos La Laguna',
      brandOrOrigin: 'Lake Atitlan Highlands, 1750m',
      inStock: true,
      stockQuantity: 15,
      shippingOrPickupInfo: 'Same-day local boat delivery & global shipping',
      tags: ['Organic', 'Direct Trade', 'Shade Grown'],
    ),

    // 2. E-COMMERCE: Handwoven Poncho
    const ProductMessageModel(
      id: 'prod_ecom_02',
      type: ProductType.ecommerce,
      title: 'Handwoven Natural Dye Wool Poncho',
      description:
          'Authentic backstrap-loom woven wool poncho crafted with plant-based botanical dyes by master indigenous artisans.',
      price: 65.00,
      currency: '\$',
      priceUnit: '/ piece',
      iconData: Icons.checkroom_rounded,
      rating: 4.88,
      reviewCount: 32,
      sellerOrHostName: 'K\'iche\' Weavers Guild',
      sellerOrHostRole: 'ARTISAN COLLECTIVE',
      location: 'San Juan La Laguna',
      brandOrOrigin: '100% Organic Virgin Wool',
      inStock: true,
      stockQuantity: 4,
      shippingOrPickupInfo: 'Available in locker #4 or local delivery',
      tags: ['Handmade', 'Fair Trade', 'Botanical Dye'],
    ),

    // 3. RIDESHARE: EV Shuttle
    const ProductMessageModel(
      id: 'prod_ride_01',
      type: ProductType.rideshare,
      title: 'Panajachel ➔ Guatemala City Express EV Shuttle',
      description:
          'Zero-emission express passenger shuttle with high-speed Starlink WiFi, AC, and luggage space via Highway CA-1.',
      price: 24.00,
      currency: '\$',
      priceUnit: '/ seat',
      iconData: Icons.electric_car_rounded,
      rating: 4.98,
      reviewCount: 112,
      sellerOrHostName: 'EcoTransit Co-op #12',
      sellerOrHostRole: 'MOBILITY OPERATOR',
      origin: 'Panajachel Central Pier',
      destination: 'Guatemala City Airport / Zone 10',
      departureTime: 'Today at 2:30 PM',
      availableSeats: 3,
      totalSeats: 6,
      vehicleInfo: 'BYD E-Passenger Van (100% Electric)',
      driverName: 'Carlos Mendonza',
      driverRating: 4.98,
      tags: ['100% Electric', 'Starlink WiFi', 'Luggage Included'],
    ),

    // 4. RENTAL (House): Lakeview Solar Eco-Villa
    const ProductMessageModel(
      id: 'prod_rent_house_01',
      type: ProductType.rental,
      rentalCategory: RentalCategory.house,
      title: 'Lakeview Solar Eco-Villa with Private Dock',
      description:
          'Off-grid cliffside architectural sanctuary powered by 10kW solar system with panoramic volcanic views, fiber optic WiFi, and private kayak launch.',
      price: 110.00,
      currency: '\$',
      priceUnit: '/ night',
      iconData: Icons.villa_rounded,
      rating: 4.96,
      reviewCount: 76,
      sellerOrHostName: 'Elena & Mateo',
      sellerOrHostRole: 'SUPERHOST',
      location: 'Jaibalito, Lake Atitlan',
      availability: 'Available this weekend & next week',
      depositInfo: '10% Smart Contract Escrow',
      amenitiesOrSpecs: [
        '2 King Bedrooms',
        'High-Speed Fiber (200 Mbps)',
        'Private Boat Dock',
        'Kitchen & Solar Power',
      ],
      tags: ['Solar Powered', 'Superhost', 'Private Dock'],
    ),

    // 5. RENTAL (Gear): Sony Cinema Camera Kit
    const ProductMessageModel(
      id: 'prod_rent_gear_01',
      type: ProductType.rental,
      rentalCategory: RentalCategory.gear,
      title: 'Sony FX6 Cinema Kit & G-Master Cine Lenses',
      description:
          'Full cinema package including Sony FX6 body, 24-70mm GM II, V-mount batteries, wireless audio, and pelican case ready for production.',
      price: 75.00,
      currency: '\$',
      priceUnit: '/ day',
      iconData: Icons.videocam_rounded,
      rating: 5.0,
      reviewCount: 19,
      sellerOrHostName: 'Pan-Lake Media Collective',
      sellerOrHostRole: 'EQUIPMENT DEPOT',
      location: 'Panajachel Hub (Locker #18)',
      availability: 'Ready for instant locker pickup',
      depositInfo: 'Identity Escrow / Zero Collateral for Verified Nodes',
      amenitiesOrSpecs: [
        '4K 120fps Raw Ready',
        '2x 150Wh V-Mounts',
        'Wireless Mic Set',
        'Carbon Fiber Tripod',
      ],
      tags: ['Cinema Grade', 'Instant Locker Unlock', 'Insured'],
    ),

    // 6. RENTAL (Vehicle): Electric Scooter
    const ProductMessageModel(
      id: 'prod_rent_veh_01',
      type: ProductType.rental,
      rentalCategory: RentalCategory.vehicle,
      title: 'Dual-Battery Electric Adventure Scooter',
      description:
          'Lightweight electric dual-sport scooter with 90km range per charge. Helmets and phone mount included.',
      price: 32.00,
      currency: '\$',
      priceUnit: '/ day',
      iconData: Icons.two_wheeler_rounded,
      rating: 4.91,
      reviewCount: 35,
      sellerOrHostName: 'GreenWheels Mobility Hub',
      sellerOrHostRole: 'FLEET MANAGER',
      location: 'Santa Cruz Wharf Hub',
      availability: 'Instant Unlock via QR Code',
      depositInfo: 'No security deposit with EME ID',
      amenitiesOrSpecs: [
        '90km Dual Battery Range',
        '2x Helmets Included',
        'GPS Security & USB-C Fast Charger',
      ],
      tags: ['Eco Commute', 'Helmet Included', 'QR Unlock'],
    ),
  ];

  factory ProductMessageModel.fromJson(Map<String, dynamic> json) {
    ProductType parsedType = ProductType.ecommerce;
    final rawType = json['type'] as String? ?? 'ecommerce';
    for (final t in ProductType.values) {
      if (t.name.toLowerCase() == rawType.toLowerCase()) {
        parsedType = t;
        break;
      }
    }

    RentalCategory? parsedRentalCategory;
    if (json['rentalCategory'] != null) {
      final rawCat = json['rentalCategory'] as String;
      for (final c in RentalCategory.values) {
        if (c.name.toLowerCase() == rawCat.toLowerCase()) {
          parsedRentalCategory = c;
          break;
        }
      }
    }

    return ProductMessageModel(
      id: json['id'] as String? ?? '',
      type: parsedType,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? '\$',
      priceUnit: json['priceUnit'] as String?,
      imageUrl: json['imageUrl'] as String?,
      iconData: json['iconCodePoint'] != null
          // ignore: non_const_argument_for_const_parameter
          ? IconData(json['iconCodePoint'] as int, fontFamily: 'MaterialIcons')
          : null,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      sellerOrHostName: json['sellerOrHostName'] as String? ?? '',
      sellerOrHostRole: json['sellerOrHostRole'] as String? ?? '',
      location: json['location'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      origin: json['origin'] as String?,
      destination: json['destination'] as String?,
      departureTime: json['departureTime'] as String?,
      availableSeats: (json['availableSeats'] as num?)?.toInt(),
      totalSeats: (json['totalSeats'] as num?)?.toInt(),
      vehicleInfo: json['vehicleInfo'] as String?,
      driverName: json['driverName'] as String?,
      driverRating: (json['driverRating'] as num?)?.toDouble(),
      rentalCategory: parsedRentalCategory,
      amenitiesOrSpecs: (json['amenitiesOrSpecs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      depositInfo: json['depositInfo'] as String?,
      availability: json['availability'] as String?,
      inStock: json['inStock'] as bool? ?? true,
      stockQuantity: (json['stockQuantity'] as num?)?.toInt(),
      shippingOrPickupInfo: json['shippingOrPickupInfo'] as String?,
      brandOrOrigin: json['brandOrOrigin'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'description': description,
      'price': price,
      'currency': currency,
      if (priceUnit != null) 'priceUnit': priceUnit,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (iconData != null) 'iconCodePoint': iconData!.codePoint,
      'rating': rating,
      'reviewCount': reviewCount,
      'sellerOrHostName': sellerOrHostName,
      'sellerOrHostRole': sellerOrHostRole,
      if (location != null) 'location': location,
      'tags': tags,
      'metadata': metadata,
      if (origin != null) 'origin': origin,
      if (destination != null) 'destination': destination,
      if (departureTime != null) 'departureTime': departureTime,
      if (availableSeats != null) 'availableSeats': availableSeats,
      if (totalSeats != null) 'totalSeats': totalSeats,
      if (vehicleInfo != null) 'vehicleInfo': vehicleInfo,
      if (driverName != null) 'driverName': driverName,
      if (driverRating != null) 'driverRating': driverRating,
      if (rentalCategory != null) 'rentalCategory': rentalCategory!.name,
      'amenitiesOrSpecs': amenitiesOrSpecs,
      if (depositInfo != null) 'depositInfo': depositInfo,
      if (availability != null) 'availability': availability,
      'inStock': inStock,
      if (stockQuantity != null) 'stockQuantity': stockQuantity,
      if (shippingOrPickupInfo != null)
        'shippingOrPickupInfo': shippingOrPickupInfo,
      if (brandOrOrigin != null) 'brandOrOrigin': brandOrOrigin,
    };
  }
}
