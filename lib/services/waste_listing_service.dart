import 'package:dio/dio.dart';
import 'package:waste_bridge/models/marketplace_listing.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

class WasteListingService {
  WasteListingService(this._dio);
  final Dio _dio;

  Future<MarketplaceListing> createListing({
    required String wasteType,
    required double quantityKg,
    required String locationText,
    double? unitPricePerKg,
    double? totalPrice,
    double? latitude,
    double? longitude,
    String listingMode = 'fixed_price',
    double? bulkMinQuantityKg,
    String? auctionEndsAt,
    double? startingBid,
    double? reservePrice,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.wasteCreate,
      data: <String, dynamic>{
        'wasteType': wasteType,
        'quantityKg': quantityKg,
        'locationText': locationText,
        if (unitPricePerKg != null) 'unitPricePerKg': unitPricePerKg,
        if (totalPrice != null) 'totalPrice': totalPrice,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'listingMode': listingMode,
        if (bulkMinQuantityKg != null) 'bulkMinQuantityKg': bulkMinQuantityKg,
        if (auctionEndsAt != null) 'auctionEndsAt': auctionEndsAt,
        if (startingBid != null) 'startingBid': startingBid,
        if (reservePrice != null) 'reservePrice': reservePrice,
      },
    );
    final data = response.data;
    if (data == null) {
      throw StateError('Empty listing response');
    }
    return MarketplaceListing.fromJson(data);
  }
}
