import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';
import '../controllers/roster_controller.dart';
import '../controllers/dashboard_controller.dart';
import 'create_action_modal.dart';
import 'single_player_baseline_modal.dart';
import 'manage_player_squads_modal.dart';
import 'add_existing_player_modal.dart';

class RosterTabView extends ConsumerStatefulWidget {
  const RosterTabView({super.key});

  @override
  ConsumerState<RosterTabView> createState() => _RosterTabViewState();
}

class _RosterTabViewState extends ConsumerState<RosterTabView> {
  final String _selectedAgeGroup = 'U15';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final currentAge = ref.read(selectedAgeGroupProvider);
      ref.read(rosterProvider.notifier).fetchRoster(currentAge);
    });
  }

  void _onAgeGroupChanged(String? newAge) {
    if (newAge != null) {
      ref.read(selectedAgeGroupProvider.notifier).state = newAge;
      ref.read(rosterProvider.notifier).fetchRoster(newAge);
      ref.read(dashboardSummaryProvider.notifier).fetchSummary(ageGroup: newAge);
      ref.read(dashboardFlagsProvider.notifier).fetchFlags(ageGroup: newAge);
      ref.read(risingStarsProvider.notifier).fetchRisingStars(ageGroup: newAge);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSubtitle(RosterPlayer player) {
    final parts = <String>[];
    if (player.position.isNotEmpty) {
      parts.add(player.position.toUpperCase());
    }
    if (player.assignedSquads.isNotEmpty) {
      parts.add(player.assignedSquads.map((s) => s.name.toUpperCase()).join(' / '));
    } else if (player.team.isNotEmpty) {
      parts.add(player.team.toUpperCase());
    }
    
    if (parts.isEmpty) {
      return Text(
        'UNASSIGNED • ${player.ageGroup}',
        style: const TextStyle(
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
          color: Color(0xFF94A3B8), // slate-400
          letterSpacing: 0.5,
        ),
      );
    }
    
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6.0,
      children: [
        for (int i = 0; i < parts.length; i++) ...[
          Text(
            parts[i],
            style: const TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2563EB), // azure-600
              letterSpacing: 0.8,
            ),
          ),
          if (i < parts.length - 1)
            const Text(
              '/',
              style: TextStyle(
                fontSize: 11.0,
                color: Color(0xFFCBD5E1), // slate-300
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAgeGroup = ref.watch(selectedAgeGroupProvider);

    ref.listen<String>(selectedAgeGroupProvider, (previous, next) {
      if (previous != next) {
        ref.read(rosterProvider.notifier).fetchRoster(next);
      }
    });

    final rosterState = ref.watch(rosterProvider);
    final flagsState = ref.watch(dashboardFlagsProvider);

    final players = rosterState.playersByAge[selectedAgeGroup] ?? [];
    final filteredPlayers = players.where((p) {
      final fullName = '${p.firstName} ${p.lastName}'.toLowerCase();
      return fullName.contains(_searchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row 1: Title & Squad Dropdown Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [              const Text(
                'Squad Athletes',
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 8.0),
              // Squad Dropdown selector
              Flexible(
                child: Consumer(
                  builder: (context, ref, child) {
                    final squads = ref.watch(squadsProvider);
                    final activeValue = squads.any((s) => s.ageGroup == selectedAgeGroup)
                        ? selectedAgeGroup
                        : (squads.isNotEmpty ? squads.first.ageGroup : 'None');

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: activeValue,
                          borderRadius: BorderRadius.circular(16.0),
                          isDense: true,
                          isExpanded: false,
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB)),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13.0),
                          items: [
                            if (squads.isEmpty)
                              const DropdownMenuItem(
                                value: 'None',
                                child: Text('No Squad Created', overflow: TextOverflow.ellipsis),
                              ),
                            ...squads.map((sq) => DropdownMenuItem(
                                  value: sq.ageGroup,
                                  child: Text(sq.name, overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (newAge) {
                            if (newAge != null) {
                              _onAgeGroupChanged(newAge);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          // Action Row 2: Search Field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search athlete by name...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20.0),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18.0, color: Color(0xFF94A3B8)),
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
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  AddExistingPlayerModal.show(context, activeAgeGroup: selectedAgeGroup);
                },
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  height: 46.0,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_alt_1, size: 16.0, color: Color(0xFF2563EB)),
                      SizedBox(width: 4.0),
                      Text(
                        '+ Add Existing Player',
                        style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20.0),

          // Loader or Error states
          if (rosterState.loading && players.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (rosterState.error != null && players.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 40.0, color: Color(0xFF64748B)),
                    const SizedBox(height: 8.0),
                    Text(rosterState.error!, style: const TextStyle(color: Color(0xFF64748B))),
                    const SizedBox(height: 12.0),
                    ElevatedButton(
                      onPressed: () => ref.read(rosterProvider.notifier).fetchRoster(_selectedAgeGroup),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (filteredPlayers.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.groups_outlined, size: 48.0, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No athletes match "$_searchQuery"'
                          : 'No Squad Athletes Registered',
                      style: const TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6.0),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'Try adjusting your search filter or age group.'
                            : 'No athletes have been assigned to squad $selectedAgeGroup yet.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13.0, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 100.0),
                itemCount: filteredPlayers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12.0),
                itemBuilder: (context, index) {
                  final player = filteredPlayers[index];
                  final initials = '${player.firstName.isNotEmpty ? player.firstName[0] : ''}${player.lastName.isNotEmpty ? player.lastName[0] : ''}';
                  
                  // Check if player has flags
                  final isFlagged = flagsState.maybeWhen(
                    data: (flags) => flags.any((f) => f.id == player.id),
                    orElse: () => false,
                  );

                  return GestureDetector(
                    onTap: () => _showPlayerProfileSheet(context, player, isFlagged),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: isFlagged 
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFF1F5F9),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x0A0F172A),
                            blurRadius: 16.0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 56.0,
                            height: 56.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFlagged 
                                  ? const Color(0xFFFEE2E2) 
                                  : const Color(0xFFEFF6FF), // azure-50
                              border: Border.all(
                                color: isFlagged 
                                    ? const Color(0xFFFCA5A5) 
                                    : const Color(0xFFDBEAFE), // azure-100
                                width: 1.0,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                initials.isNotEmpty ? initials : 'P',
                                style: TextStyle(
                                  color: isFlagged 
                                      ? const Color(0xFFDC2626) 
                                      : const Color(0xFF2563EB), // azure-600
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16.0),
                          
                          // Middle Text Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${player.firstName} ${player.lastName}'.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    if (player.age != null && player.age! > 0) ...[
                                      const SizedBox(width: 8.0),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9), // slate-100
                                          borderRadius: BorderRadius.circular(6.0),
                                        ),
                                        child: Text(
                                          'Age ${player.age}',
                                          style: const TextStyle(
                                            fontSize: 11.0,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF475569), // slate-600
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6.0),
                                      InkWell(
                                        onTap: () async {
                                          final squads = ref.read(squadsProvider);
                                          final activeSquad = squads.firstWhere(
                                            (s) => s.ageGroup == selectedAgeGroup,
                                            orElse: () => squads.isNotEmpty ? squads.first : SquadItem(id: 'default', name: 'Active Squad', ageGroup: selectedAgeGroup, description: ''),
                                          );

                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                                              actionsPadding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 20.0),
                                              title: const Text('Remove Player from Squad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17.0)),
                                              content: Text(
                                                'Are you sure you want to remove ${player.firstName} ${player.lastName} from ${activeSquad.name}?\n\nNote: This unassigns the athlete from this squad while keeping their profile intact in the school database.',
                                                style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
                                              ),
                                              actions: [
                                                OutlinedButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                                    foregroundColor: const Color(0xFF475569),
                                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                                  ),
                                                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFDC2626),
                                                    foregroundColor: Colors.white,
                                                    elevation: 0,
                                                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                                  ),
                                                  child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed == true && context.mounted) {
                                            final ok = await ref.read(rosterProvider.notifier).removePlayerFromSquad(player.id, activeSquad.id, selectedAgeGroup);
                                            if (context.mounted) {
                                              if (ok) {
                                                AppToast.showSuccess(context, title: '${player.firstName} removed from ${activeSquad.name}');
                                              } else {
                                                AppToast.showError(context, title: 'Failed to remove player from squad');
                                              }
                                            }
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(20.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(20.0),
                                            border: Border.all(color: const Color(0xFFFECACA)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.person_remove_outlined, size: 12.0, color: Color(0xFFDC2626)),
                                              SizedBox(width: 4.0),
                                              Text(
                                                'Remove from Squad',
                                                style: TextStyle(
                                                  fontSize: 10.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFDC2626),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6.0),
                                _buildSubtitle(player),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          
                          // Trailing elements (Warning icon if flagged, and Chevron Right)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isFlagged) ...[
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20.0),
                                const SizedBox(width: 8.0),
                              ],
                              const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 22.0),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPositionRow(BuildContext context, WidgetRef ref, RosterPlayer player, [VoidCallback? onUpdated, String? preferredPosition]) {
    return InkWell(
      onTap: () => _showEditPositionDialog(context, ref, player, onUpdated),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Official Position Allocation',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14.0),
                ),
                Row(
                  children: [
                    Text(
                      player.position.isNotEmpty ? player.position : 'Unassigned',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontSize: 14.0,
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    const Icon(
                      Icons.edit_outlined,
                      size: 16.0,
                      color: Color(0xFF2563EB),
                    ),
                  ],
                ),
              ],
            ),
            if (preferredPosition != null && preferredPosition.trim().isNotEmpty) ...[
              const SizedBox(height: 4.0),
              Text(
                'Athlete Preference: $preferredPosition',
                style: const TextStyle(fontSize: 12.0, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditPositionDialog(BuildContext context, WidgetRef ref, RosterPlayer player, [VoidCallback? onUpdated]) {
    const rugbyPositionsList = [
      'Loosehead Prop',
      'Hooker',
      'Tighthead Prop',
      'Lock',
      'Blindside Flanker',
      'Openside Flanker',
      'Number 8',
      'Scrumhalf',
      'Flyhalf',
      'Left Wing',
      'Inside Center',
      'Outside Center',
      'Right Wing',
      'Fullback',
      'Utility Forward',
      'Utility Back',
    ];
    String selectedPos = rugbyPositionsList.contains(player.position) ? player.position : rugbyPositionsList.first;
    final controller = TextEditingController(text: selectedPos);
    showDialog(
      context: context,
      builder: (context) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              actionsPadding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 20.0),
              title: const Text(
                'Edit Position',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Specify the field position for ${player.firstName}:',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.0),
                  ),
                  const SizedBox(height: 12.0),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPos,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                    ),
                    items: rugbyPositionsList.map((pos) {
                      return DropdownMenuItem<String>(
                        value: pos,
                        child: Text(pos, style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: saving ? null : (val) {
                      if (val != null) {
                        selectedPos = val;
                        controller.text = val;
                      }
                    },
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    foregroundColor: const Color(0xFF475569),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() {
                            saving = true;
                          });
                          final newPos = controller.text.trim();
                          final success = await ref
                              .read(rosterProvider.notifier)
                              .updatePlayerPosition(player, newPos);
                          if (success) {
                            player.position = newPos;
                            onUpdated?.call();
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            if (success) {
                              AppToast.showSuccess(context, title: 'Position Updated', message: 'Player position changed successfully.');
                            } else {
                              AppToast.showError(context, title: 'Update Failed', message: 'Could not update position. Please try again.');
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 16.0,
                          height: 16.0,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPlayerProfileSheet(BuildContext context, RosterPlayer player, bool isFlagged) {
    final initials = '${player.firstName.isNotEmpty ? player.firstName[0] : ''}${player.lastName.isNotEmpty ? player.lastName[0] : ''}';
    final apiClient = ref.read(apiClientProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF8FAFC),
      constraints: const BoxConstraints(maxWidth: double.infinity),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        final bottomInset = MediaQuery.of(context).padding.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return FutureBuilder<Response>(
                  future: apiClient.getAndCache('/api/student-portal?player_id=${player.id}'),
                  builder: (context, snapshot) {
                    List dynamicMetrics = [];
                    String gpa = '--';
                    int powerIndex = 0;
                    String gymAtt = '0%';
                    String? preferredPos;

                    if (snapshot.hasData && snapshot.data?.data['success'] == true) {
                      final data = snapshot.data?.data['data'] ?? {};
                      dynamicMetrics = data['dynamicMetrics'] ?? [];
                      if (data['profile'] != null) {
                        preferredPos = data['profile']['preferredPosition']?.toString();
                      }
                      final academics = data['academics'] ?? [];
                      if (academics.isNotEmpty) {
                        final lastGrade = academics.last['gradePercentage'];
                        if (lastGrade != null) gpa = '$lastGrade%';
                      }
                      powerIndex = data['readinessScore'] ?? 0;
                      final att = data['attendanceRate'];
                      if (att != null) gymAtt = '$att%';
                    }

                    return SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.only(
                        left: 24.0,
                        right: 24.0,
                        top: 24.0,
                        bottom: 24.0 + bottomInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8.0),

                          // Athlete Profile Header Section
                          Row(
                            children: [
                              Container(
                                width: 80.0,
                                height: 80.0,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD0E1FB),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(color: const Color(0xFFB7C8E1), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4.0,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    initials.isNotEmpty ? initials : 'P',
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24.0,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${player.firstName} ${player.lastName}',
                                      style: const TextStyle(
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      '${player.position.isNotEmpty ? player.position : 'Unassigned'} • ${player.team.isNotEmpty ? player.team : player.ageGroup}',
                                      style: const TextStyle(
                                        fontSize: 13.0,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6.0),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0052FF),
                                            borderRadius: BorderRadius.circular(20.0),
                                          ),
                                          child: const Text(
                                            'Active Squad',
                                            style: TextStyle(
                                              fontSize: 10.0,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6.0),
                                        InkWell(
                                          onTap: () async {
                                            final updated = await showModalBottomSheet<bool>(
                                              context: context,
                                              isScrollControlled: true,
                                              useSafeArea: true,
                                              backgroundColor: Colors.transparent,
                                              builder: (context) => ManagePlayerSquadsModal(
                                                player: player,
                                                currentAgeGroup: player.ageGroup,
                                              ),
                                            );
                                            if (updated == true) {
                                              setSheetState(() {});
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(20.0),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(20.0),
                                              border: Border.all(color: const Color(0xFFBFDBFE)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.edit_calendar, size: 12.0, color: Color(0xFF2563EB)),
                                                SizedBox(width: 4.0),
                                                Text(
                                                  'Manage Squads',
                                                  style: TextStyle(
                                                    fontSize: 10.0,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF2563EB),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24.0),

                          // Development Portals Bento Grid
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Development Portals',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'METRICS OVERVIEW',
                                style: TextStyle(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF003EC7),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),

                          // Bento grid layout
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12.0,
                            mainAxisSpacing: 12.0,
                            childAspectRatio: 1.15,
                            children: [
                              _buildBentoCard(
                                title: 'MIND\n(ACADEMIC)',
                                value: gpa,
                                subtext: 'Term Average',
                                icon: Icons.psychology,
                                color: const Color(0xFF003EC7),
                              ),
                              _buildBentoCard(
                                title: 'BODY\n(FITNESS)',
                                value: '$powerIndex',
                                subtext: 'Power Index',
                                icon: Icons.fitness_center,
                                color: const Color(0xFF16A34A),
                              ),
                              _buildBentoCard(
                                title: 'GYM\nATTENDANCE',
                                value: gymAtt,
                                subtext: 'Facility Attendance',
                                icon: Icons.open_in_full,
                                color: const Color(0xFF64748B),
                                valueColor: const Color(0xFF131B2E),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24.0),

                          // Evaluation Baselines Section Header & Action Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Evaluation Baselines',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0, color: Color(0xFF0F172A)),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  HapticFeedback.lightImpact();
                                  await SinglePlayerBaselineModal.show(
                                    context,
                                    playerId: player.id,
                                    playerName: '${player.firstName} ${player.lastName}',
                                  );
                                  setSheetState(() {});
                                },
                                icon: const Icon(Icons.edit_note, size: 18.0, color: Color(0xFF003EC7)),
                                label: const Text(
                                  'Update Test Score',
                                  style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Color(0xFF003EC7)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                            ),
                            child: Column(
                              children: [
                                if (dynamicMetrics.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'No baseline test scores logged for this athlete yet.\nTap "Update Test Score" above to record a baseline test.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                                    ),
                                  )
                                else
                                  ...dynamicMetrics.map((m) {
                                    final name = m['name'] ?? 'Test';
                                    final latest = m['latestScore'];
                                    final unit = m['unit'] ?? '';
                                    final valStr = latest != null ? '$latest $unit' : 'No test logged';
                                    return Column(
                                      children: [
                                        _buildProfileRow(name, valStr),
                                        const Divider(height: 1.0, color: Color(0xFFE2E8F0)),
                                      ],
                                    );
                                  }),
                                _buildPositionRow(context, ref, player, () => setSheetState(() {}), preferredPos),
                                const Divider(height: 1.0, color: Color(0xFFE2E8F0)),
                                _buildProfileRow('Athlete System ID', player.id),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24.0),

                          // Actions
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.pop(context);
                                  CreateActionModal.show(
                                    context,
                                    playerId: player.id,
                                    playerName: '${player.firstName} ${player.lastName}',
                                  );
                                },
                                icon: const Icon(Icons.add_task, size: 18.0),
                                label: const Text(
                                  'Set Coach Action Plan',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF003EC7),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                ),
                              ),
                              const SizedBox(height: 10.0),
                              OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                ),
                                child: const Text(
                                  'Close Profile',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProfileRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14.0)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14.0)),
        ],
      ),
    );
  }

  Widget _buildBentoCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    Color? valueColor,
    bool hasLeftBorder = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasLeftBorder)
            Container(
              width: 4.0,
              color: color,
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.8,
                            height: 1.2,
                          ),
                        ),
                      ),
                      Icon(icon, color: color, size: 18.0),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: valueColor ?? color,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        subtext,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.0,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
