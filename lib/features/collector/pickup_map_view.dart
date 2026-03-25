import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
  Timer? _simulationTimer;
  StreamSubscription<Position>? _positionSub;
  Timer? _routeDebounce;
  bool _usingDeviceGps = false;
  bool _busy = false;
  Map<String, dynamic>? _routePlan;
  bool _routePlanLoading = false;
  String? _routePlanError;

  @override
  void initState() {
    super.initState();
    _jobId = widget.jobId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initLocation());
    });
  }

  Future<void> _initLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _startSimulationFallback();
      unawaited(_refreshRoutePlan());
      return;
    }

    try {
      final p = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _collectorPos = LatLng(p.latitude, p.longitude);
        _usingDeviceGps = true;
      });
      unawaited(_refreshRoutePlan());
    } catch (_) {
      _startSimulationFallback();
      unawaited(_refreshRoutePlan());
      return;
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).listen(
      (pos) {
        if (!mounted) return;
        setState(() {
          _collectorPos = LatLng(pos.latitude, pos.longitude);
          _usingDeviceGps = true;
        });
        _debounceRoutePlan();
      },
      onError: (_) {},
    );
  }

  void _debounceRoutePlan() {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(seconds: 5), () {
      unawaited(_refreshRoutePlan());
    });
  }

  void _startSimulationFallback() {
    final jobs = ref.read(jobNotifierProvider).value ?? [];
    Job? currentJob;
    for (final item in jobs) {
      if (item.id == _jobId) {
        currentJob = item;
        break;
      }
    }
    if (currentJob == null) return;
    final route = _routeForJob(currentJob);
    final pickupPoint = _pickupLatLng(currentJob, route);
    _collectorPos ??= route.hub;
    _usingDeviceGps = false;
    _simulationTimer = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      _advanceCollectorPositionToward(pickupPoint, route);
    });
  }

  void _advanceCollectorPositionToward(LatLng pickupPoint, _CollectorRoute route) {
    final jobs = ref.read(jobNotifierProvider).value ?? [];
    Job? currentJob;
    for (final item in jobs) {
      if (item.id == _jobId) {
        currentJob = item;
        break;
      }
    }
    if (currentJob == null || _collectorPos == null) return;
    final destination = switch (currentJob.status) {
      JobStatus.accepted => pickupPoint,
      JobStatus.arrived => route.recycler,
      JobStatus.picked => route.recycler,
      JobStatus.delivered => route.recycler,
      JobStatus.open => pickupPoint,
    };
    final next = _stepTowards(
      from: _collectorPos!,
      to: destination,
      stepKm: _speedKmh * (_tick.inSeconds / 3600),
    );
    if (_distanceKm(next, _collectorPos!) <= 0.001) return;
    setState(() => _collectorPos = next);
  }

  Future<void> _refreshRoutePlan() async {
    final jobService = ref.read(jobServiceProvider);
    double? lat;
    double? lng;
    if (_collectorPos != null) {
      lat = _collectorPos!.latitude;
      lng = _collectorPos!.longitude;
    }
    setState(() {
      _routePlanLoading = true;
      _routePlanError = null;
    });
    try {
      final plan = await jobService.getRoutePlan(latitude: lat, longitude: lng);
      if (mounted) {
        setState(() {
          _routePlan = plan;
          final slat = plan['startLatitude'];
          final slng = plan['startLongitude'];
          if (_collectorPos == null && slat is num && slng is num) {
            _collectorPos = LatLng(slat.toDouble(), slng.toDouble());
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _routePlan = null;
          _routePlanError = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _routePlanLoading = false);
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _routeDebounce?.cancel();
    _positionSub?.cancel();
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

    final route = _routeForJob(currentJob);
    final pickupPoint = _pickupLatLng(currentJob, route);
    _collectorPos ??= route.hub;
    final destination = switch (currentJob.status) {
      JobStatus.accepted => pickupPoint,
      JobStatus.arrived => route.recycler,
      JobStatus.picked => route.recycler,
      JobStatus.delivered => route.recycler,
      JobStatus.open => pickupPoint,
    };

    final collector = _collectorPos!;
    final toDestinationKm = _distanceKm(collector, destination);
    final etaMinutes = (toDestinationKm / _speedKmh * 60).ceil();
    final canArrive =
        currentJob.status == JobStatus.accepted &&
        _distanceKm(collector, pickupPoint) <= _arrivalThresholdKm;
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
        position: pickupPoint,
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
        ? [collector, pickupPoint]
        : [collector, route.recycler];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup Map'),
        actions: [
          IconButton(
            tooltip: 'Refresh server route',
            onPressed: _routePlanLoading ? null : () => unawaited(_refreshRoutePlan()),
            icon: _routePlanLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.alt_route_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshRoutePlan,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(AppSpacing.md),
          children: [
            if (!_usingDeviceGps)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'GPS off or denied — showing simulated movement. '
                            'Enable location for live tracking.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                        target: pickupPoint,
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
            title: 'Server route (GET /jobs/route-plan)',
            child: _buildServerRoutePlan(context, currentJob.id),
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
      ),
    );
  }

  Widget _buildServerRoutePlan(BuildContext context, String currentJobPublicId) {
    if (_routePlanLoading && _routePlan == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_routePlanError != null) {
      return Text(
        _routePlanError!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    final plan = _routePlan;
    if (plan == null) {
      return const Text('No route plan from server.');
    }
    final total = plan['totalDistanceKm'];
    final algo = plan['algorithm']?.toString() ?? '—';
    final rawStops = plan['stops'];
    final stops = rawStops is List<dynamic> ? rawStops : const <dynamic>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Algorithm: $algo · Total ≈ ${total is num ? total.toStringAsFixed(1) : total} km',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (stops.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: const Text(
              'No active multi-stop jobs, or pickups lack GPS on the request.',
            ),
          )
        else
          ...List<Widget>.generate(stops.length, (i) {
            final s = stops[i];
            if (s is! Map<String, dynamic>) {
              return const SizedBox.shrink();
            }
            final jobMap = s['job'];
            Job? job;
            if (jobMap is Map<String, dynamic>) {
              try {
                job = Job.fromJson(jobMap);
              } catch (_) {
                job = null;
              }
            }
            final leg = s['legDistanceKm'];
            final legStr = leg is num ? '${leg.toStringAsFixed(1)} km leg' : '—';
            final title = job?.pickupLocation ?? 'Stop ${i + 1}';
            final jid = job?.id ?? '';
            final isCurrent = jid == currentJobPublicId;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: isCurrent
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text('${i + 1}'),
              ),
              title: Text(
                title,
                style: isCurrent
                    ? const TextStyle(fontWeight: FontWeight.w700)
                    : null,
              ),
              subtitle: Text(
                '${job?.wasteType ?? ''} · $legStr${isCurrent ? ' · this job' : ''}',
              ),
            );
          }),
      ],
    );
  }

  Future<void> _checkInStatus(JobStatus status) async {
    setState(() => _busy = true);
    try {
      await ref.read(jobNotifierProvider.notifier).setStatus(_jobId, status);
      if (!mounted) return;
      await _refreshRoutePlan();
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

  LatLng _pickupLatLng(Job job, _CollectorRoute route) {
    final lat = job.latitude;
    final lng = job.longitude;
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return route.pickup;
  }

  _CollectorRoute _routeForJob(Job job) {
    if (job.latitude != null && job.longitude != null) {
      final pickup = LatLng(job.latitude!, job.longitude!);
      return _CollectorRoute(
        hub: const LatLng(6.5244, 3.3792),
        pickup: pickup,
        recycler: LatLng(
          pickup.latitude + 0.03,
          pickup.longitude + 0.03,
        ),
      );
    }
    return _routeFor(job.pickupLocation);
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
