import 'dart:async';

import 'package:waste_bridge/models/app_notification.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/services/mock_data.dart';

class NotificationService {
  Future<List<AppNotification>> getNotifications() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return List<AppNotification>.from(MockData.notifications);
  }

  Future<AppNotification> addNotification({
    required String title,
    required String message,
    required NotificationType type,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final notification = AppNotification(
      id: 'n-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      type: type,
      createdAt: DateTime.now(),
    );
    MockData.notifications.insert(0, notification);
    return notification;
  }
}
