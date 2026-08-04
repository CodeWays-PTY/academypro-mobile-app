import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/network/api_client.dart';
import '../../student/controllers/student_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../../auth/presentation/login_screen.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

import '../../notifications/controllers/notification_controller.dart';
import '../../notifications/presentation/notifications_panel.dart';

class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
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

  void _showLinkChildModal(BuildContext context) {
    final emailCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0 + MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.family_restroom, color: Color(0xFF003EC7), size: 24),
                      SizedBox(width: 10),
                      Text('Link Child / Athlete Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Enter your child\'s email address. An in-app link approval request will be sent to their athlete profile.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'e.g. child@academypro.co.za',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: submitting ? null : () async {
                            if (emailCtrl.text.trim().isEmpty) return;
                            setModalState(() => submitting = true);
                            try {
                              final apiClient = ref.read(apiClientProvider);
                              await apiClient.post('/api/parent/link-request', data: {'childEmail': emailCtrl.text.trim()});
                              if (!mounted) return;
                              Navigator.pop(this.context);
                              AppToast.showSuccess(
                                this.context,
                                title: 'Link Request Dispatched',
                                message: 'Parent link request sent to ${emailCtrl.text.trim()}. Pending athlete approval.',
                              );
                            } catch (e) {
                              setModalState(() => submitting = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003EC7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: submitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Send Link Request', style: TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final studentDataState = ref.watch(studentControllerProvider);
    final userProfile = ref.watch(authProvider).userProfile;
    final notifState = ref.watch(notificationProvider);
    final parentName = userProfile != null
        ? '${userProfile['firstName']} ${userProfile['lastName']}'
        : 'Parent';

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
            Container(
              width: 36.0,
              height: 36.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2), width: 1.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18.0),
                child: Image.network(
                  'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return CircleAvatar(
                      backgroundColor: const Color(0xFF2563EB),
                      child: Text(
                        parentName.isNotEmpty ? parentName[0] : 'P',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 10.0),
            const Text(
              'AcademyPro',
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.bold,
                fontSize: 20.0,
              ),
            ),
          ],
        ),
        actions: [
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
            icon: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF003EC7)),
            tooltip: 'Link Child Account',
            onPressed: () => _showLinkChildModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Color(0xFF64748B)),
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF003EC7),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        onPressed: () {
          AppToast.showInfo(context, title: 'Support Chat', message: 'Opening your support agent chat...');
        },
        child: const Icon(Icons.support_agent, size: 32.0),
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
      return _buildFitnessTab(data);
    } else if (_activeTab == 2) {
      return _buildAcademicsTab(data);
    } else if (_activeTab == 3) {
      return _buildMatchesTab(data);
    }
    return _buildOverviewTab(data);
  }

  // ==========================================
  // TAB 1: ELITE PERFORMANCE OVERVIEW
  // ==========================================
  Widget _buildOverviewTab(StudentPortalData data) {
    final profile = data.profile;
    final studentName = '${profile['firstName'] ?? 'Athlete'} ${profile['lastName'] ?? ''}'.trim();
    final team = profile['team'] ?? 'Elite Development';
    final ageGroup = profile['ageGroup'] ?? 'U15';

    // Compute Power Index
    int powerIndex = 0;
    final baseline = data.fitness['baseline'];
    if (baseline != null) {
      final pushUps = baseline['pushUps'] as num? ?? 0;
      final squats = baseline['squats40kg'] as num? ?? 0;
      final pullUps = baseline['pullUps'] as num? ?? 0;
      powerIndex = (pushUps * 5 + squats * 10 + pullUps * 15).toInt();
    }

    // Compute Latest Grade
    final latestGrade = _getLatestGrade(data.academics);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 100.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Status Section (Blue Gradient Card)
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32.0),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF003EC7),
                  Color(0xFF0052FF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF003EC7).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24.0,
                      height: 2.0,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      '${studentName.toUpperCase()}\'S PERFORMANCE HUB',
                      style: const TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                const Row(
                  children: [
                    Text(
                      'On Track',
                      style: TextStyle(
                        fontSize: 32.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8.0),
                    Icon(Icons.verified, color: Color(0xFF4ADE80), size: 32.0),
                  ],
                ),
                const SizedBox(height: 8.0),
                Text(
                  '$studentName is meeting all performance benchmarks for the $ageGroup $team squad.',
                  style: TextStyle(
                    fontSize: 15.0,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24.0),
                Row(
                  children: [
                    _buildGlassSubPanel(
                      'Squad Rank',
                      powerIndex > 0 ? '#$powerIndex' : '--',
                      powerIndex > 0 ? const Color(0xFF4ADE80) : Colors.white,
                    ),
                    const SizedBox(width: 16.0),
                    _buildGlassSubPanel(
                      'Consistency',
                      data.attendance.isNotEmpty ? '${data.attendance.length}%' : '--',
                      Colors.white,
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 28.0),

          // Priority Info Grid (Matches & Metrics)
          _buildPriorityInfoGrid(data, studentName, latestGrade, powerIndex),
          const SizedBox(height: 32.0),

          // Peace of Mind Feed Section
          const Text(
            'Peace of Mind',
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              color: Color(0xFF131B2E),
            ),
          ),
          const SizedBox(height: 16.0),
          _buildCoachQuoteCard(studentName),
          const SizedBox(height: 12.0),
          _buildCampusCheckoutCard(data, studentName),
        ],
      ),
    );
  }

  Widget _buildGlassSubPanel(String label, String value, Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 4.0,
            height: 28.0,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
          const SizedBox(width: 12.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 8.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPriorityInfoGrid(StudentPortalData data, String studentName, double latestGrade, int powerIndex) {
    final Map<String, dynamic>? match = data.matches.isNotEmpty
        ? (data.matches.first is Map<String, dynamic> ? data.matches.first as Map<String, dynamic> : null)
        : null;
    final matchDate = match?['date'] ?? match?['time'] ?? 'No Scheduled Match';
    final venue = match?['location'] ?? match?['venue'] ?? '--';
    final courtInfo = match?['opponent'] != null
        ? 'vs ${match!['opponent']} • ${match['court'] ?? match['jersey'] ?? 'Home Match'}'
        : (match?['details'] ?? '--');
    final matchStatus = match?['status'] ?? (match != null ? 'CONFIRMED' : 'PENDING');

    return Column(
      children: [
        // Ticket Match Card
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0052FF), // Primary container
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0052FF).withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.confirmation_number_outlined, color: Colors.white, size: 20.0),
                          SizedBox(width: 8.0),
                          Text(
                            'UPCOMING MATCH',
                            style: TextStyle(
                              fontSize: 10.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Text(
                          matchStatus.toString().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 28.0),
                  const Text(
                    'Match Date & Time',
                    style: TextStyle(
                      fontSize: 10.0,
                      color: Color(0xFFDDE1FF),
                    ),
                  ),
                  Text(
                    matchDate.toString(),
                    style: const TextStyle(
                      fontSize: 26.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFDDE1FF), size: 18.0),
                      const SizedBox(width: 6.0),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            venue.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.0),
                          ),
                          Text(
                            courtInfo.toString(),
                            style: const TextStyle(color: Color(0xFFDDE1FF), fontSize: 12.0),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 28.0),
                  ElevatedButton(
                    onPressed: () {
                      AppToast.showSuccess(context, title: 'Calendar', message: 'Event added to your calendar.');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF003EC7),
                      minimumSize: const Size(double.infinity, 48.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.calendar_today, size: 18.0),
                        SizedBox(width: 8.0),
                        Text('ADD TO CALENDAR', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            // Ticket cutout circles (Mock)
            Positioned(
              left: -8.0,
              bottom: 110.0,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF8FF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: -8.0,
              bottom: 110.0,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF8FF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20.0),

        // Development Metrics list
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4.0,
                  height: 24.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFF003EC7),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
                const SizedBox(width: 8.0),
                const Text(
                  'Development Metrics',
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
                ),
              ],
            ),
            const SizedBox(height: 16.0),

            // Academics card
            _buildMetricItemCard(
              'Academics',
              latestGrade > 0 ? 'Term Avg: ${latestGrade.toStringAsFixed(1)}%' : 'No grades recorded',
              latestGrade >= AppConfig.academicPassCutoff ? 'On Track' : (latestGrade > 0 ? 'Needs Attention' : 'Pending'),
              'ACADEMIC PORTAL',
              Icons.school,
              const Color(0xFF16A34A),
              latestGrade > 0 ? (latestGrade / 20).clamp(1, 5).toInt() : 0,
            ),
            const SizedBox(height: 12.0),

            // Athleticism card
            _buildMetricItemCard(
              'Athleticism',
              powerIndex > 0 ? 'Power Index: $powerIndex' : 'No tests logged',
              powerIndex > 0 ? 'Active Athlete' : 'Pending Test',
              'FITNESS PORTAL',
              Icons.sports_martial_arts,
              const Color(0xFF003EC7),
              powerIndex > 0 ? 5 : 0,
            ),
          ],
        )
      ],
    );
  }

  Widget _buildMetricItemCard(
    String title,
    String desc,
    String badgeText,
    String extraText,
    IconData icon,
    Color themeColor,
    int segmentsCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF), // surface-container-low
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: const Color(0xFFC3C5D9).withValues(alpha: 0.3), width: 1.0),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Icon(icon, color: const Color(0xFF003EC7), size: 28.0),
                  ),
                  const SizedBox(width: 16.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0, color: Color(0xFF131B2E)),
                      ),
                      Text(
                        desc,
                        style: const TextStyle(fontSize: 12.0, color: Color(0xFF434656)),
                      ),
                    ],
                  )
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Text(
                      badgeText.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    extraText,
                    style: const TextStyle(fontSize: 9.0, color: Color(0xFF434656), fontWeight: FontWeight.bold),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16.0),
          // Progress segments
          Row(
            children: List.generate(5, (index) {
              final isActive = index < segmentsCount;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.0),
                  height: 6.0,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF003EC7) : const Color(0xFFDAE2FD),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                badgeText,
                style: const TextStyle(fontSize: 10.0, color: Color(0xFF434656), fontWeight: FontWeight.bold),
              ),
              const Text(
                'Elite Benchmark: 90%',
                style: TextStyle(fontSize: 10.0, color: Color(0xFF434656), fontStyle: FontStyle.italic),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCoachQuoteCard(String studentName) {
    final actions = ref.watch(coachActionProvider);
    final studentActions = actions.where((a) =>
        a.playerName.isNotEmpty && studentName.toLowerCase().contains(a.playerName.toLowerCase())).toList();

    if (studentActions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: const Color(0xFFC3C5D9).withValues(alpha: 0.3), width: 1.0),
        ),
        child: Column(
          children: [
            const Icon(Icons.mark_chat_read_outlined, size: 36.0, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10.0),
            Text(
              'No Coach Notes Logged for $studentName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4.0),
            const Text(
              'Evaluation updates and direct notes from coaching staff will appear here as reviews are logged.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final latest = studentActions.first;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: const Color(0xFFC3C5D9).withValues(alpha: 0.3), width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                        latest.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF131B2E)),
                      ),
                      Text(
                        'Category: ${latest.category}',
                        style: const TextStyle(fontSize: 11.0, color: Color(0xFF434656)),
                      ),
                    ],
                  ),
                )
              ],
            ),
            if (latest.notes.isNotEmpty) ...[
              const SizedBox(height: 14.0),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Text(
                  '"${latest.notes}"',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF131B2E),
                    fontSize: 14.0,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCampusCheckoutCard(StudentPortalData data, String studentName) {
    final Map<String, dynamic>? latestAttendance = data.attendance.isNotEmpty
        ? (data.attendance.first is Map<String, dynamic> ? data.attendance.first as Map<String, dynamic> : null)
        : null;
    final checkoutTime = data.profile['checkoutTime'] ?? latestAttendance?['checkoutTime'] ?? latestAttendance?['time'] ?? '--';
    final checkoutStatus = data.profile['checkoutStatus'] ?? latestAttendance?['status'] ?? (latestAttendance != null ? 'CHECKED OUT' : 'STATUS: SAFE');
    final checkoutDesc = data.profile['checkoutDetails'] ?? '$studentName ${latestAttendance?['action'] ?? 'has checked out of training facility.'}';

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: const Color(0xFFC3C5D9).withValues(alpha: 0.3), width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user, color: Color(0xFF16A34A), size: 22.0),
              ),
              const SizedBox(width: 12.0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Campus Checkout',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0, color: Color(0xFF131B2E)),
                  ),
                  Text(
                    checkoutDesc.toString(),
                    style: const TextStyle(fontSize: 12.0, color: Color(0xFF434656)),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                checkoutTime.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: Color(0xFF131B2E)),
              ),
              Text(
                checkoutStatus.toString().toUpperCase(),
                style: const TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ==========================================
  // TAB REUSES FOR FITNESS, ACADEMICS, MATCHES
  // ==========================================
  Widget _buildFitnessTab(StudentPortalData data) {
    final baseline = data.fitness['baseline'];
    if (baseline == null) return _buildEmptyState('No fitness stats recorded.');
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      children: [
        const Text('Fitness Baselines', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Color(0xFF131B2E))),
        const SizedBox(height: 16.0),
        _buildStatCard('Speed', [
          _buildStatRow('40m Sprint', '${baseline['speed40m'] ?? '-'}s'),
          _buildStatRow('60m Sprint', '${baseline['speed60m'] ?? '-'}s'),
          _buildStatRow('T-Test Agility', '${baseline['tTest'] ?? '-'}s'),
        ]),
        const SizedBox(height: 16.0),
        _buildStatCard('Strength', [
          _buildStatRow('Push-Ups', '${baseline['pushUps'] ?? '-'} reps'),
          _buildStatRow('Pull-Ups', '${baseline['pullUps'] ?? '-'} reps'),
          _buildStatRow('Squats (40kg)', '${baseline['squats40kg'] ?? '-'} reps'),
        ]),
      ],
    );
  }

  Widget _buildAcademicsTab(StudentPortalData data) {
    if (data.academics.isEmpty) return _buildEmptyState('No academics recorded.');
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      itemCount: data.academics.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16.0),
      itemBuilder: (context, index) {
        final acad = data.academics[index];
        final grade = (acad['gradePercentage'] as num?)?.toDouble() ?? 0.0;
        final term = acad['term'] ?? 1;

        Color border = const Color(0xFF16A34A);
        if (grade < AppConfig.academicWarningCutoff) {
          border = const Color(0xFFDC2626);
        } else if (grade < AppConfig.academicPassCutoff) {
          border = const Color(0xFFD97706);
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              decoration: BoxDecoration(border: Border(left: BorderSide(color: border, width: 4.0))),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Term $term Report Card', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                        const Text('Official Term Grade', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.0)),
                      ],
                    ),
                    Text('$grade%', style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w900, color: border)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchesTab(StudentPortalData data) {
    if (data.matches.isEmpty) return _buildEmptyState('No matches played.');
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      itemCount: data.matches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16.0),
      itemBuilder: (context, index) {
        final match = data.matches[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('vs. ${match['opponent']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                    Text('${match['matchDate']}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.0)),
                  ],
                ),
                Text('${match['autoScore']}', style: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, List<Widget> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
            const Divider(height: 20.0),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 36.0, color: Color(0xFF64748B)),
            const SizedBox(height: 8.0),
            Text(msg, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
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
              selectedLabelStyle: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 11.0),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Overview'),
                BottomNavigationBarItem(icon: Icon(Icons.fitness_center_outlined), activeIcon: Icon(Icons.fitness_center), label: 'Fitness'),
                BottomNavigationBarItem(icon: Icon(Icons.school_outlined), activeIcon: Icon(Icons.school), label: 'Academics'),
                BottomNavigationBarItem(icon: Icon(Icons.sports_score_outlined), activeIcon: Icon(Icons.sports_score), label: 'Matches'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
