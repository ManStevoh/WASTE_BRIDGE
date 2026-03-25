import 'package:waste_bridge/models/waste_request.dart';

/// Order + pickup context from `GET /orders` and `GET /orders/{order}`.
class MarketplaceOrderDetail {
  const MarketplaceOrderDetail({
    required this.id,
    required this.status,
    this.sellerUserId,
    this.buyerUserId,
    this.listingId,
    this.subtotalAmount,
    this.escrowAmount,
    this.escrowStatus,
    this.currency,
    this.createdAt,
    this.receiptId,
    this.receiptIssuedAt,
    this.pickupRequest,
    this.jobPublicId,
    this.jobStatus,
  });

  final String id;
  final String status;
  final String? sellerUserId;
  final String? buyerUserId;
  final String? listingId;
  final double? subtotalAmount;
  final double? escrowAmount;
  final String? escrowStatus;
  final String? currency;
  final DateTime? createdAt;
  final String? receiptId;
  final DateTime? receiptIssuedAt;
  final WasteRequest? pickupRequest;
  final String? jobPublicId;
  final String? jobStatus;

  factory MarketplaceOrderDetail.fromJson(Map<String, dynamic> json) {
    WasteRequest? pr;
    final rawPr = json['pickupRequest'];
    if (rawPr is Map<String, dynamic>) {
      pr = WasteRequest.fromJson(rawPr);
    }

    return MarketplaceOrderDetail(
      id: json['id'] as String,
      status: json['status'] as String,
      sellerUserId: json['sellerUserId'] as String?,
      buyerUserId: json['buyerUserId'] as String?,
      listingId: json['listingId'] as String?,
      subtotalAmount: (json['subtotalAmount'] as num?)?.toDouble(),
      escrowAmount: (json['escrowAmount'] as num?)?.toDouble(),
      escrowStatus: json['escrowStatus'] as String?,
      currency: json['currency'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
      receiptId: json['receiptId'] as String?,
      receiptIssuedAt: json['receiptIssuedAt'] == null
          ? null
          : DateTime.tryParse(json['receiptIssuedAt'] as String),
      pickupRequest: pr,
      jobPublicId: json['jobPublicId'] as String?,
      jobStatus: json['jobStatus'] as String?,
    );
  }
}

class OrderListPage {
  const OrderListPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<MarketplaceOrderDetail> items;
  final int page;
  final int perPage;
  final int total;

  factory OrderListPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? [];
    final per = json['per_page'] ?? json['perPage'];
    return OrderListPage(
      items: raw
          .map((e) => MarketplaceOrderDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      perPage: (per as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
