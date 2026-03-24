import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/waste_request.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class GeneratorHomeScreen extends ConsumerWidget {
  const GeneratorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generator Home'),
        actions: [
          IconButton(
            onPressed: () => context.push('/generator/impact'),
            icon: const Icon(Icons.insights_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/generator/requests'),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: () => context.push('/generator/request-pickup'),
            icon: const Icon(Icons.add_business),
            label: const Text('Request Pickup'),
          ),
          const SizedBox(height: 16),
          const AppSectionCard(
            title: 'Waste Categories',
            child: Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('Plastic')),
                Chip(label: Text('Paper')),
                Chip(label: Text('Metal')),
                Chip(label: Text('Organic')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Recent Requests',
            trailing: TextButton(
              onPressed: () => context.push('/generator/requests'),
              child: const Text('View all'),
            ),
            child: requests.when(
              data: (items) {
                if (items.isEmpty) {
                  return const CenterState(
                    title: 'No requests yet',
                    subtitle: 'Create your first pickup request.',
                  );
                }
                return Column(
                  children: items
                      .take(3)
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () =>
                              context.push('/generator/track/${item.id}'),
                          title: Text(
                            '${item.wasteType} - ${item.quantityKg}kg',
                          ),
                          subtitle: Text(item.location),
                          trailing: Text(item.status.name),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text('Failed to load: $e'),
            ),
          ),
        ],
      ),
    );
  }
}

class RequestPickupScreen extends ConsumerStatefulWidget {
  const RequestPickupScreen({super.key});

  @override
  ConsumerState<RequestPickupScreen> createState() =>
      _RequestPickupScreenState();
}

class _RequestPickupScreenState extends ConsumerState<RequestPickupScreen> {
  final _quantity = TextEditingController();
  final _location = TextEditingController(text: 'Victoria Island, Lagos');
  String _wasteType = 'Plastic';
  DateTime? _scheduledAt;
  String? _selectedTemplate;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final quantity = double.tryParse(_quantity.text) ?? 0;
    final estimatedDistance = _location.text.toLowerCase().contains('lekki')
        ? 9.5
        : 5.0;
    final unitPrice = _unitPriceFor(_wasteType, estimatedDistance);
    final total = unitPrice * quantity;
    return Scaffold(
      appBar: AppBar(title: const Text('Request Pickup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _selectedTemplate,
            hint: const Text('Saved Template (optional)'),
            items: const [
              DropdownMenuItem(
                value: 'Office Plastic 20kg',
                child: Text('Office Plastic 20kg'),
              ),
              DropdownMenuItem(
                value: 'Market Organic 50kg',
                child: Text('Market Organic 50kg'),
              ),
            ],
            onChanged: (value) {
              setState(() => _selectedTemplate = value);
              if (value == null) return;
              if (value.contains('Plastic')) _wasteType = 'Plastic';
              if (value.contains('Organic')) _wasteType = 'Organic';
              _quantity.text = value.contains('20kg') ? '20' : '50';
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _wasteType,
            decoration: const InputDecoration(labelText: 'Waste Type'),
            items: const [
              'Plastic',
              'Paper',
              'Metal',
              'Organic',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _wasteType = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity (kg)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Pickup location'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pickup Schedule'),
            subtitle: Text(
              _scheduledAt == null
                  ? 'Now / earliest available'
                  : _scheduledAt!.toLocal().toString().split('.').first,
            ),
            trailing: TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time == null) return;
                setState(() {
                  _scheduledAt = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                });
              },
              child: const Text('Pick slot'),
            ),
          ),
          const SizedBox(height: 8),
          AppSectionCard(
            title: 'Dynamic Pricing Preview',
            child: Column(
              children: [
                _InfoRow(
                  label: 'Distance',
                  value: '${estimatedDistance.toStringAsFixed(1)} km',
                ),
                _InfoRow(
                  label: 'Rate',
                  value: 'NGN ${unitPrice.toStringAsFixed(0)} / kg',
                ),
                _InfoRow(
                  label: 'Estimated total',
                  value: 'NGN ${total.toStringAsFixed(0)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting
                ? null
                : () async {
                    setState(() => _submitting = true);
                    try {
                      await ref
                          .read(requestNotifierProvider.notifier)
                          .addRequest(
                            wasteType: _wasteType,
                            quantityKg: double.tryParse(_quantity.text) ?? 1,
                            location: _location.text.trim(),
                            scheduledAt: _scheduledAt,
                          );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Pickup request submitted successfully.',
                          ),
                        ),
                      );
                      context.pop();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    } finally {
                      if (mounted) setState(() => _submitting = false);
                    }
                  },
            child: _submitting
                ? const CircularProgressIndicator()
                : const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
}

double _unitPriceFor(String wasteType, double distanceKm) {
  final type = wasteType.toLowerCase();
  final base = switch (type) {
    'plastic' => 420.0,
    'paper' => 260.0,
    'metal' => 520.0,
    'organic' => 180.0,
    _ => 220.0,
  };
  return base - (distanceKm * 2);
}

class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: requests.when(
        data: (items) {
          if (items.isEmpty) {
            return const CenterState(
              title: 'No pickup requests',
              subtitle: 'You can request a pickup from the home screen.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) {
              final item = items[i];
              return Card(
                child: ListTile(
                  onTap: () => context.push('/generator/track/${item.id}'),
                  title: Text('${item.wasteType} - ${item.quantityKg}kg'),
                  subtitle: Text(item.location),
                  trailing: Chip(label: Text(item.status.name.toUpperCase())),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: items.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            CenterState(title: 'Error', subtitle: '$e', icon: Icons.error),
      ),
    );
  }
}

class RequestTrackingScreen extends ConsumerWidget {
  const RequestTrackingScreen({super.key, required this.requestId});

  final String requestId;

  static const List<RequestStatus> _timeline = [
    RequestStatus.pending,
    RequestStatus.accepted,
    RequestStatus.pickedUp,
    RequestStatus.completed,
  ];

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
              : _timeline.indexOf(requestStatus);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppSectionCard(
                title: 'Request Details',
                child: Column(
                  children: [
                    _InfoRow(label: 'Request ID', value: requestId),
                    _InfoRow(label: 'Waste Type', value: requestWasteType),
                    _InfoRow(label: 'Quantity', value: '$requestQuantityKg kg'),
                    _InfoRow(label: 'Location', value: requestLocation),
                    _InfoRow(
                      label: 'Created',
                      value: requestCreatedAt
                          .toLocal()
                          .toString()
                          .split('.')
                          .first,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppSectionCard(
                title: 'Smart Match',
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Suggested Collector',
                      value:
                          currentRequest?.suggestedCollectorName ??
                          'Matching in progress',
                    ),
                    _InfoRow(
                      label: 'Estimated ETA',
                      value: currentRequest?.estimatedEtaMinutes == null
                          ? 'TBD'
                          : '${currentRequest?.estimatedEtaMinutes} mins',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppSectionCard(
                title: 'Status Timeline',
                child: Column(
                  children: [
                    ..._timeline.asMap().entries.map((entry) {
                      final index = entry.key;
                      final status = entry.value;
                      final done = index <= currentIndex;
                      final active = index == currentIndex;
                      return _StatusStep(
                        isDone: done,
                        isActive: active,
                        isLast:
                            index == _timeline.length - 1 &&
                            requestStatus != RequestStatus.cancelled,
                        label: _labelFor(status),
                        dateTime: _dateForStatus(
                          status: status,
                          createdAt: requestCreatedAt!,
                          item: currentRequest,
                        ),
                      );
                    }),
                    if (requestStatus == RequestStatus.cancelled)
                      _StatusStep(
                        isDone: true,
                        isActive: true,
                        isLast: true,
                        label: _labelFor(RequestStatus.cancelled),
                        dateTime: currentRequest?.cancelledAt,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppSectionCard(
                title: 'Photo Proof',
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Before Pickup',
                      value: currentRequest?.beforePickupPhotoUrl == null
                          ? 'Not uploaded'
                          : 'Uploaded',
                    ),
                    _InfoRow(
                      label: 'After Pickup',
                      value: currentRequest?.afterPickupPhotoUrl == null
                          ? 'Not uploaded'
                          : 'Uploaded',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed:
                              currentRequest?.beforePickupPhotoUrl != null
                              ? null
                              : () async {
                                  final filePath = await _pickImagePath();
                                  if (filePath == null) return;
                                  try {
                                    await ref
                                        .read(requestNotifierProvider.notifier)
                                        .uploadProof(
                                          requestId: requestId,
                                          isBeforePickup: true,
                                          filePath: filePath,
                                        );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Before pickup photo uploaded.',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Upload Before'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: currentRequest?.afterPickupPhotoUrl != null
                              ? null
                              : () async {
                                  final filePath = await _pickImagePath();
                                  if (filePath == null) return;
                                  try {
                                    await ref
                                        .read(requestNotifierProvider.notifier)
                                        .uploadProof(
                                          requestId: requestId,
                                          isBeforePickup: false,
                                          filePath: filePath,
                                        );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'After pickup photo uploaded.',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Upload After'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppSectionCard(
                title: 'Scheduling and Pricing',
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Scheduled',
                      value: currentRequest?.scheduledAt == null
                          ? 'Not set'
                          : currentRequest!.scheduledAt!
                                .toLocal()
                                .toString()
                                .split('.')
                                .first,
                    ),
                    _InfoRow(
                      label: 'Rescheduled',
                      value: currentRequest?.rescheduledAt == null
                          ? 'No'
                          : currentRequest!.rescheduledAt!
                                .toLocal()
                                .toString()
                                .split('.')
                                .first,
                    ),
                    _InfoRow(
                      label: 'Distance',
                      value: currentRequest?.distanceKm == null
                          ? 'Unknown'
                          : '${currentRequest!.distanceKm!.toStringAsFixed(1)} km',
                    ),
                    _InfoRow(
                      label: 'Price/kg',
                      value: currentRequest?.unitPricePerKg == null
                          ? 'TBD'
                          : 'NGN ${currentRequest!.unitPricePerKg!.toStringAsFixed(0)}',
                    ),
                    _InfoRow(
                      label: 'Total Amount',
                      value: currentRequest?.totalAmount == null
                          ? 'TBD'
                          : 'NGN ${currentRequest!.totalAmount!.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppSectionCard(
                title: 'Payment and Receipt',
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Payment',
                      value:
                          currentRequest?.paymentStatus.name.toUpperCase() ??
                          'UNPAID',
                    ),
                    _InfoRow(
                      label: 'Receipt ID',
                      value: currentRequest?.receiptId ?? 'Pending issuance',
                    ),
                    _InfoRow(
                      label: 'Receipt time',
                      value: currentRequest?.receiptIssuedAt == null
                          ? 'N/A'
                          : currentRequest!.receiptIssuedAt!
                                .toLocal()
                                .toString()
                                .split('.')
                                .first,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppSectionCard(
                title: 'Dispute and Compliance',
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Dispute',
                      value: currentRequest?.isDisputed == true
                          ? 'Open'
                          : 'None',
                    ),
                    _InfoRow(
                      label: 'Reason',
                      value: currentRequest?.disputeReason ?? 'N/A',
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                _openDisputeDialog(context, ref, requestId),
                            icon: const Icon(Icons.report_problem_outlined),
                            label: const Text('Report an Issue'),
                          ),
                          if (currentRequest?.isDisputed == true)
                            TextButton.icon(
                              onPressed: () =>
                                  _resolveDispute(context, ref, requestId),
                              icon: const Icon(Icons.verified_outlined),
                              label: const Text('Resolve Dispute'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppSectionCard(
                title: 'Trust and Rating',
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Generator Rating',
                      value: _formatRating(currentRequest?.generatorRating),
                    ),
                    _InfoRow(
                      label: 'Collector Rating',
                      value: _formatRating(currentRequest?.collectorRating),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed:
                            currentRequest?.status == RequestStatus.completed
                            ? () => _openRatingsDialog(context, ref, requestId)
                            : null,
                        icon: const Icon(Icons.star_rate_rounded),
                        label: const Text('Rate This Pickup'),
                      ),
                    ),
                  ],
                ),
              ),
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

  String _labelFor(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.accepted:
        return 'Accepted by Collector';
      case RequestStatus.pickedUp:
        return 'Waste Picked Up';
      case RequestStatus.completed:
        return 'Completed';
      case RequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatRating(double? rating) {
    if (rating == null) return 'Not rated';
    return '${rating.toStringAsFixed(1)} / 5';
  }

  Future<String?> _pickImagePath() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    return picked?.path;
  }

  Future<void> _openRatingsDialog(
    BuildContext context,
    WidgetRef ref,
    String requestId,
  ) async {
    double generator = 4;
    double collector = 4;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: const Text('Submit Ratings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Generator: ${generator.toStringAsFixed(1)}'),
                Slider(
                  min: 1,
                  max: 5,
                  divisions: 8,
                  value: generator,
                  onChanged: (value) => setLocalState(() => generator = value),
                ),
                const SizedBox(height: 8),
                Text('Collector: ${collector.toStringAsFixed(1)}'),
                Slider(
                  min: 1,
                  max: 5,
                  divisions: 8,
                  value: collector,
                  onChanged: (value) => setLocalState(() => collector = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
    if (submitted != true) return;
    await ref
        .read(requestNotifierProvider.notifier)
        .submitRatings(
          requestId: requestId,
          generatorRating: generator,
          collectorRating: collector,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ratings submitted successfully.')),
    );
  }

  Future<void> _openDisputeDialog(
    BuildContext context,
    WidgetRef ref,
    String requestId,
  ) async {
    final reasonController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Dispute'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Describe issue with pickup/payment',
          ),
          minLines: 2,
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (submitted != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;
    await ref
        .read(requestNotifierProvider.notifier)
        .reportDispute(requestId: requestId, reason: reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dispute reported successfully.')),
    );
  }

  Future<void> _resolveDispute(
    BuildContext context,
    WidgetRef ref,
    String requestId,
  ) async {
    await ref
        .read(requestNotifierProvider.notifier)
        .resolveDispute(requestId: requestId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dispute resolved and payment marked as paid.'),
      ),
    );
  }

  DateTime? _dateForStatus({
    required RequestStatus status,
    required DateTime createdAt,
    required WasteRequest? item,
  }) {
    switch (status) {
      case RequestStatus.pending:
        return createdAt;
      case RequestStatus.accepted:
        return item?.acceptedAt;
      case RequestStatus.pickedUp:
        return item?.pickedUpAt;
      case RequestStatus.completed:
        return item?.completedAt;
      case RequestStatus.cancelled:
        return item?.cancelledAt;
    }
  }
}

class ImpactDashboardScreen extends ConsumerWidget {
  const ImpactDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Impact Dashboard')),
      body: requests.when(
        data: (items) {
          final completed = items
              .where((e) => e.status == RequestStatus.completed)
              .length;
          final totalKg = items.fold<double>(0, (sum, e) => sum + e.quantityKg);
          final co2 = items.fold<double>(0, (sum, e) => sum + e.co2SavedKg);
          final paid = items
              .where((e) => e.paymentStatus == PaymentStatus.paid)
              .length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppSectionCard(
                title: 'Environmental Impact',
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Waste diverted',
                      value: '${totalKg.toStringAsFixed(1)} kg',
                    ),
                    _InfoRow(
                      label: 'Estimated CO2 saved',
                      value: '${co2.toStringAsFixed(1)} kg',
                    ),
                    _InfoRow(label: 'Completed pickups', value: '$completed'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppSectionCard(
                title: 'Business Metrics',
                child: Column(
                  children: [
                    _InfoRow(label: 'Total requests', value: '${items.length}'),
                    _InfoRow(label: 'Paid requests', value: '$paid'),
                    _InfoRow(
                      label: 'Revenue estimate',
                      value:
                          'NGN ${items.fold<double>(0, (sum, e) => sum + (e.totalAmount ?? 0)).toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const AppSectionCard(
                title: 'Exportable Reports',
                child: Text(
                  'CSV/PDF report export can be connected to backend reporting endpoints.',
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            CenterState(title: 'Error', subtitle: '$e', icon: Icons.error),
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  const _StatusStep({
    required this.isDone,
    required this.isActive,
    required this.isLast,
    required this.label,
    this.dateTime,
  });

  final bool isDone;
  final bool isActive;
  final bool isLast;
  final String label;
  final DateTime? dateTime;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dotColor = isDone ? scheme.primary : scheme.outline;
    final textColor = isActive ? scheme.primary : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: dotColor,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: isDone ? scheme.primary : scheme.outlineVariant,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: textColor),
                ),
                if (dateTime != null)
                  Text(
                    dateTime!.toLocal().toString().split('.').first,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
