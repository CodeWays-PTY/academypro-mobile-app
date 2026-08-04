import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_toast.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/checkin_controller.dart';
import 'create_event_modal.dart';
import 'batch_test_logger_modal.dart';

class EventsTabView extends ConsumerStatefulWidget {
  const EventsTabView({super.key});

  @override
  ConsumerState<EventsTabView> createState() => _EventsTabViewState();
}

class _EventsTabViewState extends ConsumerState<EventsTabView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final selectedAge = ref.read(selectedAgeGroupProvider);
      ref.read(dashboardEventsProvider.notifier).fetchEvents(ageGroup: selectedAge);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedAge = ref.watch(selectedAgeGroupProvider);

    ref.listen<String>(selectedAgeGroupProvider, (previous, next) {
      if (previous != next) {
        ref.read(dashboardEventsProvider.notifier).fetchEvents(ageGroup: next);
      }
    });

    final eventsState = ref.watch(dashboardEventsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(dashboardEventsProvider.notifier).fetchEvents(ageGroup: selectedAge);
        },
        child: eventsState.when(
          data: (events) {
            final now = DateTime.now();
            final todayStr = DateFormat('yyyy-MM-dd').format(now);

            // Filter today's events vs upcoming events vs past events dynamically
            final todayEvents = events.where((e) => e.date == todayStr).toList();
            final upcomingEvents = events.where((e) => e.date.compareTo(todayStr) > 0).toList();
            final pastEvents = events.where((e) => e.date.compareTo(todayStr) < 0).toList();

            todayEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
            upcomingEvents.sort((a, b) => a.date.compareTo(b.date) != 0 ? a.date.compareTo(b.date) : a.startTime.compareTo(b.startTime));
            pastEvents.sort((a, b) => b.date.compareTo(a.date) != 0 ? b.date.compareTo(a.date) : b.startTime.compareTo(a.startTime));

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 100.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===================================================================
                  // 1. CLEAN HEADER (Fixed layout, no text collision)
                  // ===================================================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Events & Schedule',
                              style: TextStyle(
                                fontSize: 22.0,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 3.0),
                            Text(
                              'Manage training sessions, gym tests & matches',
                              style: TextStyle(
                                fontSize: 12.0,
                                color: Color(0xFF64748B),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      IconButton(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          await ref.read(dashboardEventsProvider.notifier).fetchEvents(ageGroup: selectedAge);
                          if (!mounted) return;
                          AppToast.showSuccess(this.context, title: 'Refreshed', message: 'Latest events updated!');
                        },
                        icon: const Icon(Icons.sync, color: Color(0xFF003EC7), size: 20.0),
                        tooltip: 'Refresh Events',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFEFF4FF),
                          padding: const EdgeInsets.all(10.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          CreateEventModal.show(context);
                        },
                        icon: const Icon(Icons.add, size: 16.0),
                        label: const Text('Add Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003EC7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20.0),

                  // ===================================================================
                  // 2. TODAY'S EVENTS SECTION
                  // ===================================================================
                  const Text(
                    "TODAY'S SCHEDULE",
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10.0),

                  if (todayEvents.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.event_busy, color: Color(0xFF94A3B8), size: 36.0),
                          SizedBox(height: 8.0),
                          Text(
                            'No sessions scheduled for today',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: todayEvents.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12.0),
                      itemBuilder: (context, index) {
                        return _buildEventCard(context, todayEvents[index]);
                      },
                    ),

                  const SizedBox(height: 24.0),

                  // ===================================================================
                  // 3. UPCOMING EVENTS SECTION
                  // ===================================================================
                  const Text(
                    'UPCOMING SESSIONS',
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10.0),

                  if (upcomingEvents.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Text(
                          'No upcoming events scheduled',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: upcomingEvents.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12.0),
                      itemBuilder: (context, index) {
                        return _buildEventCard(context, upcomingEvents[index]);
                      },
                    ),

                  if (pastEvents.isNotEmpty) ...[
                    const SizedBox(height: 24.0),
                    const Text(
                      'PAST SESSIONS',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pastEvents.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12.0),
                      itemBuilder: (context, index) {
                        return _buildEventCard(context, pastEvents[index]);
                      },
                    ),
                  ],

                  const SizedBox(height: 32.0),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text(
              'Failed to load events: $err',
              style: const TextStyle(color: Color(0xFFBA1A1A)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, CoachEvent event) {
    Color leftBorderColor = const Color(0xFF003EC7);
    Color badgeBgColor = const Color(0xFFDBEAFE);
    Color badgeTextColor = const Color(0xFF1D4ED8);
    IconData iconData = Icons.sports_soccer;
    String badgeText = event.eventType;

    switch (event.eventType) {
      case 'Field':
      case 'Field Session':
        leftBorderColor = const Color(0xFF003EC7);
        badgeBgColor = const Color(0xFFDBEAFE);
        badgeTextColor = const Color(0xFF1D4ED8);
        iconData = Icons.sports_soccer;
        badgeText = 'Field';
        break;
      case 'Gym':
      case 'Gym Session':
        leftBorderColor = const Color(0xFF7C3AED);
        badgeBgColor = const Color(0xFFF3E8FF);
        badgeTextColor = const Color(0xFF6B21A8);
        iconData = Icons.fitness_center;
        badgeText = 'Gym';
        break;
      case 'Fitness Test':
      case 'Test Day':
        leftBorderColor = const Color(0xFFD97706);
        badgeBgColor = const Color(0xFFFEF3C7);
        badgeTextColor = const Color(0xFF92400E);
        iconData = Icons.timer_outlined;
        badgeText = 'Fitness Test';
        break;
      case 'Match':
      case 'Match Day':
        leftBorderColor = const Color(0xFF166534);
        badgeBgColor = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF15803D);
        iconData = Icons.sports_score;
        badgeText = 'Match';
        break;
      default:
        leftBorderColor = const Color(0xFF003EC7);
        badgeBgColor = const Color(0xFFDBEAFE);
        badgeTextColor = const Color(0xFF1D4ED8);
        iconData = Icons.sports_soccer;
        break;
    }

    return InkWell(
      onTap: () => _showEventDetailsBottomSheet(context, event),
      borderRadius: BorderRadius.circular(20.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0A0F172A),
              blurRadius: 16.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left Category Indicator Accent Bar
              Container(
                width: 5.0,
                decoration: BoxDecoration(
                  color: leftBorderColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    bottomLeft: Radius.circular(20.0),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6.0,
                              runSpacing: 6.0,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Category Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
                                  decoration: BoxDecoration(
                                    color: badgeBgColor,
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(iconData, size: 12.0, color: badgeTextColor),
                                      const SizedBox(width: 4.0),
                                      Text(
                                        badgeText.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: badgeTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Team Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8.0),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.shield_outlined, size: 11.0, color: Color(0xFF003EC7)),
                                      const SizedBox(width: 4.0),
                                      Text(
                                        event.team,
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ),
                                // Important Badge
                                if (event.isImportant)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(8.0),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star, color: Color(0xFFD97706), size: 11.0),
                                        SizedBox(width: 4.0),
                                        Text(
                                          'IMPORTANT',
                                          style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          const Padding(
                            padding: EdgeInsets.only(top: 2.0),
                            child: Icon(Icons.chevron_right, size: 20.0, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10.0),
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14.0, color: Color(0xFF64748B)),
                          const SizedBox(width: 6.0),
                          Text(
                            '${event.startTime} • ${event.date} (${event.durationMins ?? 60}m)',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 12.0),
                          const Icon(Icons.location_on_outlined, size: 14.0, color: Color(0xFF64748B)),
                          const SizedBox(width: 4.0),
                          Expanded(
                            child: Text(
                              event.location,
                              style: const TextStyle(fontSize: 12.0, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (event.workoutImagePath != null && event.eventType != 'Match') ...[
                        const SizedBox(height: 10.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo, color: Color(0xFF166534), size: 13.0),
                              SizedBox(width: 6.0),
                              Text(
                                'Workout Photo Attached',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventDetailsBottomSheet(BuildContext context, CoachEvent event) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24.0, 20.0, 24.0, MediaQuery.of(context).padding.bottom + 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Text(
                '${event.eventType} • ${event.startTime} • ${event.location}',
                style: const TextStyle(fontSize: 13.0, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20.0),
              // Display Workout Attachment directly inside details modal
              if (event.workoutImagePath != null && event.workoutImagePath!.trim().isNotEmpty && event.eventType != 'Match') ...[
                const Text(
                  'WORKOUT ROUTINE ATTACHMENT',
                  style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
                ),
                const SizedBox(height: 8.0),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 220.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: _buildWorkoutPreviewWidget(event.workoutImagePath!),
                  ),
                ),
                const SizedBox(height: 16.0),
              ],
              // Log Test Scores CTA Button (Prominent for Test Day events)
              if (event.eventType.toLowerCase().contains('test')) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      BatchTestLoggerModal.show(
                        context,
                        ageGroup: event.team.isNotEmpty ? event.team : 'U15',
                        initialEvent: event,
                      );
                    },
                    icon: const Icon(Icons.speed, size: 18.0),
                    label: const Text('Log Test Scores for this Event', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                  ),
                ),
                const SizedBox(height: 10.0),
              ],

              // Start Practice Check-In CTA Button (Disabled for past events)
              Builder(
                builder: (context) {
                  final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                  final isPastEvent = event.date.compareTo(nowStr) < 0;

                  if (isPastEvent) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_clock_outlined, color: Color(0xFF64748B), size: 18.0),
                          SizedBox(width: 8.0),
                          Text(
                            'Check-In Closed (Past Event)',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 13.5),
                          ),
                        ],
                      ),
                    );
                  }

                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(checkInProvider.notifier).selectEvent(event);
                        ref.read(dashboardTabProvider.notifier).state = 2;
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 18.0),
                      label: const Text('Start Practice Check-In For This Event', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003EC7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10.0),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        CreateEventModal.show(context, eventToEdit: event);
                      },
                      icon: const Icon(Icons.edit, size: 16.0),
                      label: const Text('Edit Event'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(dashboardEventsProvider.notifier).deleteEvent(event.id);
                      },
                      icon: const Icon(Icons.delete, size: 16.0, color: Color(0xFFEF4444)),
                      label: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildWorkoutPreviewWidget(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallbackAttachmentBox(path),
      );
    } else if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallbackAttachmentBox(path),
      );
    } else {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(file, fit: BoxFit.cover);
        }
      } catch (_) {}
      return _buildFallbackAttachmentBox(path);
    }
  }

  Widget _buildFallbackAttachmentBox(String text) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      color: const Color(0xFFF1F5F9),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fitness_center, color: Color(0xFF003EC7), size: 36.0),
          const SizedBox(height: 8.0),
          Text(
            text.split('/').last,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4.0),
          const Text(
            'Workout Plan Attached',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
