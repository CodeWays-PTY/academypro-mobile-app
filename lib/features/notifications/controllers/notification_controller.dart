import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';
import '../models/notification_item.dart';

class NotificationState {
  final List<NotificationItem> notifications;
  final int unreadCount;
  final bool loading;
  final String? error;
  final String filter; // 'all' or 'unread'

  NotificationState({
    required this.notifications,
    required this.unreadCount,
    required this.loading,
    this.error,
    this.filter = 'all',
  });

  factory NotificationState.initial() => NotificationState(
        notifications: [],
        unreadCount: 0,
        loading: false,
      );

  List<NotificationItem> get filteredNotifications {
    if (filter == 'unread') {
      return notifications.where((n) => !n.isRead).toList();
    }
    return notifications;
  }

  NotificationState copyWith({
    List<NotificationItem>? notifications,
    int? unreadCount,
    bool? loading,
    String? error,
    String? filter,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      loading: loading ?? this.loading,
      error: error,
      filter: filter ?? this.filter,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final ApiClient _apiClient;

  NotificationNotifier(this._apiClient) : super(NotificationState.initial()) {
    fetchNotifications();
  }

  Future<void> fetchNotifications({bool isUserInitiated = false}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final response = await _apiClient.getAndCache('/api/notifications');
      if (response.statusCode == 200 && response.data != null && response.data['success'] == true) {
        final data = response.data['data'] ?? {};
        final List notifList = data['notifications'] ?? [];
        final List<NotificationItem> items =
            notifList.map((n) => NotificationItem.fromJson(n)).toList();
        final int unread = data['unreadCount'] ?? items.where((i) => !i.isRead).length;

        state = state.copyWith(
          notifications: items,
          unreadCount: unread,
          loading: false,
          error: null,
        );
      } else {
        state = state.copyWith(loading: false, error: response.data?['message'] ?? 'Failed to load notifications');
      }
    } catch (e) {
      debugPrint('Error in fetchNotifications: $e');
      state = state.copyWith(loading: false, error: e.toString());
      if (isUserInitiated) {
        AppToast.showError(null, title: 'Network Failure', message: 'Could not refresh notifications.');
      }
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }

  Future<void> markAsRead(int id) async {
    final updatedList = state.notifications.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    final newUnread = updatedList.where((n) => !n.isRead).length;
    state = state.copyWith(notifications: updatedList, unreadCount: newUnread);

    try {
      await _apiClient.dio.post('/api/notifications/$id/read');
    } catch (e) {
      debugPrint('Error in markAsRead: $e');
      AppToast.showError(null, title: 'Network Failure', message: 'Failed to update notification status.');
    }
  }

  Future<void> markAllAsRead() async {
    final updatedList = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updatedList, unreadCount: 0);

    try {
      await _apiClient.dio.post('/api/notifications/read-all');
    } catch (e) {
      debugPrint('Error in markAllAsRead: $e');
      AppToast.showError(null, title: 'Network Failure', message: 'Failed to mark notifications as read.');
    }
  }

  Future<void> deleteNotification(int id) async {
    final updatedList = state.notifications.where((n) => n.id != id).toList();
    final newUnread = updatedList.where((n) => !n.isRead).length;
    state = state.copyWith(notifications: updatedList, unreadCount: newUnread);

    try {
      await _apiClient.dio.post('/api/notifications/$id/delete');
    } catch (e) {
      try {
        await _apiClient.dio.delete('/api/notifications/$id');
      } catch (err) {
        debugPrint('Error in deleteNotification: $err');
        AppToast.showError(null, title: 'Network Failure', message: 'Failed to delete notification.');
      }
    }
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationNotifier(apiClient);
});
