import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/roster_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../../../core/utils/app_toast.dart';

class ManagePlayerSquadsModal extends ConsumerStatefulWidget {
  final RosterPlayer player;
  final String currentAgeGroup;

  const ManagePlayerSquadsModal({
    super.key,
    required this.player,
    required this.currentAgeGroup,
  });

  @override
  ConsumerState<ManagePlayerSquadsModal> createState() => _ManagePlayerSquadsModalState();
}

class _ManagePlayerSquadsModalState extends ConsumerState<ManagePlayerSquadsModal> {
  final Set<String> _selectedSquadIds = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final s in widget.player.assignedSquads) {
      _selectedSquadIds.add(s.id);
    }
  }

  void _onToggleSquad(String squadId, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedSquadIds.add(squadId);
      } else {
        _selectedSquadIds.remove(squadId);
      }
    });
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    final success = await ref
        .read(rosterProvider.notifier)
        .updatePlayerSquads(widget.player.id, widget.currentAgeGroup, _selectedSquadIds.toList());

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
      if (success) {
        AppToast.showSuccess(context, title: 'Squad assignments updated for ${widget.player.firstName}');
        Navigator.pop(context, true);
      } else {
        AppToast.showError(context, title: 'Failed to update squad assignments');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSquads = ref.watch(squadsProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      padding: EdgeInsets.only(
        top: 20.0,
        left: 20.0,
        right: 20.0,
        bottom: bottomInset + paddingBottom + 24.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Color(0xFF2563EB),
                  size: 22.0,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Squads',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${widget.player.firstName} ${widget.player.lastName}',
                      style: const TextStyle(
                        fontSize: 13.0,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20.0),
          const Text(
            'Select all squads/teams this player belongs to:',
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 12.0),
          if (availableSquads.isEmpty)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 20.0),
                  SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      'No squads provisioned yet. Squads are managed via Admin Dashboard.',
                      style: TextStyle(fontSize: 13.0, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: availableSquads.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8.0),
                itemBuilder: (context, index) {
                  final squad = availableSquads[index];
                  final isChecked = _selectedSquadIds.contains(squad.id);
                  return Container(
                    decoration: BoxDecoration(
                      color: isChecked ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: isChecked ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        width: isChecked ? 1.5 : 1.0,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: isChecked,
                      onChanged: (val) => _onToggleSquad(squad.id, val),
                      activeColor: const Color(0xFF2563EB),
                      title: Text(
                        squad.name,
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: isChecked ? const Color(0xFF1E40AF) : const Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: Text(
                        'Age Group: ${squad.ageGroup}',
                        style: const TextStyle(
                          fontSize: 12.0,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 24.0),
          SizedBox(
            width: double.infinity,
            height: 48.0,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                    )
                  : const Text(
                      'Save Squad Assignments',
                      style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
