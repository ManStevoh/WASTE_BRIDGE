import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/models/app_notification.dart';
import 'package:waste_bridge/providers/service_providers.dart';
import 'package:waste_bridge/services/notification_service.dart';

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
