import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/core/network/api_client.dart';
import 'package:waste_bridge/services/analytics_service.dart';
import 'package:waste_bridge/services/auth_service.dart';
import 'package:waste_bridge/services/job_service.dart';
import 'package:waste_bridge/services/kyc_service.dart';
import 'package:waste_bridge/services/marketplace_service.dart';
import 'package:waste_bridge/services/notification_service.dart';
import 'package:waste_bridge/services/order_service.dart';
import 'package:waste_bridge/services/payment_service.dart';
import 'package:waste_bridge/services/ratings_service.dart';
import 'package:waste_bridge/services/receipt_service.dart';
import 'package:waste_bridge/services/transaction_service.dart';
import 'package:waste_bridge/services/waste_listing_service.dart';
import 'package:waste_bridge/services/waste_request_service.dart';

final apiClientProvider = Provider((ref) => ApiClient());
final authServiceProvider = Provider(
  (ref) => AuthService(ref.read(apiClientProvider).dio),
);
final wasteRequestServiceProvider = Provider(
  (ref) => WasteRequestService(ref.read(apiClientProvider).dio),
);
final jobServiceProvider = Provider(
  (ref) => JobService(ref.read(apiClientProvider).dio),
);
final transactionServiceProvider = Provider(
  (ref) => TransactionService(ref.read(apiClientProvider).dio),
);
final paymentServiceProvider = Provider(
  (ref) => PaymentService(ref.read(apiClientProvider).dio),
);
final notificationServiceProvider = Provider(
  (ref) => NotificationService(ref.read(apiClientProvider).dio),
);
final marketplaceServiceProvider = Provider(
  (ref) => MarketplaceService(ref.read(apiClientProvider).dio),
);
final orderServiceProvider = Provider(
  (ref) => OrderService(ref.read(apiClientProvider).dio),
);
final wasteListingServiceProvider = Provider(
  (ref) => WasteListingService(ref.read(apiClientProvider).dio),
);
final receiptServiceProvider = Provider(
  (ref) => ReceiptService(ref.read(apiClientProvider).dio),
);
final kycServiceProvider = Provider(
  (ref) => KycService(ref.read(apiClientProvider).dio),
);
final ratingsServiceProvider = Provider(
  (ref) => RatingsService(ref.read(apiClientProvider).dio),
);
final analyticsServiceProvider = Provider(
  (ref) => AnalyticsService(ref.read(apiClientProvider).dio),
);
