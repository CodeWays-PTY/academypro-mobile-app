import 'package:flutter/material.dart';
import '../../../core/utils/type_parsers.dart';

class NotificationItem {
  final int id;
  final String userId;
  final String title;
  final String body;
  final String type; // 'academic_flag', 'match_update', 'event_schedule', 'system', 'general'
  final bool isRead;
  final String? actionRoute;
  final String createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.actionRoute,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: TypeParsers.parseInt(json['id']),
      userId: TypeParsers.parseString(json['userId'] ?? json['user_id']),
      title: TypeParsers.parseString(json['title']),
      body: TypeParsers.parseString(json['body']),
      type: TypeParsers.parseString(json['type'], 'general'),
      isRead: TypeParsers.parseBool(json['isRead'] ?? json['is_read']),
      actionRoute: json['actionRoute'] != null ? TypeParsers.parseString(json['actionRoute']) : (json['action_route'] != null ? TypeParsers.parseString(json['action_route']) : null),
      createdAt: TypeParsers.parseString(json['createdAt'] ?? json['created_at']),
    );
  }

  NotificationItem copyWith({
    int? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    bool? isRead,
    String? actionRoute,
    String? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      actionRoute: actionRoute ?? this.actionRoute,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  IconData get icon {
    switch (type) {
      case 'academic_flag':
        return Icons.warning_amber_rounded;
      case 'match_update':
        return Icons.sports_outlined;
      case 'event_schedule':
        return Icons.event_available_outlined;
      case 'system':
        return Icons.phonelink_ring_outlined;
      case 'general':
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color get iconBgColor {
    switch (type) {
      case 'academic_flag':
        return const Color(0xFFFEE2E2); // Light red
      case 'match_update':
        return const Color(0xFFDBEAFE); // Light blue
      case 'event_schedule':
        return const Color(0xFFF3E8FF); // Light purple
      case 'system':
        return const Color(0xFFDCFCE7); // Light green
      case 'general':
      default:
        return const Color(0xFFFEF3C7); // Light amber
    }
  }

  Color get iconColor {
    switch (type) {
      case 'academic_flag':
        return const Color(0xFFDC2626); // Red
      case 'match_update':
        return const Color(0xFF2563EB); // Blue
      case 'event_schedule':
        return const Color(0xFF9333EA); // Purple
      case 'system':
        return const Color(0xFF16A34A); // Green
      case 'general':
      default:
        return const Color(0xFFD97706); // Amber
    }
  }

  String get timeAgo {
    if (createdAt.isEmpty) return 'Just now';
    try {
      final parsed = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(parsed);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${parsed.day}/${parsed.month}';
    } catch (_) {
      return createdAt;
    }
  }
}
