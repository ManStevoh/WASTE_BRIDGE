import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/job.dart';
import 'package:waste_bridge/providers/app_providers.dart';

/// Full-screen map + check-ins for an active pickup job.
class PickupMapView extends ConsumerStatefulWidget {
  const PickupMapView({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<PickupMapView> createState() => _PickupMapViewState();
}

class _PickupMapViewState extends ConsumerState<PickupMapView> {
  static const _arrivalThresholdKm = 0.12;
  static const _pickupThresholdKm = 0.15;
  static const _speedKmh = 28.0;
  static const _tick = Duration(seconds: 2);

  late final String _jobId;
  LatLng? _collectorPos;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _jobId = widget.jobId;
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      _advanceCollectorPosition();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(jobNotifierProvider).value ?? [];
    Job? currentJob;
    for (final item in jobs) {
      if (item.id == _jobId) {
        currentJob = item;
        break;
      }
    }
    if (currentJob == null) {
      return const Scaffold(
        body: CenterState(
          title: 'Map unavailable',
          subtitle: 'Job not found for route preview.',
          icon: Icons.map_outlined,
        ),
      );
    }

    final route = _routeFor(currentJob.pickupLocation);
    _collectorPos ??= route.hub;
    final destination = switch (currentJob.status) {
      JobStatus.accepted => route.pickup,
      JobStatus.arrived => route.recycler,
      JobStatus.picked => route.recycler,
      JobStatus.delivered => route.recycler,
      JobStatus.open => route.pickup,
    };

    final collector = _collectorPos!;
    final toDestinationKm = _distanceKm(collector, destination);
    final etaMinutes = (toDestinationKm / _speedKmh * 60).ceil();
    final canArrive =
        currentJob.status == JobStatus.accepted &&
        _distanceKm(collector, route.pickup) <= _arrivalThresholdKm;
    final canPick =
        currentJob.status == JobStatus.arrived &&
        _distanceKm(collector, route.recycler) <= _pickupThresholdKm;

    final mapMarkers = <Marker>{
      Marker(
        markerId: const MarkerId('collector'),
        position: collector,
        infoWindow: const InfoWindow(title: 'Collector'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      Marker(
        markerId: const MarkerId('pickup'),
        position: route.pickup,
        infoWindow: InfoWindow(title: 'Pickup', snippet: currentJob.pickupLocation),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('recycler'),
        position: route.recycler,
        infoWindow: const InfoWindow(title: 'Recycler'),
      ),
    };
    final routePoints = currentJob.status == JobStatus.accepted
        ? [collector, route.pickup]
        : [collector, route.recycler];

    return Scaffold(
      appBar: AppBar(title: const Text('Pickup Map')),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.md),
        children: [
          AppSectionCard(
            title: 'Live Route',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: route.pickup,
                        zoom: 12.8,
                      ),
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      markers: mapMarkers,
                      polylines: {
                        Polyline(
                          polylineId: const PolylineId('trip'),
                          points: routePoints,
                          width: 5,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      },
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text('Pickup: ${currentJob.pickupLocation}'),
                Text('Waste: ${currentJob.wasteType} (${currentJob.quantityKg} kg)'),
                Text('Status: ${currentJob.status.name.toUpperCase()}'),
                Text(
                  'ETA: ${etaMinutes <= 0 ? 'Reached' : '$etaMinutes min'}',
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          AppSectionCard(
            title: 'Map Check-ins',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: canArrive && !_busy
                      ? () => _checkInStatus(JobStatus.arrived)
                      : null,
                  icon: const Icon(Icons.place_rounded),
                  label: const Text('Arrived at Pickup'),
                ),
                FilledButton.tonalIcon(
                  onPressed: canPick && !_busy
                      ? () => _checkInStatus(JobStatus.picked)
                      : null,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Picked and Departed'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _advanceCollectorPosition() {
    final jobs = ref.read(jobNotifierProvider).value ?? [];
    Job? currentJob;
    for (final item in jobs) {
      if (item.id == _jobId) {
        currentJob = item;
        break;
      }
    }
    if (currentJob == null || _collectorPos == null) return;
    final route = _routeFor(currentJob.pickupLocation);
    final destination = switch (currentJob.status) {
      JobStatus.accepted => route.pickup,
      JobStatus.arrived => route.recycler,
      JobStatus.picked => route.recycler,
      JobStatus.delivered => route.recycler,
      JobStatus.open => route.pickup,
    };
    final next = _stepTowards(
      from: _collectorPos!,
      to: destination,
      stepKm: _speedKmh * (_tick.inSeconds / 3600),
    );
    if (_distanceKm(next, _collectorPos!) <= 0.001) return;
    setState(() => _collectorPos = next);
  }

  Future<void> _checkInStatus(JobStatus status) async {
    setState(() => _busy = true);
    try {
      await ref.read(jobNotifierProvider.notifier).setStatus(_jobId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Check-in saved as ${status.name}.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  _CollectorRoute _routeFor(String pickupLocation) {
    final lower = pickupLocation.toLowerCase();
    if (lower.contains('yaba')) {
      return const _CollectorRoute(
        hub: LatLng(6.5244, 3.3792),
        pickup: LatLng(6.5158, 3.3726),
        recycler: LatLng(6.5470, 3.3312),
      );
    }
    if (lower.contains('surulere')) {
      return const _CollectorRoute(
        hub: LatLng(6.5244, 3.3792),
        pickup: LatLng(6.4960, 3.3608),
        recycler: LatLng(6.5095, 3.3123),
      );
    }
    if (lower.contains('lekki')) {
      return const _CollectorRoute(
        hub: LatLng(6.5244, 3.3792),
        pickup: LatLng(6.4474, 3.4720),
        recycler: LatLng(6.4331, 3.4479),
      );
    }
    return const _CollectorRoute(
      hub: LatLng(6.5244, 3.3792),
      pickup: LatLng(6.5000, 3.3500),
      recycler: LatLng(6.5300, 3.3200),
    );
  }

  LatLng _stepTowards({
    required LatLng from,
    required LatLng to,
    required double stepKm,
  }) {
    final distance = _distanceKm(from, to);
    if (distance <= stepKm || distance == 0) return to;
    final ratio = stepKm / distance;
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * ratio,
      from.longitude + (to.longitude - from.longitude) * ratio,
    );
  }

  double _distanceKm(LatLng a, LatLng b) {
    const kmPerDegree = 111.32;
    final dLat = (b.latitude - a.latitude) * kmPerDegree;
    final avgLatRad = ((a.latitude + b.latitude) / 2) * 0.017453292519943295;
    final dLng = (b.longitude - a.longitude) * kmPerDegree * math.cos(avgLatRad).abs();
    return math.sqrt(dLat * dLat + dLng * dLng);
  }
}

class _CollectorRoute {
  const _CollectorRoute({
    required this.hub,
    required this.pickup,
    required this.recycler,
  });

  final LatLng hub;
  final LatLng pickup;
  final LatLng recycler;
}
