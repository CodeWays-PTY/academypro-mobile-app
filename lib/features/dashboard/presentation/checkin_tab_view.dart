import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_toast.dart';
import '../controllers/checkin_controller.dart';
import '../controllers/roster_controller.dart';
import '../controllers/dashboard_controller.dart';
import 'qr_scanner_modal.dart';

class CheckInTabView extends ConsumerStatefulWidget {
  const CheckInTabView({super.key});

  @override
  ConsumerState<CheckInTabView> createState() => _CheckInTabViewState();
}

class _CheckInTabViewState extends ConsumerState<CheckInTabView> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final selectedAge = ref.read(selectedAgeGroupProvider);
      ref.read(rosterProvider.notifier).fetchRoster(selectedAge);
      ref.read(dashboardEventsProvider.notifier).fetchEvents(ageGroup: selectedAge);
      _ensureRosterInitialized();
    });
  }

  void _ensureRosterInitialized() {
    final selectedAge = ref.read(selectedAgeGroupProvider);
    final rosterState = ref.read(rosterProvider);
    final players = rosterState.playersByAge[selectedAge] ?? [];
    if (players.isNotEmpty) {
      ref.read(checkInProvider.notifier).initRoster(selectedAge, players);
    }
  }

  void _showMandatoryEventPickerDialog(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (ctx) {
        final selectedAgeGroup = ref.watch(selectedAgeGroupProvider);
        final eventsState = ref.watch(dashboardEventsProvider);
        final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final todayEvents = eventsState.maybeWhen(
          data: (list) => list.where((e) {
            final matchesDate = e.date == nowStr;
            final matchesTeam = selectedAgeGroup == 'All' ||
                e.ageGroup.toLowerCase().trim() == selectedAgeGroup.toLowerCase().trim() ||
                e.team.toLowerCase().trim().contains(selectedAgeGroup.toLowerCase().trim());
            return matchesDate && matchesTeam;
          }).toList(),
          orElse: () => <CoachEvent>[],
        );
        todayEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

        return SafeArea(
          top: false,
          bottom: true,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24.0, 20.0, 24.0, MediaQuery.of(context).padding.bottom + 24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.event_available, color: Color(0xFF003EC7), size: 24.0),
                      SizedBox(width: 10.0),
                      Text(
                        'Select Event First',
                        style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  const Text(
                    'Please select which scheduled session you are taking attendance for before marking players.',
                    style: TextStyle(fontSize: 13.0, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16.0),
                  if (todayEvents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('No scheduled events found for today. Please create an event first.', style: TextStyle(color: Color(0xFF64748B))),
                    )
                  else
                    Column(
                      children: todayEvents.map((event) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            tileColor: const Color(0xFFF8FAFC),
                            leading: const Icon(Icons.sports_soccer, color: Color(0xFF003EC7)),
                            title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0)),
                            subtitle: Text('${event.startTime} • ${event.location}', style: const TextStyle(fontSize: 12.0)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14.0, color: Color(0xFF003EC7)),
                            onTap: () {
                              Navigator.pop(ctx);
                              ref.read(checkInProvider.notifier).selectEvent(event);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedAgeGroup = ref.watch(selectedAgeGroupProvider);

    ref.listen<String>(selectedAgeGroupProvider, (previous, next) {
      if (previous != next) {
        ref.read(dashboardEventsProvider.notifier).fetchEvents(ageGroup: next);
        final currentEvent = ref.read(checkInProvider).selectedEvent;
        if (currentEvent != null) {
          final matchesNewTeam = next == 'All' ||
              currentEvent.ageGroup.toLowerCase().trim() == next.toLowerCase().trim() ||
              currentEvent.team.toLowerCase().trim().contains(next.toLowerCase().trim());
          if (!matchesNewTeam) {
            ref.read(checkInProvider.notifier).clearSelectedEvent();
          }
        }
      }
    });

    final rosterState = ref.watch(rosterProvider);
    final eventsState = ref.watch(dashboardEventsProvider);
    final checkInState = ref.watch(checkInProvider);

    final players = rosterState.playersByAge[selectedAgeGroup] ?? [];

    // Automatically sync roster to check-in state whenever roster updates
    if (players.isNotEmpty && checkInState.totalCount == 0) {
      Future.microtask(() {
        ref.read(checkInProvider.notifier).initRoster(selectedAgeGroup, players);
      });
    }

    final recordsList = checkInState.playerRecords.values.toList();
    final filteredRecords = recordsList.where((r) {
      final fullName = '${r.player.firstName} ${r.player.lastName}'.toLowerCase();
      final pos = r.player.position.toLowerCase();
      final q = _searchQuery.toLowerCase();
      return fullName.contains(q) || pos.contains(q);
    }).toList();

    final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final hasTodayEvents = eventsState.maybeWhen(
      data: (allEvents) => allEvents.any((e) {
        final matchesDate = e.date == nowStr;
        final matchesTeam = selectedAgeGroup == 'All' ||
            e.ageGroup.toLowerCase().trim() == selectedAgeGroup.toLowerCase().trim() ||
            e.team.toLowerCase().trim().contains(selectedAgeGroup.toLowerCase().trim());
        return matchesDate && matchesTeam;
      }),
      orElse: () => true,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(rosterProvider.notifier).fetchRoster(selectedAgeGroup);
          await ref.read(dashboardEventsProvider.notifier).fetchEvents(ageGroup: selectedAgeGroup);
          final updatedPlayers = ref.read(rosterProvider).playersByAge[selectedAgeGroup] ?? [];
          ref.read(checkInProvider.notifier).initRoster(selectedAgeGroup, updatedPlayers);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 100.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===================================================================
              // 1. CLEAN HEADER (Fixed layout, no text collision)
              // ===================================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Practice Check-In',
                          style: TextStyle(
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2.0),
                        Text(
                          'Mark attendance by name or scan QR badges',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12.0),

                  // Age Group Dropdown Selector Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final squads = ref.watch(squadsProvider);
                        final activeValue = squads.any((s) => s.ageGroup == selectedAgeGroup)
                            ? selectedAgeGroup
                            : (squads.isNotEmpty ? squads.first.ageGroup : 'U15');

                        return DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: activeValue,
                            borderRadius: BorderRadius.circular(16.0),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB)),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13.5),
                            items: [
                              ...squads.map((sq) => DropdownMenuItem(
                                    value: sq.ageGroup,
                                    child: Text(sq.name),
                                  )),
                            ],
                            onChanged: (newAge) {
                              if (newAge != null) {
                                ref.read(selectedAgeGroupProvider.notifier).state = newAge;
                                ref.read(rosterProvider.notifier).fetchRoster(newAge);
                                final updated = ref.read(rosterProvider).playersByAge[newAge] ?? [];
                                ref.read(checkInProvider.notifier).changeAgeGroup(newAge, updated);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18.0),

              // ===================================================================
              // 2. CONTINUOUS QR SCANNER CARD (Polished alignment)
              // ===================================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF003EC7), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF003EC7).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14.0),
                          ),
                          child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28.0),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Continuous QR Scanner',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2.0),
                              Text(
                                'Keep camera open to scan athlete badges back-to-back',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14.0),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (checkInState.selectedEvent == null) {
                            _showMandatoryEventPickerDialog(context);
                          } else {
                            HapticFeedback.mediumImpact();
                            QrScannerModal.show(context);
                          }
                        },
                        icon: const Icon(Icons.camera_alt_outlined, size: 18.0),
                        label: const Text(
                          'Open Live Scanner Mode',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF003EC7),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20.0),

              // ===================================================================
              // 3. SCHEDULED EVENTS SELECTOR CAROUSEL (SORTED BY TIME)
              // ===================================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "TODAY'S SCHEDULED EVENTS",
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),

              eventsState.when(
                data: (allEvents) {
                  // Filter strictly for today's date and the selected age group / team
                  final todayEvents = allEvents.where((e) {
                    final matchesDate = e.date == nowStr;
                    final matchesTeam = selectedAgeGroup == 'All' ||
                        e.ageGroup.toLowerCase().trim() == selectedAgeGroup.toLowerCase().trim() ||
                        e.team.toLowerCase().trim().contains(selectedAgeGroup.toLowerCase().trim());
                    return matchesDate && matchesTeam;
                  }).toList();
                  
                  // Sort chronologically by startTime
                  todayEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

                  if (todayEvents.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.event_note, color: Color(0xFF2563EB), size: 20.0),
                          SizedBox(width: 10.0),
                          Expanded(
                            child: Text(
                              'No scheduled events for today',
                              style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return SizedBox(
                    height: 85.0,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: todayEvents.length,
                      separatorBuilder: (ctx, i) => const SizedBox(width: 10.0),
                      itemBuilder: (context, index) {
                        final event = todayEvents[index];
                        final isSelected = checkInState.selectedEvent?.id == event.id;

                        IconData eventIcon = Icons.sports_soccer;
                        Color accentColor = const Color(0xFF003EC7);
                        if (event.eventType == 'Gym') {
                          eventIcon = Icons.fitness_center;
                          accentColor = const Color(0xFF7C3AED);
                        } else if (event.eventType == 'Match') {
                          eventIcon = Icons.sports_score;
                          accentColor = const Color(0xFF166534);
                        } else if (event.eventType == 'Fitness Test' || event.eventType == 'Test Day') {
                          eventIcon = Icons.timer_outlined;
                          accentColor = const Color(0xFFD97706);
                        }

                        return InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(checkInProvider.notifier).selectEvent(event);
                          },
                          borderRadius: BorderRadius.circular(16.0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 230.0,
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: isSelected ? accentColor.withValues(alpha: 0.08) : Colors.white,
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: isSelected ? accentColor : const Color(0xFFE2E8F0),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(eventIcon, color: accentColor, size: 16.0),
                                    const SizedBox(width: 6.0),
                                    Expanded(
                                      child: Text(
                                        '${event.startTime} • TODAY',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: accentColor,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle, color: accentColor, size: 16.0),
                                  ],
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  event.title,
                                  style: const TextStyle(
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  event.location,
                                  style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const SizedBox(
                  height: 60.0,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
                ),
                error: (_, _) => Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text('General Field Practice Session', style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 18.0),

              // ===================================================================
              // 4. ATTENDANCE PROGRESS STATS CARD
              // ===================================================================
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: checkInState.checkedInCount > 0
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFF94A3B8),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              'CHECKED IN: ${checkInState.checkedInCount} / ${checkInState.totalCount} ATHLETES',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${(checkInState.progressPercentage * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF003EC7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10.0),

                    // Linear Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999.0),
                      child: LinearProgressIndicator(
                        value: checkInState.progressPercentage,
                        minHeight: 8.0,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          checkInState.checkedInCount == checkInState.totalCount && checkInState.totalCount > 0
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF003EC7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Text(
                      checkInState.selectedEvent != null
                          ? 'Active Session: ${checkInState.selectedEvent!.title}'
                          : (!hasTodayEvents
                              ? '⚠️ Please create an event first to start check-in'
                              : '⚠️ Please select a scheduled event above to start check-in'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: checkInState.selectedEvent != null ? const Color(0xFF2563EB) : const Color(0xFFB45309),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18.0),

              // ===================================================================
              // 5. SEARCH INPUT BAR WITH 'X' CLEAR BUTTON
              // ===================================================================
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search player by name or position...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14.0),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 16.0),

              // ===================================================================
              // 6. ROSTER LIST (MANUAL CHECK-IN BY NAME - WITH EVENT CHECK)
              // ===================================================================
              if (filteredRecords.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_search_outlined, color: Color(0xFF64748B), size: 40.0),
                      ),
                      const SizedBox(height: 14.0),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No check-in match for "$_searchQuery"'
                            : 'No Athletes Registered in Squad',
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16.0, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Try clearing your search query.'
                            : 'No athletes are currently assigned to squad $selectedAgeGroup.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredRecords.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10.0),
                  itemBuilder: (context, index) {
                    final item = filteredRecords[index];
                    final player = item.player;
                    final isCheckedIn = item.isCheckedIn;
                    final timeStr = item.checkInTime != null ? DateFormat('hh:mm a').format(item.checkInTime!) : '';

                    return InkWell(
                      onTap: () {
                        if (checkInState.selectedEvent == null) {
                          _showMandatoryEventPickerDialog(context);
                        } else {
                          ref.read(checkInProvider.notifier).toggleAndSaveCheckIn(player.id);
                        }
                      },
                      borderRadius: BorderRadius.circular(16.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                        decoration: BoxDecoration(
                          color: isCheckedIn ? const Color(0xFFF0FDF4) : Colors.white,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: isCheckedIn ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                            width: isCheckedIn ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Status Checkbox Indicator Button
                            Container(
                              width: 36.0,
                              height: 36.0,
                              decoration: BoxDecoration(
                                color: isCheckedIn ? const Color(0xFF22C55E) : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCheckedIn ? const Color(0xFF22C55E) : const Color(0xFFCBD5E1),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                isCheckedIn ? Icons.check : Icons.radio_button_unchecked,
                                color: isCheckedIn ? Colors.white : const Color(0xFF94A3B8),
                                size: 20.0,
                              ),
                            ),
                            const SizedBox(width: 14.0),

                            // Athlete Name & Position
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${player.firstName} ${player.lastName}',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: isCheckedIn ? const Color(0xFF14532D) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    '${player.position.toUpperCase()} • ${player.team.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isCheckedIn ? const Color(0xFF166534) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Check-in Badge/Status
                            if (isCheckedIn)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(999.0),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, color: Color(0xFF15803D), size: 12.0),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        color: Color(0xFF15803D),
                                        fontSize: 11.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(999.0),
                                ),
                                child: const Text(
                                  'Unchecked',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 32.0),
            ],
          ),
        ),
      ),
    );
  }
}
