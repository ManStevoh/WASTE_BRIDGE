/// Listing row from `GET /marketplace` (Phase 3 feed).
class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.wasteType,
    required this.quantityKg,
    required this.locationText,
    required this.status,
    required this.listingMode,
    required this.createdAt,
    this.unitPricePerKg,
    this.totalPrice,
    this.latitude,
    this.longitude,
    this.sellerUserId,
    this.bulkMinQuantityKg,
    this.auctionEndsAt,
    this.startingBid,
    this.reservePrice,
    this.currentBidAmount,
    this.currentHighestBidderUserId,
    this.auctionStatus,
  });

  final String id;
  final String wasteType;
  final double quantityKg;
  final String locationText;
  final String status;
  final String listingMode;
  final DateTime createdAt;
  final double? unitPricePerKg;
  final double? totalPrice;
  final double? latitude;
  final double? longitude;
  final String? sellerUserId;
  final double? bulkMinQuantityKg;
  final DateTime? auctionEndsAt;
  final double? startingBid;
  final double? reservePrice;
  final double? currentBidAmount;
  final String? currentHighestBidderUserId;
  final String? auctionStatus;

  factory MarketplaceListing.fromJson(Map<String, dynamic> json) {
    return MarketplaceListing(
      id: json['id'] as String,
      wasteType: json['wasteType'] as String,
      quantityKg: (json['quantityKg'] as num).toDouble(),
      locationText: json['locationText'] as String,
      status: json['status'] as String,
      listingMode: json['listingMode'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      unitPricePerKg: (json['unitPricePerKg'] as num?)?.toDouble(),
      totalPrice: (json['totalPrice'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      sellerUserId: json['sellerUserId'] as String?,
      bulkMinQuantityKg: (json['bulkMinQuantityKg'] as num?)?.toDouble(),
      auctionEndsAt: json['auctionEndsAt'] != null
          ? DateTime.tryParse(json['auctionEndsAt'] as String)
          : null,
      startingBid: (json['startingBid'] as num?)?.toDouble(),
      reservePrice: (json['reservePrice'] as num?)?.toDouble(),
      currentBidAmount: (json['currentBidAmount'] as num?)?.toDouble(),
      currentHighestBidderUserId: json['currentHighestBidderUserId'] as String?,
      auctionStatus: json['auctionStatus'] as String?,
    );
  }
}

class MarketplaceFeedPage {
  const MarketplaceFeedPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<MarketplaceListing> items;
  final int page;
  final int perPage;
  final int total;

  factory MarketplaceFeedPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? [];
    final per = json['per_page'] ?? json['perPage'];
    return MarketplaceFeedPage(
      items: raw
          .map((e) => MarketplaceListing.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      perPage: (per as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
