import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/waste_request.dart';
import 'package:waste_bridge/providers/app_providers.dart';

import 'tracking/request_tracking_dialogs.dart';
import 'tracking/request_tracking_helpers.dart';
import 'tracking/request_tracking_photo.dart';
import 'tracking/widgets/dispute_compliance_section.dart';
import 'tracking/widgets/payment_receipt_section.dart';
import 'tracking/widgets/photo_proof_section.dart';
import 'tracking/widgets/request_scheduling_pricing_section.dart';
import 'tracking/widgets/request_status_timeline.dart';
import 'tracking/widgets/request_summary_card.dart';
import 'tracking/widgets/smart_match_card.dart';
import 'tracking/widgets/trust_rating_section.dart';

class RequestTrackingScreen extends ConsumerWidget {
  const RequestTrackingScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Request Tracking')),
      body: requests.when(
        data: (items) {
          WasteRequest? currentRequest;
          RequestStatus? requestStatus;
          String? requestWasteType;
          String? requestLocation;
          double? requestQuantityKg;
          DateTime? requestCreatedAt;
          for (final item in items) {
            if (item.id == requestId) {
              currentRequest = item;
              requestStatus = item.status;
              requestWasteType = item.wasteType;
              requestLocation = item.location;
              requestQuantityKg = item.quantityKg;
              requestCreatedAt = item.createdAt;
              break;
            }
          }
          if (requestStatus == null ||
              requestWasteType == null ||
              requestLocation == null ||
              requestQuantityKg == null ||
              requestCreatedAt == null) {
            return const CenterState(
              title: 'Request not found',
              subtitle: 'This request may have been removed or is unavailable.',
              icon: Icons.search_off_rounded,
            );
          }
          final currentIndex = requestStatus == RequestStatus.cancelled
              ? 0
              : kRequestTrackingTimeline.indexOf(requestStatus);

          Future<void> uploadBefore() async {
            final filePath = await pickProofImagePath();
            if (filePath == null) return;
            try {
              await ref.read(requestNotifierProvider.notifier).uploadProof(
                    requestId: requestId,
                    isBeforePickup: true,
                    filePath: filePath,
                  );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Before pickup photo uploaded.'),
                ),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString())),
              );
            }
          }

          Future<void> uploadAfter() async {
            final filePath = await pickProofImagePath();
            if (filePath == null) return;
            try {
              await ref.read(requestNotifierProvider.notifier).uploadProof(
                    requestId: requestId,
                    isBeforePickup: false,
                    filePath: filePath,
                  );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('After pickup photo uploaded.'),
                ),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString())),
              );
            }
          }

          return ListView(
            padding: EdgeInsets.all(AppSpacing.md),
            children: [
              RequestSummaryCard(
                requestId: requestId,
                wasteType: requestWasteType,
                quantityKg: requestQuantityKg,
                location: requestLocation,
                createdAt: requestCreatedAt,
              ),
              SizedBox(height: AppSpacing.sm),
              SmartMatchCard(request: currentRequest),
              SizedBox(height: AppSpacing.sm),
              RequestStatusTimeline(
                requestStatus: requestStatus,
                currentIndex: currentIndex,
                createdAt: requestCreatedAt,
                currentRequest: currentRequest,
              ),
              SizedBox(height: AppSpacing.sm),
              PhotoProofSection(
                hasBeforePhoto: currentRequest?.beforePickupPhotoUrl != null,
                hasAfterPhoto: currentRequest?.afterPickupPhotoUrl != null,
                onUploadBefore: () => unawaited(uploadBefore()),
                onUploadAfter: () => unawaited(uploadAfter()),
              ),
              if (currentRequest != null) ...[
                SizedBox(height: AppSpacing.sm),
                RequestSchedulingPricingSection(request: currentRequest),
              ],
              if (currentRequest != null) ...[
                SizedBox(height: AppSpacing.sm),
                PaymentReceiptSection(request: currentRequest),
              ],
              if (currentRequest != null) ...[
                SizedBox(height: AppSpacing.sm),
                DisputeComplianceSection(
                  request: currentRequest,
                  onReportIssue: () => showRequestDisputeDialog(
                    context,
                    ref,
                    requestId,
                  ),
                  onResolveDispute: () => resolveRequestDispute(
                    context,
                    ref,
                    requestId,
                  ),
                ),
              ],
              if (currentRequest != null) ...[
                SizedBox(height: AppSpacing.sm),
                TrustRatingSection(
                  request: currentRequest,
                  onRatePickup: currentRequest.status == RequestStatus.completed
                      ? () => showRequestRatingsDialog(
                            context,
                            ref,
                            requestId,
                          )
                      : null,
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CenterState(
          title: 'Failed to load request',
          subtitle: '$e',
          icon: Icons.error_outline_rounded,
        ),
      ),
    );
  }
}
