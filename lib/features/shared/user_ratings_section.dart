import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/user_rating.dart';
import 'package:waste_bridge/providers/app_providers.dart';

/// Loads `GET /users/{userPublicId}/ratings` for trust / reputation.
class UserRatingsSection extends ConsumerStatefulWidget {
  const UserRatingsSection({
    super.key,
    required this.userPublicId,
    this.title = 'Ratings',
  });

  final String userPublicId;
  final String title;

  @override
  ConsumerState<UserRatingsSection> createState() => _UserRatingsSectionState();
}

class _UserRatingsSectionState extends ConsumerState<UserRatingsSection> {
  late Future<List<UserRating>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<UserRating>> _load() {
    return ref.read(ratingsServiceProvider).getUserRatings(widget.userPublicId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserRating>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppSectionCard(
            title: widget.title,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          final msg = snapshot.error is DioException
              ? userVisibleError(
                  snapshot.error!,
                  fallback: 'Could not load ratings.',
                )
              : snapshot.error.toString();
          return AppSectionCard(
            title: widget.title,
            child: Text(msg, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return AppSectionCard(
            title: widget.title,
            child: Text(
              'No ratings yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        final avg = items.fold<double>(0, (s, r) => s + r.score) / items.length;
        return AppSectionCard(
          title: widget.title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Average ${avg.toStringAsFixed(1)} / 5 · ${items.length} review(s)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: AppSpacing.sm),
              ...items.take(5).map(
                    (r) => Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.score.toStringAsFixed(1)} ★'
                            '${r.raterName != null ? ' · ${r.raterName}' : ''}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (r.comment != null && r.comment!.isNotEmpty)
                            Text(r.comment!, style: Theme.of(context).textTheme.bodyMedium),
                          if (r.createdAt != null)
                            Text(
                              r.createdAt!.toLocal().toString().split('.').first,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
