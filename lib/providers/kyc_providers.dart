import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/models/kyc_submission.dart';
import 'package:waste_bridge/providers/service_providers.dart';

final kycSubmissionsProvider = FutureProvider<List<KycSubmission>>((ref) {
  return ref.watch(kycServiceProvider).listSubmissions();
});
