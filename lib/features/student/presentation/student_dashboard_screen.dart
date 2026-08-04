import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/country_code_picker.dart';
import '../controllers/student_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../../auth/presentation/login_screen.dart';

import '../../dashboard/controllers/dashboard_controller.dart';
import '../../notifications/controllers/notification_controller.dart';
import '../../notifications/presentation/notifications_panel.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends ConsumerState<StudentDashboardScreen> {
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(studentControllerProvider.notifier).fetchStudentData();
      ref.read(notificationProvider.notifier).fetchNotifications();
    });
  }

  void _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
        content: const Text(
          'Are you sure you want to permanently delete your account and all associated profile data? This action cannot be undone.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final authState = ref.read(authProvider);
              final email = authState.email ?? authState.userProfile?['email'] ?? '';
              final userId = authState.userProfile?['id']?.toString() ?? '';
              try {
                final apiClient = ref.read(apiClientProvider);
                await apiClient.post('/api/user/delete-account', data: {
                  'email': email,
                  'userId': userId,
                });
              } catch (e) {
                debugPrint('[Account Deletion Error] $e');
              }
              await ref.read(authProvider.notifier).logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentDataState = ref.watch(studentControllerProvider);
    final userProfile = ref.watch(authProvider).userProfile;
    final notifState = ref.watch(notificationProvider);
    final studentName = userProfile != null
        ? '${userProfile['firstName']} ${userProfile['lastName']}'
        : 'Student';

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16.0,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _activeTab = 4),
              child: Container(
                width: 36.0,
                height: 36.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2), width: 1.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18.0),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=150',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return CircleAvatar(
                        backgroundColor: const Color(0xFF2563EB),
                        child: Text(
                          studentName.isNotEmpty ? studentName[0] : 'S',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10.0),
            GestureDetector(
              onTap: () => setState(() => _activeTab = 4),
              child: const Text(
                'AcademyPro',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.bold,
                  fontSize: 20.0,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF2563EB), size: 26.0),
            tooltip: 'My Digital Pass',
            onPressed: () {
              if (studentDataState.value != null) {
                _showQRCodeModal(context, studentDataState.value!);
              }
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF64748B)),
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
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Color(0xFF64748B)),
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(studentControllerProvider.notifier).fetchStudentData();
        },
        child: studentDataState.when(
          data: (data) => _buildContent(data),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48.0, color: Color(0xFFBA1A1A)),
                  const SizedBox(height: 12.0),
                  Text(
                    'Error loading dashboard:\n${err.toString().replaceAll(RegExp(r'^DioException \[.*?\]:\s*'), '')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold, fontSize: 14.0),
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: () => ref.read(studentControllerProvider.notifier).fetchStudentData(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(StudentPortalData data) {
    if (_activeTab == 1) {
      return _buildEventsTab(data);
    } else if (_activeTab == 2) {
      return _buildStatsTab(data);
    } else if (_activeTab == 3) {
      return _buildFeedbackTab(data);
    } else if (_activeTab == 4) {
      return _buildProfileTab(data);
    }
    return _buildOverviewTab(data);
  }

  Widget _buildSquadSelectorBar(StudentPortalData data) {
    if (data.assignedSquads.isEmpty) return const SizedBox.shrink();

    final selectedSquadId = ref.watch(selectedStudentSquadIdProvider) ?? data.assignedSquads.first.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF2563EB),
              size: 18.0,
            ),
          ),
          const SizedBox(width: 10.0),
          const Text(
            'Active Squad:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: data.assignedSquads.any((s) => s.id == selectedSquadId) ? selectedSquadId : data.assignedSquads.first.id,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB)),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
                items: data.assignedSquads.map((squad) {
                  return DropdownMenuItem<String>(
                    value: squad.id,
                    child: Text(
                      '${squad.name} (${squad.code})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (newSquadId) {
                  if (newSquadId != null && newSquadId != selectedSquadId) {
                    ref.read(selectedStudentSquadIdProvider.notifier).state = newSquadId;
                    ref.read(studentControllerProvider.notifier).fetchStudentData(squadId: newSquadId);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: OVERVIEW (Student Journey)
  // ==========================================
  Widget _buildOverviewTab(StudentPortalData data) {
    final profile = data.profile;
    final studentName = '${profile['firstName'] ?? 'Athlete'} ${profile['lastName'] ?? ''}'.trim();
    final team = profile['team'] ?? 'First Team';
    final ageGroup = profile['ageGroup'] ?? 'U15';
    final position = profile['position'] ?? 'Player';

    // Athlete Readiness Score
    final readinessScore = data.readinessScore;

    // Compute Latest Grade
    final latestGrade = _getLatestGrade(data.academics);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 140.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSquadSelectorBar(data),
          // Hero Status Card
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: const Color(0xFFC3C5D9).withValues(alpha: 0.3), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF05B046).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: const Text(
                        'ZONE ACTIVE',
                        style: TextStyle(
                          color: Color(0xFF003A11),
                          fontSize: 10.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    if (readinessScore > 0) ...[
                      const SizedBox(width: 8.0),
                      Text(
                        '${readinessScore.toStringAsFixed(0)}TH PERCENTILE',
                        style: const TextStyle(
                          color: Color(0xFF434656),
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16.0),
                Text(
                  readinessScore > 0 ? 'Active Evaluation' : 'Pending Evaluation',
                  style: const TextStyle(
                    fontSize: 28.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF131B2E),
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  readinessScore > 0
                      ? '$studentName is currently tracking in the $ageGroup $team squad as a $position.'
                      : '$studentName is registered as a $position in the $ageGroup $team squad. Log baseline test scores to unlock performance insights.',
                  style: TextStyle(
                    fontSize: 15.0,
                    color: const Color(0xFF434656).withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24.0),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CURRENT RANK',
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF434656),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          (data.academics.isNotEmpty && latestGrade > 0)
                              ? (latestGrade >= 85 ? 'A+' : (latestGrade >= 75 ? 'A' : (latestGrade >= 65 ? 'B+' : (latestGrade >= 55 ? 'B' : (latestGrade >= 45 ? 'C' : 'D')))))
                              : '--',
                          style: const TextStyle(
                            fontSize: 36.0,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF05B046),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 32.0),
                    Container(
                      width: 1.5,
                      height: 40.0,
                      color: const Color(0xFFC3C5D9).withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 32.0),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RECRUIT READINESS',
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF434656),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          readinessScore > 0
                              ? '${readinessScore.toStringAsFixed(0)}%'
                              : '--',
                          style: const TextStyle(
                            fontSize: 28.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF131B2E),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24.0),

          // Next Event Countdown Hero Card
          _buildNextEventHeroWidget(data),
          const SizedBox(height: 28.0),

          // Mind, Body, Spirit Portals Grid
          const Text(
            'Development Portals',
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: Color(0xFF131B2E),
            ),
          ),
          const SizedBox(height: 16.0),
          _buildPortalCard(
            'Mind',
            'Academic performance and cognitive load metrics.',
            latestGrade > 0 ? 'Term Avg: ${latestGrade.toStringAsFixed(1)}%' : 'No grades recorded',
            Icons.psychology,
            const Color(0xFF003EC7),
            () => setState(() {
              _activeTab = 2;
              _selectedStatsFilter = 2; // Academics in Stats Page
            }),
          ),
          const SizedBox(height: 12.0),
          _buildPortalCard(
            'Body',
            'Athletic progression and dynamic test metrics.',
            readinessScore > 0 ? 'Readiness: $readinessScore%' : 'No tests logged',
            Icons.sports_martial_arts,
            const Color(0xFF05B046),
            () => setState(() {
              _activeTab = 2;
              _selectedStatsFilter = 1; // Fitness & Tests in Stats Page
            }),
          ),
          const SizedBox(height: 28.0),

          // Assigned Coach Action Plans / To-Do
          _buildCoachActionPlansForStudent(studentName),

          // Peace of Mind Coach Feed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Latest Feedback',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF131B2E),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _activeTab = 3),
                icon: const Icon(Icons.arrow_forward, size: 14.0, color: Color(0xFF2563EB)),
                label: const Text('View All', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          InkWell(
            onTap: () => setState(() => _activeTab = 3),
            borderRadius: BorderRadius.circular(20.0),
            child: _buildCoachFeedbackCard(data),
          ),
          const SizedBox(height: 32.0),
        ],
      ),
    );
  }

  Widget _buildNextEventHeroWidget(StudentPortalData data) {
    if (data.events.isEmpty) return const SizedBox();

    final now = DateTime.now();
    StudentEvent? nextEvent;

    for (final event in data.events) {
      try {
        final parts = event.startTime.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final dateParts = event.date.split('-');
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        final eventTime = DateTime(year, month, day, hour, minute);

        if (eventTime.isAfter(now) || eventTime.add(Duration(minutes: event.durationMins ?? 90)).isAfter(now)) {
          nextEvent = event;
          break;
        }
      } catch (_) {}
    }

    nextEvent ??= data.events.first;

    final countdownText = _formatCountdown(nextEvent.date, nextEvent.startTime);
    final hasImage = nextEvent.workoutImagePath != null && nextEvent.workoutImagePath!.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEventDetailsModal(context, nextEvent!),
        borderRadius: BorderRadius.circular(24.0),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF003EC7).withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.timer, color: Color(0xFF60A5FA), size: 18.0),
                      SizedBox(width: 6.0),
                      Text(
                        'NEXT TEAM EVENT',
                        style: TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Text(
                      countdownText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14.0),
              Text(
                nextEvent.title,
                style: const TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10.0),
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFF94A3B8), size: 14.0),
                  const SizedBox(width: 6.0),
                  Text(
                    '${nextEvent.date} at ${nextEvent.startTime}',
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.0, fontWeight: FontWeight.w600),
                  ),
                  if (nextEvent.durationMins != null) ...[
                    const SizedBox(width: 12.0),
                    const Icon(Icons.timer_outlined, color: Color(0xFF94A3B8), size: 14.0),
                    const SizedBox(width: 4.0),
                    Text(
                      '${nextEvent.durationMins}m',
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.0),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 6.0),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: Color(0xFF94A3B8), size: 14.0),
                  const SizedBox(width: 6.0),
                  Expanded(
                    child: Text(
                      nextEvent.location,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.0),
                    ),
                  ),
                  const Row(
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(color: Color(0xFF60A5FA), fontSize: 12.0, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 4.0),
                      Icon(Icons.chevron_right, color: Color(0xFF60A5FA), size: 16.0),
                    ],
                  )
                ],
              ),
              if (hasImage) ...[
                const SizedBox(height: 16.0),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Image.network(
                        nextEvent.workoutImagePath!,
                        width: double.infinity,
                        height: 280.0,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        color: const Color(0xFF003EC7).withValues(alpha: 0.9),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.zoom_in, color: Colors.white, size: 18.0),
                            SizedBox(width: 6.0),
                            Text(
                              'View Coach Workout Plan',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  String _formatCountdown(String dateStr, String startTimeStr) {
    try {
      final now = DateTime.now();
      final parts = startTimeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dateParts = dateStr.split('-');
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      final eventTime = DateTime(year, month, day, hour, minute);
      final diff = eventTime.difference(now);

      if (diff.isNegative) {
        if (diff.inHours.abs() < 2) {
          return 'IN PROGRESS NOW';
        }
        return 'Completed';
      }

      if (diff.inMinutes < 60) {
        return 'Starting in ${diff.inMinutes} mins';
      } else if (diff.inHours < 24) {
        final hrs = diff.inHours;
        final mins = diff.inMinutes % 60;
        if (mins == 0) {
          return 'Starting in ${hrs}h';
        }
        return 'Starting in ${hrs}h ${mins}m';
      } else if (diff.inDays == 1) {
        return 'Starts tomorrow at $startTimeStr';
      } else {
        return 'Starting in ${diff.inDays} days';
      }
    } catch (_) {
      return '$dateStr at $startTimeStr';
    }
  }

  Widget _buildCoachActionPlansForStudent(String studentName) {
    final actions = ref.watch(coachActionProvider);
    final studentFirstName = studentName.split(' ')[0].toLowerCase();
    final studentActions = actions.where((a) =>
        a.playerName.toLowerCase().contains(studentFirstName) ||
        (a.playerName.isNotEmpty && studentName.toLowerCase().contains(a.playerName.toLowerCase()))).toList();

    if (studentActions.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF2563EB), size: 22.0),
                SizedBox(width: 8.0),
                Text(
                  'My Action Plans (From Coach)',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF131B2E),
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
                '${studentActions.where((a) => !a.isCompleted).length} PENDING',
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
        ...studentActions.map((item) {
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showActionItemDetailsModal(context, item);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                gradient: item.isCompleted
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: item.isCompleted ? Colors.white : null,
                borderRadius: BorderRadius.circular(18.0),
                border: item.isCompleted ? Border.all(color: const Color(0xFFE2E8F0)) : null,
                boxShadow: [
                  BoxShadow(
                    color: item.isCompleted ? const Color(0x08000000) : const Color(0x202563EB),
                    blurRadius: 10.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      ref.read(coachActionProvider.notifier).toggleAction(item.id);
                    },
                    child: Icon(
                      item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: item.isCompleted ? const Color(0xFF10B981) : Colors.white,
                      size: 24.0,
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            color: item.isCompleted ? const Color(0xFF64748B) : Colors.white,
                            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Assigned to ${item.playerName} • ${item.category}',
                          style: TextStyle(
                            fontSize: 11.0,
                            color: item.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFFBFDBFE),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 20.0),
      ],
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
              InkWell(
                onTap: () {
                  final cleanPhone = item.playerPhone.replaceAll(RegExp(r'[^\d+]'), '');
                  launchUrl(Uri.parse('tel:$cleanPhone'));
                },
                borderRadius: BorderRadius.circular(14.0),
                child: Container(
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
                      Text(
                        '${item.playerName}: ${item.playerPhone}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                          fontSize: 13.0,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildPortalCard(
    String title,
    String desc,
    String value,
    IconData icon,
    Color themeColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFFC3C5D9).withValues(alpha: 0.4), width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Icon(icon, color: themeColor, size: 28.0),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 12.0,
                      color: Color(0xFF434656),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 4.0),
                Icon(Icons.arrow_forward, color: themeColor, size: 16.0),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCoachFeedbackCard(StudentPortalData data) {
    final actions = ref.watch(coachActionProvider);
    final studentName = '${data.profile['firstName'] ?? ''} ${data.profile['lastName'] ?? ''}'.trim();
    final studentId = data.profile['id']?.toString() ?? '';
    final studentActions = actions.where((a) =>
        (studentId.isNotEmpty && a.playerId == studentId) ||
        (a.playerName.isNotEmpty && studentName.toLowerCase().contains(a.playerName.toLowerCase()))).toList();

    if (studentActions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        ),
        child: const Column(
          children: [
            Icon(Icons.rate_review_outlined, size: 36.0, color: Color(0xFF94A3B8)),
            SizedBox(height: 10.0),
            Text(
              'No Coach Feedback Logged Yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0, color: Color(0xFF0F172A)),
            ),
            SizedBox(height: 4.0),
            Text(
              'Evaluation notes and tactical guidance from your coaching staff will appear here as reviews are logged.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final latestAction = studentActions.first;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF003EC7),
                child: Icon(Icons.person, color: Colors.white, size: 16.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latestAction.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
                    ),
                    Text(
                      'Category: ${latestAction.category}',
                      style: const TextStyle(fontSize: 11.0, color: Color(0xFF434656)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (latestAction.notes.isNotEmpty) ...[
            const SizedBox(height: 12.0),
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                '"${latestAction.notes}"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF131B2E),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: COMBINED STATS & PERFORMANCE HUB
  // ==========================================
  int _selectedStatsFilter = 0; // 0: All, 1: Fitness & Tests, 2: Academics, 3: Match Logs

  Widget _buildStatsTab(StudentPortalData data) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 140.0),
      children: [
        const Text(
          'Stats & Performance Hub',
          style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
        ),
        const SizedBox(height: 4.0),
        const Text(
          'Unified athletic evaluation, academic scores, and match statistics.',
          style: TextStyle(fontSize: 13.0, color: Color(0xFF434656)),
        ),
        const SizedBox(height: 16.0),

        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatsPill('All Stats', 0),
              const SizedBox(width: 8.0),
              _buildStatsPill('Fitness & Tests', 1),
              const SizedBox(width: 8.0),
              _buildStatsPill('Academics', 2),
              const SizedBox(width: 8.0),
              _buildStatsPill('Match Logs', 3),
            ],
          ),
        ),
        const SizedBox(height: 20.0),

        // Fitness Section
        if (_selectedStatsFilter == 0 || _selectedStatsFilter == 1) ...[
          const Row(
            children: [
              Icon(Icons.fitness_center, color: Color(0xFF05B046), size: 20.0),
              SizedBox(width: 8.0),
              Text(
                'Fitness & Athletic Benchmarks',
                style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          _buildFitnessSectionContent(data),
          const SizedBox(height: 28.0),
        ],

        // Academics Section
        if (_selectedStatsFilter == 0 || _selectedStatsFilter == 2) ...[
          const Row(
            children: [
              Icon(Icons.school, color: Color(0xFF003EC7), size: 20.0),
              SizedBox(width: 8.0),
              Text(
                'Academic Performance',
                style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          _buildAcademicsSectionContent(data),
          const SizedBox(height: 28.0),
        ],

        // Match Logs Section
        if (_selectedStatsFilter == 0 || _selectedStatsFilter == 3) ...[
          const Row(
            children: [
              Icon(Icons.sports_score, color: Color(0xFFD97706), size: 20.0),
              SizedBox(width: 8.0),
              Text(
                'Match Logs & Auto-Scores',
                style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          _buildMatchesSectionContent(data),
        ],
      ],
    );
  }

  Widget _buildStatsPill(String label, int index) {
    final isSelected = _selectedStatsFilter == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedStatsFilter = index);
      },
      selectedColor: const Color(0xFF003EC7),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF475569),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        fontSize: 12.0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(color: isSelected ? const Color(0xFF003EC7) : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildFitnessSectionContent(StudentPortalData data) {
    if (data.dynamicMetrics.isEmpty) {
      return _buildEmptyState('No dynamic athletic test benchmarks recorded.');
    }

    return Column(
      children: data.dynamicMetrics.map((metric) {
        final baseline = metric.initialBaseline;
        final latest = metric.latestScore;
        final unit = metric.unit;
        final isLowerBetter = metric.goalDirection == 'LOWER_IS_BETTER';

        double percentChange = 0.0;
        if (baseline > 0) {
          if (isLowerBetter) {
            percentChange = ((baseline - latest) / baseline) * 100;
          } else {
            percentChange = ((latest - baseline) / baseline) * 100;
          }
        }

        final isImproved = percentChange >= 0;
        final changeString = isImproved
            ? '+${percentChange.toStringAsFixed(1)}%'
            : '${percentChange.toStringAsFixed(1)}%';

        return Card(
          margin: const EdgeInsets.only(bottom: 14.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        metric.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: isImproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isImproved ? Icons.trending_up : Icons.trending_down,
                            size: 14.0,
                            color: isImproved ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            changeString,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isImproved ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BASELINE', style: TextStyle(fontSize: 10.0, color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          const SizedBox(height: 4.0),
                          Text('$baseline $unit', style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('TARGET', style: TextStyle(fontSize: 10.0, color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          const SizedBox(height: 4.0),
                          Text('${metric.targetBenchmark} $unit', style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: Color(0xFF003EC7))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('LATEST SCORE', style: TextStyle(fontSize: 10.0, color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          const SizedBox(height: 4.0),
                          Text('$latest $unit', style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w900, color: Color(0xFF05B046))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: LinearProgressIndicator(
                    value: (metric.targetPercent / 100).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: const Color(0xFF05B046),
                    minHeight: 6.0,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAcademicsSectionContent(StudentPortalData data) {
    if (data.academics.isEmpty) {
      return _buildEmptyState('No academic report cards recorded.');
    }

    return Column(
      children: data.academics.map((acad) {
        final term = acad['term'] ?? 1;
        final grade = (acad['gradePercentage'] as num?)?.toDouble() ?? 0.0;

        Color cardBorderColor = const Color(0xFF16A34A);
        Color textBadgeColor = const Color(0xFF166534);
        Color badgeBg = const Color(0xFFDCFCE7);
        String label = 'EXCELLENT';

        if (grade < AppConfig.academicWarningCutoff) {
          cardBorderColor = const Color(0xFFDC2626);
          textBadgeColor = const Color(0xFF991B1B);
          badgeBg = const Color(0xFFFEE2E2);
          label = 'CRITICAL';
        } else if (grade < AppConfig.academicPassCutoff) {
          cardBorderColor = const Color(0xFFD97706);
          textBadgeColor = const Color(0xFF92400E);
          badgeBg = const Color(0xFFFEF3C7);
          label = 'WARNING';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 10.0,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: cardBorderColor, width: 4.0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Term $term Report Card',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4.0),
                        const Text(
                          'Official Term Assessment',
                          style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${grade.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w900, color: cardBorderColor),
                        ),
                        const SizedBox(height: 2.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(color: textBadgeColor, fontSize: 9.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMatchesSectionContent(StudentPortalData data) {
    if (data.matches.isEmpty) {
      return _buildEmptyState('No match logs recorded.');
    }

    return Column(
      children: data.matches.map((match) {
        final opponent = match['opponent'] ?? 'Unknown Opponent';
        final date = match['matchDate'] ?? 'Unknown Date';
        final tackles = match['tacklesMade'] ?? 0;
        final carries = match['carries'] ?? 0;
        final autoScore = (match['autoScore'] as num?)?.toDouble() ?? 0.0;
        final category = match['category'] ?? '🟢 On Track';

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'vs. $opponent',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      date,
                      style: const TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10.0),
                    Row(
                      children: [
                        _buildMatchMetricChip('Tackles', '$tackles'),
                        const SizedBox(width: 8.0),
                        _buildMatchMetricChip('Carries', '$carries'),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$autoScore',
                      style: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.w900, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      category,
                      style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==========================================
  // TAB 3: COACH FEEDBACK HISTORY
  // ==========================================
  Widget _buildFeedbackTab(StudentPortalData data) {
    final actions = ref.watch(coachActionProvider);
    final studentName = '${data.profile['firstName'] ?? ''} ${data.profile['lastName'] ?? ''}'.trim();
    final studentId = data.profile['id']?.toString() ?? '';
    final studentActions = actions.where((a) =>
        (studentId.isNotEmpty && a.playerId == studentId) ||
        (a.playerName.isNotEmpty && studentName.toLowerCase().contains(a.playerName.toLowerCase()))).toList();

    if (studentActions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 140.0),
        children: const [
          Text(
            'Coach Feedback History',
            style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
          ),
          SizedBox(height: 4.0),
          Text(
            'All evaluation notes, performance guidance, and tactical advice from your coaches.',
            style: TextStyle(fontSize: 13.0, color: Color(0xFF434656)),
          ),
          SizedBox(height: 48.0),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rate_review_outlined, size: 56.0, color: Color(0xFF94A3B8)),
                SizedBox(height: 16.0),
                Text(
                  'No Feedback Notes Logged Yet',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 8.0),
                Text(
                  'Evaluation notes, performance guidance, and tactical advice from your coaching staff will appear here as reviews are logged.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.0, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 140.0),
      itemCount: studentActions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coach Feedback History',
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
              ),
              SizedBox(height: 4.0),
              Text(
                'All evaluation notes, performance guidance, and tactical advice from your coaches.',
                style: TextStyle(fontSize: 13.0, color: Color(0xFF434656)),
              ),
              SizedBox(height: 16.0),
            ],
          );
        }

        final action = studentActions[index - 1];

        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 20.0,
                      backgroundColor: Color(0xFF003EC7),
                      child: Icon(Icons.person, color: Colors.white, size: 20.0),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Assigned to ${action.playerName.isNotEmpty ? action.playerName : studentName}',
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
                        action.category.toUpperCase(),
                        style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                  ],
                ),
                if (action.notes.isNotEmpty) ...[
                  const SizedBox(height: 12.0),
                  Text(
                    action.notes,
                    style: const TextStyle(fontSize: 14.0, color: Color(0xFF334155), height: 1.4),
                  ),
                ],
                const SizedBox(height: 10.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.access_time, size: 12.0, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4.0),
                    Text(
                      action.dateAdded,
                      style: const TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 4: EDIT ATHLETE PROFILE & DIGITAL PASS
  // ==========================================
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _preferredPositionController = TextEditingController();
  bool _isSavingProfile = false;
  String _selectedCountryCode = '+27';
  String _selectedFlag = '🇿🇦';

  Widget _buildProfileTab(StudentPortalData data) {
    final profile = data.profile;

    if (_firstNameController.text.isEmpty && (profile['firstName'] != null || profile['name'] != null)) {
      _firstNameController.text = profile['firstName'] ?? profile['name']?.split(' ')[0] ?? '';
      _lastNameController.text = profile['lastName'] ?? (profile['name']?.split(' ')?.skip(1)?.join(' ') ?? '');
      _phoneController.text = profile['phone'] ?? '';
      _dobController.text = profile['dob'] ?? '';
      _preferredPositionController.text = profile['preferredPosition'] ?? '';
    }

    if (_dobController.text.isEmpty && profile['dob'] != null && profile['dob'].toString().isNotEmpty) {
      _dobController.text = profile['dob'].toString();
    }

    final officialTeam = profile['team'] != null && profile['team'].toString().isNotEmpty ? profile['team'] : 'Unassigned';
    final officialAgeGroup = profile['ageGroup'] != null && profile['ageGroup'].toString().isNotEmpty ? profile['ageGroup'] : 'U15';
    final officialPosition = profile['position'] != null && profile['position'].toString().isNotEmpty ? profile['position'] : 'Athlete';

    final profileImage = profile['profileImagePath'] ?? profile['avatarUrl'] ?? '';
    final studentFullName = (profile['firstName'] != null || profile['lastName'] != null)
        ? '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim()
        : '--';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 140.0),
      children: [
        // Profile Picture Avatar & Header
        Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 36.0,
                  backgroundColor: const Color(0xFF003EC7),
                  backgroundImage: profileImage.isNotEmpty ? NetworkImage(profileImage) : null,
                  child: profileImage.isEmpty
                      ? Text(
                          studentFullName.isNotEmpty ? studentFullName[0].toUpperCase() : 'A',
                          style: const TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: Colors.white),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () => _showUpdateAvatarDialog(context, profileImage),
                    child: Container(
                      padding: const EdgeInsets.all(6.0),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 14.0),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentFullName,
                    style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    'Athlete Profile • ${profile['id'] ?? '--'}',
                    style: const TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4.0),
                  GestureDetector(
                    onTap: () => _showUpdateAvatarDialog(context, profileImage),
                    child: const Text(
                      'Tap avatar to change profile photo',
                      style: TextStyle(fontSize: 11.0, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20.0),

        // Official Squad & Position Badges (Read-Only, Managed by Coaches)
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16.0, color: Color(0xFF003EC7)),
                  SizedBox(width: 8.0),
                  Text(
                    'OFFICIAL COACH ALLOCATIONS',
                    style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Color(0xFF003EC7), letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: _buildReadOnlyInfoTile('Squad Team', officialTeam),
                  ),
                  Expanded(
                    child: _buildReadOnlyInfoTile('Age Group', officialAgeGroup),
                  ),
                  Expanded(
                    child: _buildReadOnlyInfoTile('Field Position', officialPosition),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              const Text(
                'Squad assignments, age groups, and official positions are managed by coaching staff.',
                style: TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20.0),

        // Digital Pass Banner
        GestureDetector(
          onTap: () => _showQRCodeModal(context, data),
          child: Container(
            padding: const EdgeInsets.all(18.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF003EC7), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF003EC7).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 36.0),
                ),
                const SizedBox(width: 14.0),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Digital Athlete ID & QR Pass',
                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 4.0),
                      Text(
                        'Tap to present scannable pass for gym & event check-ins.',
                        style: TextStyle(fontSize: 12.0, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white, size: 24.0),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24.0),

        // Personal Information Form (First Name, Last Name, Phone, Email, DOB, Preferred Position)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Personal Information',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16.0),

                // First Name
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14.0),

                // Last Name
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14.0),

                // Phone Number with Country Code Picker (uRun style)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile Phone Number',
                    hintText: '82 123 4567',
                    border: const OutlineInputBorder(),
                    prefixIcon: InkWell(
                      onTap: () {
                        CountryCodePicker.show(
                          context,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCountryCode = selected.dialCode;
                              _selectedFlag = selected.flag;
                            });
                          },
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_selectedFlag, style: const TextStyle(fontSize: 18.0)),
                            const SizedBox(width: 4.0),
                            Text(_selectedCountryCode, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13.5)),
                            const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 20.0),
                            Container(height: 20.0, width: 1.0, color: const Color(0xFFCBD5E1), margin: const EdgeInsets.only(left: 6.0, right: 4.0)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14.0),

                // Date of Birth (DOB) - Fast Dropdown/Direct Picker
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: () => _showFastDOBPicker(context),
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth (Fast Year/Month Selection)',
                    hintText: 'Tap to select Year & Birth Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cake_outlined),
                    suffixIcon: Icon(Icons.tune_outlined),
                  ),
                ),
                const SizedBox(height: 14.0),

                // Preferred Position (Optional Preference for Coaches)
                TextFormField(
                  controller: _preferredPositionController,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Playing Position (Optional Preference)',
                    hintText: 'e.g. Flyhalf / Winger (Coach Preference)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sports_outlined),
                  ),
                ),
                const SizedBox(height: 6.0),
                const Text(
                  'Your preferred position is visible to coaches to indicate your interest, but official position allocations are set by coaches.',
                  style: TextStyle(fontSize: 11.0, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20.0),

                ElevatedButton.icon(
                  onPressed: _isSavingProfile
                      ? null
                      : () async {
                          setState(() => _isSavingProfile = true);
                          try {
                            String rawPhone = _phoneController.text.trim();
                            String fullPhone = rawPhone;
                            if (rawPhone.isNotEmpty) {
                              String digits = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
                              if (digits.startsWith('0')) digits = digits.substring(1);
                              fullPhone = '$_selectedCountryCode $digits'.trim();
                            }

                            final apiClient = ref.read(apiClientProvider);
                            final res = await apiClient.post('/api/student-portal/profile', data: {
                              'firstName': _firstNameController.text.trim(),
                              'lastName': _lastNameController.text.trim(),
                              'phone': fullPhone,
                              'dob': _dobController.text.trim(),
                              'preferredPosition': _preferredPositionController.text.trim(),
                            });
                            if (res.data['success'] == true) {
                              await ref.read(studentControllerProvider.notifier).fetchStudentData();
                              if (mounted) {
                                AppToast.showSuccess(context, title: 'Profile Updated', message: 'Your personal information was saved successfully.');
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              AppToast.showError(context, title: 'Update Failed', message: 'Unable to save profile changes. Please check your connection and try again.');
                            }
                          } finally {
                            if (mounted) setState(() => _isSavingProfile = false);
                          }
                        },
                  icon: _isSavingProfile
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSavingProfile ? 'Saving Changes...' : 'Save Profile Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003EC7),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20.0),

        OutlinedButton.icon(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout_outlined, color: Color(0xFFDC2626)),
          label: const Text('Sign Out of Account', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: Color(0xFFFCA5A5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          ),
        ),
        const SizedBox(height: 12.0),

        TextButton.icon(
          onPressed: _handleDeleteAccount,
          icon: const Icon(Icons.delete_forever, size: 18.0, color: Color(0xFFDC2626)),
          label: const Text('Delete Account', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildReadOnlyInfoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 2.0),
        Text(
          value,
          style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showFastDOBPicker(BuildContext context) {
    int selectedYear = 2008;
    int selectedMonth = 1;
    int selectedDay = 1;

    if (_dobController.text.trim().isNotEmpty) {
      try {
        final parts = _dobController.text.trim().split('-');
        if (parts.length == 3) {
          selectedYear = int.parse(parts[0]);
          selectedMonth = int.parse(parts[1]);
          selectedDay = int.parse(parts[2]);
        }
      } catch (_) {}
    }

    final years = List<int>.generate(35, (i) => 2024 - i);
    final months = [
      'Jan (01)', 'Feb (02)', 'Mar (03)', 'Apr (04)',
      'May (05)', 'Jun (06)', 'Jul (07)', 'Aug (08)',
      'Sep (09)', 'Oct (10)', 'Nov (11)', 'Dec (12)'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
              actionsPadding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0, top: 12.0),
              title: const Row(
                children: [
                  Icon(Icons.cake, color: Color(0xFF003EC7)),
                  SizedBox(width: 10.0),
                  Text('Select Date of Birth', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select birth Year, Month, and Day directly:',
                    style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      // Year Dropdown
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('YEAR', style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 4.0),
                            DropdownButtonFormField<int>(
                              initialValue: selectedYear,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                              items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                              onChanged: (val) => setModalState(() => selectedYear = val!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      // Month Dropdown
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MONTH', style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 4.0),
                            DropdownButtonFormField<int>(
                              initialValue: selectedMonth,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
                              items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i].split(' ')[0]))).toList(),
                              onChanged: (val) => setModalState(() => selectedMonth = val!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      // Day Dropdown
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DAY', style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 4.0),
                            DropdownButtonFormField<int>(
                              initialValue: selectedDay,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
                              items: List.generate(31, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))).toList(),
                              onChanged: (val) => setModalState(() => selectedDay = val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    foregroundColor: const Color(0xFF64748B),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003EC7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final monthStr = selectedMonth.toString().padLeft(2, '0');
                    final dayStr = selectedDay.toString().padLeft(2, '0');
                    _dobController.text = '$selectedYear-$monthStr-$dayStr';
                    Navigator.pop(context);
                  },
                  child: const Text('Confirm Date', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUpdateAvatarDialog(BuildContext context, String currentUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 20.0,
            bottom: 24.0 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              const Text(
                'Update Profile Picture',
                style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4.0),
              const Text(
                'Take a new photo or select an existing picture from your device gallery:',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20.0),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF2563EB), size: 24.0),
                ),
                title: const Text('Take a Photo (Camera)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                subtitle: const Text('Capture photo directly with your camera', style: TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12.0),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: Color(0xFF059669), size: 24.0),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                subtitle: const Text('Select image file from device photo gallery', style: TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile == null) return;

      if (mounted) {
        AppToast.showInfo(context, title: 'Uploading Photo...', message: 'Saving profile photo to server.');
      }

      final bytes = await pickedFile.readAsBytes();
      final base64Img = base64Encode(bytes);

      final apiClient = ref.read(apiClientProvider);
      final uploadRes = await apiClient.dio.post('/api/upload', data: {
        'imageBase64': base64Img,
        'filename': 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      });

      final uploadedUrl = uploadRes.data['url'];

      await apiClient.dio.post('/api/student-portal/profile', data: {
        'profileImagePath': uploadedUrl,
      });

      await ref.read(studentControllerProvider.notifier).fetchStudentData();

      if (mounted) {
        AppToast.showSuccess(context, title: 'Profile Photo Updated', message: 'Your photo was saved successfully.');
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, title: 'Upload Failed', message: 'Unable to save profile photo.');
      }
    }
  }

  void _showQRCodeModal(BuildContext context, StudentPortalData data) {
    final profile = data.profile;
    final studentName = (profile['firstName'] != null || profile['lastName'] != null)
        ? '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim()
        : '--';
    final studentId = profile['id'] ?? '--';
    final ageGroup = profile['ageGroup'] ?? 'U15';
    final position = profile['position'] ?? 'Flyhalf';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Digital Athlete Pass',
                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 2.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Image.network(
                      'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=$studentId',
                      width: 200.0,
                      height: 200.0,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        width: 200,
                        height: 200,
                        color: const Color(0xFFF1F5F9),
                        alignment: Alignment.center,
                        child: const Icon(Icons.qr_code_2, size: 120, color: Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      studentId,
                      style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Color(0xFF003EC7), letterSpacing: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                studentName,
                style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4.0),
              Text(
                'Hoërskool Overkruin • $position ($ageGroup)',
                style: const TextStyle(fontSize: 13.0, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_outlined, color: Color(0xFF059669), size: 14.0),
                    SizedBox(width: 6.0),
                    Text(
                      'Saved Offline — Valid Scan Without Data',
                      style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003EC7),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
                child: const Text('Close QR Pass', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchMetricChip(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        '$label: $val',
        style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
      ),
    );
  }

  // ==========================================
  // HELPERS & WIDGET UTILS
  // ==========================================



  Widget _buildEmptyState(String msg) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 40.0, color: Color(0xFF64748B)),
            const SizedBox(height: 12.0),
            Text(
              msg,
              style: const TextStyle(fontSize: 14.0, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  double _getLatestGrade(List<dynamic> academics) {
    if (academics.isEmpty) return 0.0;
    final last = academics.last;
    if (last is Map) {
      final val = last['gradeAverage'] ?? last['gradePercentage'] ?? last['grade'];
      if (val != null && val is num) {
        return val.toDouble();
      }
    }
    return 0.0;
  }



  // ==========================================
  // TAB 5: TEAM EVENTS & SCHEDULE
  // =================================  // ==========================================
  // TAB 5: TEAM EVENTS & SCHEDULE
  // ==========================================
  Widget _buildEventsTab(StudentPortalData data) {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    // Filter out completed / past events
    final activeEvents = data.events.where((e) {
      if (e.date.trim().isEmpty) return true;
      return e.date.compareTo(todayStr) >= 0;
    }).toList();

    if (activeEvents.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 140.0),
        children: [
          _buildEmptyState('No upcoming team sessions or events scheduled.'),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 140.0),
      itemCount: activeEvents.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Team Events & Schedule',
                style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
              ),
              SizedBox(height: 4.0),
              Text(
                'Upcoming training sessions, match days, and coach workout plans.',
                style: TextStyle(fontSize: 13.0, color: Color(0xFF434656)),
              ),
              SizedBox(height: 16.0),
            ],
          );
        }

        final event = activeEvents[index - 1];
        final hasImage = event.workoutImagePath != null && event.workoutImagePath!.trim().isNotEmpty;
        final countdown = _formatCountdown(event.date, event.startTime);
        final themeMap = _getEventTypeTheme(event.eventType);

        final Color accentColor = themeMap['accent'];
        final Color badgeBg = themeMap['badgeBg'];
        final Color badgeText = themeMap['badgeText'];
        final IconData typeIcon = themeMap['icon'];
        final String typeLabel = themeMap['label'];

        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 12.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accentColor, width: 5.0)),
              ),
              child: InkWell(
                onTap: () => _showEventDetailsModal(context, event),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(typeIcon, size: 13.0, color: badgeText),
                                const SizedBox(width: 5.0),
                                Text(
                                  typeLabel,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: badgeText,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            child: Text(
                              countdown,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),
                      Text(
                        event.title,
                        style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14.0, color: Color(0xFF64748B)),
                          const SizedBox(width: 6.0),
                          Text(
                            '${event.date} at ${event.startTime}',
                            style: const TextStyle(fontSize: 13.0, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                          ),
                          if (event.durationMins != null) ...[
                            const SizedBox(width: 12.0),
                            const Icon(Icons.timer_outlined, size: 14.0, color: Color(0xFF64748B)),
                            const SizedBox(width: 4.0),
                            Text(
                              '${event.durationMins} mins',
                              style: const TextStyle(fontSize: 13.0, color: Color(0xFF475569)),
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14.0, color: Color(0xFF64748B)),
                          const SizedBox(width: 6.0),
                          Expanded(
                            child: Text(
                              event.location,
                              style: const TextStyle(fontSize: 13.0, color: Color(0xFF475569)),
                            ),
                          ),
                          const Row(
                            children: [
                              Text('Details', style: TextStyle(fontSize: 12.0, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                              SizedBox(width: 2.0),
                              Icon(Icons.chevron_right, size: 16.0, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ],
                      ),
                      if (hasImage) ...[
                        const SizedBox(height: 16.0),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Image.network(
                                event.workoutImagePath!,
                                width: double.infinity,
                                height: 280.0,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  height: 100.0,
                                  color: const Color(0xFFF1F5F9),
                                  alignment: Alignment.center,
                                  child: const Text('Workout image preview unavailable', style: TextStyle(color: Color(0xFF64748B))),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                color: const Color(0xFF003EC7).withValues(alpha: 0.9),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.zoom_in, color: Colors.white, size: 18.0),
                                    SizedBox(width: 6.0),
                                    Text(
                                      'View Coach Workout Plan',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.0),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _getEventTypeTheme(String eventType) {
    final lower = eventType.toLowerCase();
    if (lower.contains('match')) {
      return {
        'accent': const Color(0xFFDC2626), // Crimson Red
        'badgeBg': const Color(0xFFFEF2F2),
        'badgeText': const Color(0xFF991B1B),
        'icon': Icons.sports,
        'label': 'MATCH DAY',
      };
    } else if (lower.contains('gym') || lower.contains('strength')) {
      return {
        'accent': const Color(0xFF2563EB), // Electric Blue
        'badgeBg': const Color(0xFFEFF6FF),
        'badgeText': const Color(0xFF1D4ED8),
        'icon': Icons.fitness_center,
        'label': 'GYM SESSION',
      };
    } else if (lower.contains('academic') || lower.contains('study') || lower.contains('exam')) {
      return {
        'accent': const Color(0xFF4F46E5), // Indigo
        'badgeBg': const Color(0xFFEEF2FF),
        'badgeText': const Color(0xFF3730A3),
        'icon': Icons.school_outlined,
        'label': 'ACADEMIC SESSION',
      };
    } else {
      // Practice / Training
      return {
        'accent': const Color(0xFF059669), // Emerald Green
        'badgeBg': const Color(0xFFECFDF5),
        'badgeText': const Color(0xFF065F46),
        'icon': Icons.sports,
        'label': eventType.toUpperCase(),
      };
    }
  }

  void _showEventDetailsModal(BuildContext context, StudentEvent event) {
    final hasImage = event.workoutImagePath != null && event.workoutImagePath!.trim().isNotEmpty;
    final countdown = _formatCountdown(event.date, event.startTime);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          bottom: true,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
                              decoration: BoxDecoration(
                                color: event.eventType == 'Match Day'
                                    ? const Color(0xFFFEE2E2)
                                    : event.eventType == 'Gym Session'
                                        ? const Color(0xFFEFF6FF)
                                        : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Text(
                                event.eventType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.bold,
                                  color: event.eventType == 'Match Day'
                                      ? const Color(0xFF991B1B)
                                      : event.eventType == 'Gym Session'
                                          ? const Color(0xFF1D4ED8)
                                          : const Color(0xFF166534),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              child: Text(
                                countdown,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 24.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _buildEventDetailRow(Icons.calendar_month, 'Date & Time', '${event.date} at ${event.startTime}'),
                              const Divider(height: 20.0, color: Color(0xFFE2E8F0)),
                              _buildEventDetailRow(Icons.location_on_outlined, 'Location', event.location),
                              if (event.durationMins != null) ...[
                                const Divider(height: 20.0, color: Color(0xFFE2E8F0)),
                                _buildEventDetailRow(Icons.timer_outlined, 'Duration', '${event.durationMins} minutes'),
                              ],
                              const Divider(height: 20.0, color: Color(0xFFE2E8F0)),
                              _buildEventDetailRow(Icons.groups_outlined, 'Team Assignment', '${event.ageGroup} ${event.team}'),
                            ],
                          ),
                        ),
                        if (hasImage) ...[
                          const SizedBox(height: 20.0),
                          const Text(
                            'Coach Workout Plan',
                            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 10.0),
                          GestureDetector(
                            onTap: () => _showFullImageModal(context, event.workoutImagePath!, event.title),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16.0),
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Image.network(
                                    event.workoutImagePath!,
                                    width: double.infinity,
                                    height: 320.0,
                                    fit: BoxFit.cover,
                                  ),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                                    color: const Color(0xFF003EC7).withValues(alpha: 0.9),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.zoom_in, color: Colors.white, size: 20.0),
                                        SizedBox(width: 8.0),
                                        Text(
                                          'Tap to Expand Full Resolution Plan',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Solid Pinned Bottom Action Container above Safe Area
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                  ),
                  padding: EdgeInsets.fromLTRB(20.0, 12.0, 20.0, MediaQuery.of(context).padding.bottom + 16.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (hasImage) {
                        _showFullImageModal(context, event.workoutImagePath!, event.title);
                      }
                    },
                    icon: Icon(hasImage ? Icons.zoom_in : Icons.check_circle_outline, size: 20.0),
                    label: Text(hasImage ? 'Open Full Resolution Workout Plan' : 'Close Event Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003EC7),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 20.0),
        const SizedBox(width: 12.0),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            const SizedBox(height: 2.0),
            Text(value, style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ],
        ),
      ],
    );
  }

  void _showFullImageModal(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28.0),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20.0),
                  minScale: 1.0,
                  maxScale: 6.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
                    },
                    errorBuilder: (_, _, _) => const Center(
                      child: Text('Failed to load workout plan image.', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 24.0,
                left: 20.0,
                right: 20.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.zoom_in, color: Color(0xFF60A5FA), size: 18.0),
                      SizedBox(width: 8.0),
                      Text(
                        'Pinch to Zoom & Pan Workout Details',
                        style: TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w600),
                      ),
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


  Widget _buildBottomNav() {
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
                currentIndex: _activeTab,
                onTap: (index) {
                  setState(() {
                    _activeTab = index;
                  });
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                elevation: 0,
                selectedItemColor: const Color(0xFF003EC7),
                unselectedItemColor: const Color(0xFF64748B),
                selectedLabelStyle: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 10.0),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Overview'),
                  BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Events'),
                  BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: 'Stats'),
                  BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Feedback'),
                  BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
                ],
              ),
            ),
          ),
        ),
      );
    }
}
