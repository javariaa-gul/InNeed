import 'package:flutter/material.dart';
import 'storage_service.dart';

class NotificationItem {
  final int id;
  final String title;
  final String body;
  final String type; // 'bid', 'offer', 'chat', 'job', 'review', 'status'
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    required this.createdAt,
    this.isRead = false,
  });
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final List<NotificationItem> _notifications = [];
  int _unreadCount = 0;

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;

  void addNotification({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) {
    final item = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );
    _notifications.insert(0, item);
    _unreadCount++;
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    _unreadCount = 0;
    notifyListeners();
  }

  void markRead(int id) {
    final n = _notifications.where((x) => x.id == id).firstOrNull;
    if (n != null && !n.isRead) {
      n.isRead = true;
      _unreadCount = (_unreadCount - 1).clamp(0, 9999);
      notifyListeners();
    }
  }

  void clear() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }
}
