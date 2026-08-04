import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/utils/phone_utils.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/roster_controller.dart';
import '../../auth/presentation/auth_state.dart';
import 'roster_tab_view.dart';
import 'checkin_tab_view.dart';
import 'events_tab_view.dart';
import 'profile_tab_view.dart';
import 'create_action_modal.dart';
import 'manage_metrics_modal.dart';
import 'batch_test_logger_modal.dart';

import '../../notifications/controllers/notification_controller.dart';
import '../../notifications/presentation/notifications_panel.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final activeGroup = ref.read(selectedAgeGroupProvider);
      ref.read(dashboardSummaryProvider.notifier).fetchSummary(ageGroup: activeGroup);
      ref.read(dashboardFlagsProvider.notifier).fetchFlags(ageGroup: activeGroup);
      ref.read(risingStarsProvider.notifier).fetchRisingStars(ageGroup: activeGroup);
      ref.read(notificationProvider.notifier).fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(dashboardTabProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final flagsState = ref.watch(dashboardFlagsProvider);
    final starsState = ref.watch(risingStarsProvider);
    final coachActions = ref.watch(coachActionProvider);
    final userProfile = ref.watch(authProvider).userProfile ?? LocalStorage.getUserProfile() ?? {};
    final notifState = ref.watch(notificationProvider);

    final firstName = userProfile['first_name'] ?? userProfile['firstName'] ?? '--';
    final lastName = userProfile['last_name'] ?? userProfile['lastName'] ?? '--';
    final avatarPath = userProfile['avatarUrl'] ?? userProfile['profile_pic'];
    final initials = '${firstName.isNotEmpty && firstName != '--' ? firstName[0] : ''}${lastName.isNotEmpty && lastName != '--' ? lastName[0] : ''}';

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 56.0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: GestureDetector(
            onTap: () {
              ref.read(dashboardTabProvider.notifier).state = 4;
            },
            child: CircleAvatar(
              backgroundColor: const Color(0xFF003EC7),
              child: avatarPath != null && avatarPath.toString().isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20.0),
                      child: avatarPath.toString().startsWith('http')
                          ? Image.network(avatarPath.toString(), fit: BoxFit.cover, width: 40, height: 40)
                          : Image.file(File(avatarPath.toString()), fit: BoxFit.cover, width: 40, height: 40),
                    )
                  : Text(
                      initials,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.0),
                    ),
            ),
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AcademyPro',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003EC7),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF434656)),
                onPressed: () {
                  NotificationsPanel.show(context);
                },
              ),
              if (notifState.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4.0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${notifState.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, activeIndex: activeTab),
      body: _buildBody(activeTab, summary, flagsState, starsState, coachActions),
    );
  }

  Widget _buildBody(
    int activeTab,
    DashboardSummaryState summary,
    AsyncValue<List<FlaggedPlayer>> flagsState,
    AsyncValue<List<RisingStarPlayer>> starsState,
    List<CoachActionItem> coachActions,
  ) {
    switch (activeTab) {
      case 1:
        return const RosterTabView();
      case 2:
        return const CheckInTabView();
      case 3:
        return const EventsTabView();
      case 4:
        return const ProfileTabView();
      case 0:
      default:
        return _buildDashboardOverview(summary, flagsState, starsState, coachActions);
    }
  }

  Widget _buildDashboardOverview(
    DashboardSummaryState summary,
    AsyncValue<List<FlaggedPlayer>> flagsState,
    AsyncValue<List<RisingStarPlayer>> starsState,
    List<CoachActionItem> coachActions,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        final activeGroup = ref.read(selectedAgeGroupProvider);
        await ref.read(dashboardSummaryProvider.notifier).fetchSummary(ageGroup: activeGroup);
        await ref.read(dashboardFlagsProvider.notifier).fetchFlags(ageGroup: activeGroup);
        await ref.read(risingStarsProvider.notifier).fetchRisingStars(ageGroup: activeGroup);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 100.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Team Selector dropdown
            const Text(
              'CURRENT COMMAND',
              style: TextStyle(
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: Consumer(
                builder: (context, ref, child) {
                  final squads = ref.watch(squadsProvider);
                  final selectedAgeGroup = ref.watch(selectedAgeGroupProvider);
                  
                  final activeValue = squads.any((s) => s.ageGroup == selectedAgeGroup) 
                      ? selectedAgeGroup 
                      : (squads.isNotEmpty ? squads.first.ageGroup : 'U15');

                  return DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: activeValue,
                      borderRadius: BorderRadius.circular(16.0),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB)),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 15.0),
                      items: [
                        ...squads.map((sq) => DropdownMenuItem(
                              value: sq.ageGroup,
                              child: Text(sq.name),
                            )),
                      ],
                      onChanged: (newAge) {
                        if (newAge != null) {
                          ref.read(selectedAgeGroupProvider.notifier).state = newAge;
                          LocalStorage.cacheData('selected_age_group', newAge);
                          ref.read(dashboardSummaryProvider.notifier).fetchSummary(ageGroup: newAge);
                          ref.read(dashboardFlagsProvider.notifier).fetchFlags(ageGroup: newAge);
                          ref.read(risingStarsProvider.notifier).fetchRisingStars(ageGroup: newAge);
                          ref.read(dashboardEventsProvider.notifier).fetchEvents(ageGroup: newAge);
                          ref.read(rosterProvider.notifier).fetchRoster(newAge);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final currentAge = ref.read(selectedAgeGroupProvider);
                      BatchTestLoggerModal.show(context, ageGroup: currentAge);
                    },
                    icon: const Icon(Icons.speed, size: 16.0, color: Color(0xFF2563EB)),
                    label: const Text('Log Squad Test', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ManageMetricsModal.show(context);
                    },
                    icon: const Icon(Icons.tune, size: 16.0, color: Color(0xFF475569)),
                    label: const Text('Test Metrics', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20.0),

            // Squad KPIs Overview Row
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    'ATTENDANCE',
                    '${summary.attendancePercent}%',
                    Icons.trending_up,
                    summary.loading,
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: _buildKpiCard(
                    'PERFORMANCE avg',
                    '${summary.teamPerformanceAvg}%',
                    Icons.sports_score,
                    summary.loading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    'SQUAD HEALTH',
                    'Optimum',
                    Icons.favorite_outline,
                    summary.loading,
                    subtitle: '${summary.uniReady + summary.onTrack} of ${summary.totalPlayers} fit units',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28.0),

            // ===================================================================
            // SECTION 1: RISING STARS (5-WEEK CONSISTENCY CLUB)
            // ===================================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium, color: Color(0xFF10B981), size: 22.0),
                    SizedBox(width: 8.0),
                    Text(
                      'Rising Stars',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: const Text(
                    '5 WKS CONSISTENT',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            const Text(
              'Only displayed when grades are up, attendance is up, and gym progress is consistent for 5+ weeks.',
              style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14.0),

            starsState.when(
              data: (players) {
                // APPLY STRICT QUALIFICATION FILTER & AGE GROUP MATCHING
                final qualifiedStars = players
                    .where((p) => p.isQualifiedForRisingStar && p.ageGroup == ref.watch(selectedAgeGroupProvider))
                    .toList();

                if (qualifiedStars.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.military_tech_outlined, color: Color(0xFF94A3B8), size: 36.0),
                        SizedBox(height: 8.0),
                        Text(
                          'No Athletes Currently Qualify for Rising Stars',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 14.0),
                        ),
                        SizedBox(height: 4.0),
                        Text(
                          'Athletes require 5 consecutive weeks of simultaneous improvement across Grades, Attendance, and Gym performance.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  );
                }

                return SizedBox(
                  height: 215.0,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: qualifiedStars.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14.0),
                    itemBuilder: (context, index) {
                      return _buildRisingStarCard(context, qualifiedStars[index]);
                    },
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox(),
            ),

            const SizedBox(height: 28.0),

            // ===================================================================
            // SECTION 2: REQUIRES ATTENTION (CAROUSEL WITH RISING STAR DESIGN)
            // ===================================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22.0),
                    SizedBox(width: 8.0),
                    Text(
                      'Requires Attention',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                flagsState.when(
                  data: (list) {
                    final filtered = list.where((p) => p.ageGroup == ref.watch(selectedAgeGroupProvider)).toList();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Text(
                        '${filtered.length} FLAGS',
                        style: const TextStyle(
                          fontSize: 10.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, _) => const SizedBox(),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            const Text(
              'Swipe horizontally to review flagged squad members & assign action plans.',
              style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14.0),

            flagsState.when(
              data: (list) {
                final filtered = list.where((p) => p.ageGroup == ref.watch(selectedAgeGroupProvider)).toList();
                if (filtered.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Text(
                        'No critical warning flags detected today for this squad.',
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                }
                return SizedBox(
                  height: 220.0,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14.0),
                    itemBuilder: (context, index) {
                      return _buildFlagCarouselCard(context, filtered[index]);
                    },
                  ),
                );
              },
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              )),
              error: (err, _) => Center(child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error loading warnings: $err', style: const TextStyle(color: Color(0xFFDC2626))),
              )),
            ),

            const SizedBox(height: 28.0),

            // ===================================================================
            // SECTION 3: COACH CUSTOM ACTION TASKS BOARD
            // ===================================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.task_alt, color: Color(0xFF2563EB), size: 22.0),
                    SizedBox(width: 8.0),
                    Text(
                      'Coach Action Tasks (To-Do)',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Text(
                    '${coachActions.where((a) => !a.isCompleted).length} OPEN',
                    style: const TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),

            if (coachActions.isEmpty)
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
                    'No open action tasks. Use "Set Action Plan" on any player to define custom tasks.',
                    style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: coachActions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8.0),
                itemBuilder: (context, index) {
                  final item = coachActions[index];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showActionItemDetailsModal(context, item);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18.0),
                        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A0F172A),
                            blurRadius: 16.0,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.read(coachActionProvider.notifier).toggleAction(item.id);
                            },
                            child: Icon(
                              item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: item.isCompleted ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                              size: 22.0,
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: item.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                    decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  '${item.playerName} • Added ${item.dateAdded}',
                                  style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              item.category,
                              style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showActionItemDetailsModal(BuildContext context, CoachActionItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 16.0,
            bottom: 24.0 + bottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC3C5D9).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      item.category.toUpperCase(),
                      style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Text(
                item.title,
                style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6.0),
              Text(
                'Assigned Player: ${item.playerName} • Added ${item.dateAdded}',
                style: const TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20.0),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16.0),

              // Parent & Guardian Contact Section
              const Text(
                'PARENT / GUARDIAN CONTACT',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
              ),
              const SizedBox(height: 10.0),
              Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Color(0xFF2563EB), size: 18.0),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Text(
                        item.parentName,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14.0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),

              // Player Direct Contact
              const Text(
                'PLAYER DIRECT CONTACT',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
              ),
              const SizedBox(height: 10.0),
              Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smartphone, color: Color(0xFF003EC7), size: 18.0),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          final clean = item.playerPhone.replaceAll(RegExp(r'[^\d+]'), '');
                          launchUrl(Uri.parse('tel:$clean'));
                        },
                        child: Text(
                          '${item.playerName}: ${PhoneUtils.formatRSAPhone(item.playerPhone)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13.0),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16.0, color: Color(0xFF003EC7)),
                      tooltip: 'Copy Player Phone Number',
                      padding: const EdgeInsets.all(4.0),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: item.playerPhone));
                        HapticFeedback.lightImpact();
                        AppToast.showInfo(
                          context,
                          title: 'Phone Number Copied',
                          message: 'Player contact phone (${item.playerPhone}) copied to clipboard.',
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),

              // Plan Guidance & Notes
              const Text(
                'ACTION PLAN DETAILS & GUIDANCE',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
              ),
              const SizedBox(height: 8.0),
              Text(
                item.notes,
                style: const TextStyle(fontSize: 13.0, color: Color(0xFF334155), height: 1.4),
              ),
              const SizedBox(height: 24.0),

              // Toggle Action Button
              SizedBox(
                width: double.infinity,
                height: 48.0,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.read(coachActionProvider.notifier).toggleAction(item.id);
                    Navigator.pop(context);
                  },
                  icon: Icon(item.isCompleted ? Icons.undo : Icons.check_circle, size: 18.0),
                  label: Text(
                    item.isCompleted ? 'Mark as Pending' : 'Mark Task Completed',
                    style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: item.isCompleted ? const Color(0xFF64748B) : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRisingStarCard(BuildContext context, RisingStarPlayer player) {
    return Container(
      width: 270.0,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2010B981),
            blurRadius: 12.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                child: Text(
                  player.firstName.isNotEmpty ? player.firstName[0] : 'S',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${player.firstName} ${player.lastName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14.0),
                    ),
                    Text(
                      '${player.position} • ${player.ageGroup}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.0, color: Color(0xFFA7F3D0)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_fire_department, color: Color(0xFFFBBF24), size: 16.0),
                    SizedBox(width: 4.0),
                    Text(
                      'STREAK',
                      style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                  ],
                ),
                Text(
                  '${player.gymConsistencyWeeks} WKS CONSISTENT',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStarMetricPill('GRADES', '+${player.gradeImprovement}%', Icons.school),
              _buildStarMetricPill('ATTEND', '${player.attendancePercent}%', Icons.event_available),
              _buildStarMetricPill('GYM', '+${player.gymProgressPercent}%', Icons.fitness_center),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarMetricPill(String label, String val, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFA7F3D0), size: 14.0),
        const SizedBox(height: 2.0),
        Text(
          val,
          style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 8.5, color: Color(0xFFA7F3D0), fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, bool loading, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
              Icon(icon, color: const Color(0xFF64748B), size: 16.0),
            ],
          ),
          const SizedBox(height: 12.0),
          if (loading)
            const SizedBox(width: 20.0, height: 20.0, child: CircularProgressIndicator(strokeWidth: 2.0))
          else
            Text(
              value,
              style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 4.0),
            Text(subtitle, style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B))),
          ]
        ],
      ),
    );
  }

  Widget _buildFlagCarouselCard(BuildContext context, FlaggedPlayer player) {
    final bool isCritical = player.severity.toLowerCase() == 'critical';
    final List<Color> bgGradient = isCritical
        ? [const Color(0xFF881337), const Color(0xFF9F1239)]
        : [const Color(0xFF78350F), const Color(0xFF92400E)];

    return Container(
      width: 300.0,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: isCritical ? const Color(0x259F1239) : const Color(0x2592400E),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                child: Text(
                  player.firstName.isNotEmpty ? player.firstName[0] : 'P',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${player.firstName} ${player.lastName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14.0),
                    ),
                    Text(
                      '${player.position} • Squad: ${player.ageGroup}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.0, color: Color(0xFFFECDD3)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  player.severity.toUpperCase(),
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                player.flagReason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Colors.white, height: 1.3),
              ),
            ),
          ),
          const SizedBox(height: 10.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                CreateActionModal.show(
                  context,
                  playerId: player.id,
                  playerName: '${player.firstName} ${player.lastName}',
                );
              },
              icon: const Icon(Icons.assignment_add, size: 16.0),
              label: const Text(
                'Set Action Plan',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: isCritical ? const Color(0xFF881337) : const Color(0xFF78350F),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, {required int activeIndex}) {
    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0, top: 4.0),
        child: Container(
            height: 64.0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20.0,
                  spreadRadius: 1.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32.0),
              child: BottomNavigationBar(
                currentIndex: activeIndex,
                onTap: (index) {
                  ref.read(dashboardTabProvider.notifier).state = index;
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                elevation: 0,
                selectedItemColor: const Color(0xFF003EC7),
                unselectedItemColor: const Color(0xFF64748B),
                selectedLabelStyle: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 11.0),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
                  BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), activeIcon: Icon(Icons.people_alt), label: 'Athletes'),
                  BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner_outlined), activeIcon: Icon(Icons.qr_code_scanner), label: 'Check-In'),
                  BottomNavigationBarItem(icon: Icon(Icons.sports_score_outlined), activeIcon: Icon(Icons.sports_score), label: 'Events'),
                  BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
                ],
              ),
            ),
          ),
        ),
      );
    }
}
