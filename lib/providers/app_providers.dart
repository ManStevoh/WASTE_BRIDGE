import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/core/network/api_client.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/app_notification.dart';
import 'package:waste_bridge/models/app_user.dart';
import 'package:waste_bridge/models/job.dart';
import 'package:waste_bridge/models/waste_request.dart';
import 'package:waste_bridge/services/auth_service.dart';
import 'package:waste_bridge/services/job_service.dart';
import 'package:waste_bridge/services/notification_service.dart';
import 'package:waste_bridge/services/transaction_service.dart';
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
final transactionServiceProvider = Provider((ref) => TransactionService());
final notificationServiceProvider = Provider((ref) => NotificationService());

final selectedRoleProvider = StateProvider<UserRole>(
  (ref) => UserRole.generator,
);

class AuthNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  AuthNotifier(this._authService) : super(const AsyncValue.data(null)) {
    loadSavedUser();
  }

  final AuthService _authService;

  Future<void> loadSavedUser() async {
    final user = await _authService.getSavedUser();
    state = AsyncValue.data(user);
  }

  Future<void> login(String email, String password, UserRole role) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _authService.login(email: email, password: password, role: role),
    );
  }

  Future<void> register(
    String name,
    String email,
    String password,
    UserRole role,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _authService.register(
        name: name,
        email: email,
        password: password,
        role: role,
      ),
    );
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AppUser?>>((ref) {
      return AuthNotifier(ref.read(authServiceProvider));
    });

class RequestNotifier extends StateNotifier<AsyncValue<List<WasteRequest>>> {
  RequestNotifier(this._ref, this._service, this._notificationService)
    : super(const AsyncValue.loading()) {
    fetch();
  }

  final Ref _ref;
  final WasteRequestService _service;
  final NotificationService _notificationService;

  Future<void> fetch() async {
    state = await AsyncValue.guard(_service.getRequests);
  }

  Future<void> addRequest({
    required String wasteType,
    required double quantityKg,
    required String location,
    DateTime? scheduledAt,
  }) async {
    final request = await _service.requestPickup(
      wasteType: wasteType,
      quantityKg: quantityKg,
      location: location,
      scheduledAt: scheduledAt,
    );
    await _notificationService.addNotification(
      title: 'Pickup Requested',
      message:
          'Request ${request.id} has been created and is pending assignment.',
      type: NotificationType.pickupAssigned,
    );
    await _ref.read(notificationsProvider.notifier).fetch();
    await fetch();
  }

  Future<void> uploadProof({
    required String requestId,
    required bool isBeforePickup,
    required String filePath,
  }) async {
    await _service.uploadPhotoProof(
      requestId: requestId,
      beforePickupPhotoUrl: isBeforePickup ? filePath : null,
      afterPickupPhotoUrl: isBeforePickup ? null : filePath,
    );
    await _notificationService.addNotification(
      title: isBeforePickup
          ? 'Before Pickup Proof Uploaded'
          : 'After Pickup Proof Uploaded',
      message: 'Photo evidence has been attached to request $requestId.',
      type: NotificationType.deliveryCompleted,
    );
    await _ref.read(notificationsProvider.notifier).fetch();
    await fetch();
  }

  Future<void> submitRatings({
    required String requestId,
    double? generatorRating,
    double? collectorRating,
  }) async {
    await _service.submitRatings(
      requestId: requestId,
      generatorRating: generatorRating,
      collectorRating: collectorRating,
    );
    await _notificationService.addNotification(
      title: 'Ratings Submitted',
      message: 'Trust ratings were updated for request $requestId.',
      type: NotificationType.deliveryCompleted,
    );
    await _ref.read(notificationsProvider.notifier).fetch();
    await fetch();
  }

  Future<void> reportDispute({
    required String requestId,
    required String reason,
  }) async {
    await _service.reportDispute(requestId: requestId, reason: reason);
    await fetch();
  }

  Future<void> resolveDispute({required String requestId}) async {
    await _service.resolveDispute(requestId: requestId);
    await fetch();
  }
}

final requestNotifierProvider =
    StateNotifierProvider<RequestNotifier, AsyncValue<List<WasteRequest>>>((
      ref,
    ) {
      return RequestNotifier(
        ref,
        ref.read(wasteRequestServiceProvider),
        ref.read(notificationServiceProvider),
      );
    });

class JobNotifier extends StateNotifier<AsyncValue<List<Job>>> {
  JobNotifier(
    this._ref,
    this._service,
    this._requestService,
    this._notificationService,
  ) : super(const AsyncValue.loading()) {
    fetch();
  }

  final Ref _ref;
  final JobService _service;
  final WasteRequestService _requestService;
  final NotificationService _notificationService;

  Future<void> fetch() async {
    state = await AsyncValue.guard(_service.getJobs);
  }

  Future<void> accept(String id) async {
    final jobs = state.valueOrNull ?? await _service.getJobs();
    final currentJob = jobs.firstWhere(
      (job) => job.id == id,
      orElse: () => throw StateError('Job not found'),
    );
    if (currentJob.status != JobStatus.open) {
      throw StateError('Only open jobs can be accepted.');
    }
    final updatedJob = await _service.acceptJob(id);
    await _requestService.updateRequestStatus(
      requestId: updatedJob.requestId,
      status: RequestStatus.accepted,
    );
    await _notificationService.addNotification(
      title: 'Pickup Assigned',
      message: 'Collector accepted request ${updatedJob.requestId}.',
      type: NotificationType.pickupAssigned,
    );
    await _ref.read(notificationsProvider.notifier).fetch();
    await fetch();
  }

  Future<void> setStatus(String id, JobStatus status) async {
    final jobs = state.valueOrNull ?? await _service.getJobs();
    final currentJob = jobs.firstWhere(
      (job) => job.id == id,
      orElse: () => throw StateError('Job not found'),
    );
    if (!_canTransition(currentJob.status, status)) {
      throw StateError(
        'Invalid transition from ${currentJob.status.name} to ${status.name}.',
      );
    }
    final updatedJob = await _service.updateStatus(jobId: id, status: status);
    final requestStatus = switch (status) {
      JobStatus.open => RequestStatus.pending,
      JobStatus.accepted => RequestStatus.accepted,
      JobStatus.arrived => RequestStatus.accepted,
      JobStatus.picked => RequestStatus.pickedUp,
      JobStatus.delivered => RequestStatus.completed,
    };
    await _requestService.updateRequestStatus(
      requestId: updatedJob.requestId,
      status: requestStatus,
    );
    final notificationType = status == JobStatus.delivered
        ? NotificationType.deliveryCompleted
        : NotificationType.collectorArriving;
    await _notificationService.addNotification(
      title: status == JobStatus.delivered
          ? 'Delivery Completed'
          : 'Collector Status Updated',
      message: 'Request ${updatedJob.requestId} is now ${status.name}.',
      type: notificationType,
    );
    await _ref.read(notificationsProvider.notifier).fetch();
    await fetch();
  }

  bool _canTransition(JobStatus from, JobStatus to) {
    if (from == to) return false;
    return switch (from) {
      JobStatus.open => to == JobStatus.accepted,
      JobStatus.accepted => to == JobStatus.arrived,
      JobStatus.arrived => to == JobStatus.picked,
      JobStatus.picked => to == JobStatus.delivered,
      JobStatus.delivered => false,
    };
  }
}

final jobNotifierProvider =
    StateNotifierProvider<JobNotifier, AsyncValue<List<Job>>>((ref) {
      return JobNotifier(
        ref,
        ref.read(jobServiceProvider),
        ref.read(wasteRequestServiceProvider),
        ref.read(notificationServiceProvider),
      );
    });

class NotificationsNotifier
    extends StateNotifier<AsyncValue<List<AppNotification>>> {
  NotificationsNotifier(this._service) : super(const AsyncValue.loading()) {
    fetch();
  }

  final NotificationService _service;

  Future<void> fetch() async {
    state = await AsyncValue.guard(_service.getNotifications);
  }
}

final notificationsProvider =
    StateNotifierProvider<
      NotificationsNotifier,
      AsyncValue<List<AppNotification>>
    >((ref) {
      return NotificationsNotifier(ref.read(notificationServiceProvider));
    });

final transactionsProvider = FutureProvider((ref) {
  return ref.read(transactionServiceProvider).getTransactions();
});
