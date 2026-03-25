import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/models/user_rating.dart';
import 'package:waste_bridge/providers/service_providers.dart';

/// Public ratings for a user (e.g. collector on request tracking).
final collectorRatingsProvider =
    FutureProvider.family<List<UserRating>, String>((ref, userPublicId) {
  return ref.read(ratingsServiceProvider).getUserRatings(userPublicId);
});
