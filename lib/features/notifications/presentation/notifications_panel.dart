import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/notification_controller.dart';
import '../models/notification_item.dart';
import '../../../core/utils/app_toast.dart';

class NotificationsPanel extends ConsumerWidget {
  const NotificationsPanel({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationsPanel(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final notifier = ref.read(notificationProvider.notifier);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20.0,
            spreadRadius: 2.0,
            offset: Offset(0, -4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle pill
          const SizedBox(height: 12.0),
          Container(
            width: 44.0,
            height: 5.0,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(3.0),
            ),
          ),
          const SizedBox(height: 16.0),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: Color(0xFF2563EB),
                  size: 24.0,
                ),
                const SizedBox(width: 10.0),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8.0),
                if (state.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      '${state.unreadCount} NEW',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                const Spacer(),
                if (state.notifications.any((n) => !n.isRead))
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      notifier.markAllAsRead();
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 16.0, color: Color(0xFF2563EB)),
                    label: const Text(
                      'Mark all read',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                        fontSize: 13.0,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14.0),

          // Filter Segmented Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterTab(
                      context,
                      label: 'All (${state.notifications.length})',
                      isSelected: state.filter == 'all',
                      onTap: () => notifier.setFilter('all'),
                    ),
                  ),
                  Expanded(
                    child: _buildFilterTab(
                      context,
                      label: 'Unread (${state.unreadCount})',
                      isSelected: state.filter == 'unread',
                      onTap: () => notifier.setFilter('unread'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12.0),

          // Notifications List Body
          Expanded(
            child: state.loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                  )
                : state.filteredNotifications.isEmpty
                    ? _buildEmptyState(context, state.filter)
                    : RefreshIndicator(
                        onRefresh: () => notifier.fetchNotifications(),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                          itemCount: state.filteredNotifications.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10.0),
                          itemBuilder: (context, index) {
                            final item = state.filteredNotifications[index];
                            return _buildNotificationCard(context, ref, item);
                          },
                        ),
                      ),
          ),

          // Bottom Action Bar with Solid SafeArea Padding
          Container(
            padding: EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 14.0,
              bottom: bottomInset + 16.0,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
            ),
            child: Row(
              children: [
                if (state.unreadCount > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        notifier.markAllAsRead();
                      },
                      icon: const Icon(Icons.done_all, size: 16.0, color: Color(0xFF2563EB)),
                      label: const Text(
                        'Mark All Read',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ),
                if (state.unreadCount > 0) const SizedBox(width: 12.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13.0),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9.0),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 4.0,
                    offset: Offset(0, 1),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.0,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, WidgetRef ref, NotificationItem item) {
    final notifier = ref.read(notificationProvider.notifier);

    return Dismissible(
      key: Key('notif_${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        notifier.deleteNotification(item.id);
        AppToast.showInfo(context, title: 'Removed', message: 'Notification dismissed.');
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24.0),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          if (!item.isRead) {
            notifier.markAsRead(item.id);
          }
          _showDetailDialog(context, item);
        },
        borderRadius: BorderRadius.circular(16.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: item.isRead ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: item.isRead ? const Color(0xFFE2E8F0) : const Color(0xFF93C5FD),
              width: item.isRead ? 1.0 : 1.5,
            ),
            boxShadow: item.isRead
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.06),
                      blurRadius: 8.0,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                width: 42.0,
                height: 42.0,
                decoration: BoxDecoration(
                  color: item.iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.icon,
                  color: item.iconColor,
                  size: 22.0,
                ),
              ),
              const SizedBox(width: 12.0),

              // Title and Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: 6.0),
                          Container(
                            width: 8.0,
                            height: 8.0,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 13.0,
                        color: item.isRead ? const Color(0xFF64748B) : const Color(0xFF334155),
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      item.timeAgo,
                      style: const TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4.0),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1),
                size: 20.0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String filter) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 40.0,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              filter == 'unread' ? 'All caught up!' : 'No notifications yet',
              style: const TextStyle(
                fontSize: 17.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              filter == 'unread'
                  ? 'You have read all alert messages in your inbox.'
                  : 'Important team alerts and match logs will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailDialog(BuildContext context, NotificationItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        titlePadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0),
        contentPadding: const EdgeInsets.fromLTRB(20.0, 14.0, 20.0, 20.0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: item.iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.iconColor, size: 22.0),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.body,
              style: const TextStyle(
                fontSize: 14.0,
                color: Color(0xFF334155),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Received ${item.timeAgo}',
                  style: const TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: item.iconBgColor,
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Text(
                    item.type.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.w800,
                      color: item.iconColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
