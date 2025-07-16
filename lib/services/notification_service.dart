// notification_service.dart
import 'package:flutter/material.dart';

enum NotificationType {
  success,
  error,
  warning,
  info,
}

class NotificationItem {
  final String id;
  final String message;
  final NotificationType type;
  final DateTime timestamp;

  NotificationItem({
    required this.id,
    required this.message,
    required this.type,
    required this.timestamp,
  });
}

class NotificationService {
  final List<NotificationItem> _notifications = [];
  OverlayEntry? _notificationOverlay;

  void showNotification(
      BuildContext context,
      String message, {
        NotificationType type = NotificationType.info,
      }) {
    final notification = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: type,
      timestamp: DateTime.now(),
    );

    _notifications.insert(0, notification);
    if (_notifications.length > 5) {
      _notifications.removeLast();
    }

    _showNotificationOverlay(context);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      dismissNotification(context, notification.id);
    });
  }

  void _showNotificationOverlay(BuildContext context) {
    _notificationOverlay?.remove();
    _notificationOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 60,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: _notifications
                .map((notification) => _buildNotificationCard(notification, context))
                .toList(),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_notificationOverlay!);
  }

  Widget _buildNotificationCard(NotificationItem notification, BuildContext context) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (notification.type) {
      case NotificationType.success:
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle_outline;
        break;
      case NotificationType.error:
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade800;
        icon = Icons.error_outline;
        break;
      case NotificationType.warning:
        backgroundColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        icon = Icons.warning_amber_outlined;
        break;
      case NotificationType.info:
      default:
        backgroundColor = Colors.blue.shade50;
        textColor = Colors.blue.shade800;
        icon = Icons.info_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notification.message,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => dismissNotification(context, notification.id),
            child: Icon(
              Icons.close,
              color: textColor.withOpacity(0.7),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  void dismissNotification(BuildContext context, String id) {
    _notifications.removeWhere((n) => n.id == id);
    if (_notifications.isEmpty) {
      _notificationOverlay?.remove();
      _notificationOverlay = null;
    } else {
      _showNotificationOverlay(context);
    }
  }
}