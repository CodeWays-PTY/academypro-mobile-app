import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/roster_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../../../core/utils/app_toast.dart';

class AddExistingPlayerModal extends ConsumerStatefulWidget {
  final String activeAgeGroup;

  const AddExistingPlayerModal({
    super.key,
    required this.activeAgeGroup,
  });

  static Future<void> show(BuildContext context, {required String activeAgeGroup}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExistingPlayerModal(activeAgeGroup: activeAgeGroup),
    );
  }

  @override
  ConsumerState<AddExistingPlayerModal> createState() => _AddExistingPlayerModalState();
}

class _AddExistingPlayerModalState extends ConsumerState<AddExistingPlayerModal> {
  int _selectedTabIndex = 0; // 0 = Search Existing, 1 = Register New Player
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  List<RosterPlayer> _allSchoolPlayers = [];
  List<RosterPlayer> _filteredPlayers = [];
  bool _isLoading = true;
  bool _isRegistering = false;
  final Set<String> _addingPlayerIds = {};

  @override
  void initState() {
    super.initState();
    _loadSchoolPlayers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSchoolPlayers([String query = '']) async {
    setState(() {
      _isLoading = true;
    });

    final players = await ref.read(rosterProvider.notifier).fetchSchoolPlayers(query);

    if (mounted) {
      setState(() {
        _allSchoolPlayers = players;
        _filteredPlayers = players;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    final clean = query.trim().toLowerCase();
    setState(() {
      if (clean.isEmpty) {
        _filteredPlayers = _allSchoolPlayers;
      } else {
        _filteredPlayers = _allSchoolPlayers.where((p) {
          final fullName = '${p.firstName} ${p.lastName}'.toLowerCase();
          return fullName.contains(clean) || p.ageGroup.toLowerCase().contains(clean);
        }).toList();
      }
    });
  }

  Future<void> _handleAddPlayer(RosterPlayer player, String targetSquadId) async {
    setState(() {
      _addingPlayerIds.add(player.id);
    });

    HapticFeedback.lightImpact();

    final success = await ref.read(rosterProvider.notifier).addPlayerToSquad(
          player.id,
          targetSquadId,
          widget.activeAgeGroup,
        );

    if (mounted) {
      setState(() {
        _addingPlayerIds.remove(player.id);
      });

      if (success) {
        AppToast.showSuccess(
          context,
          title: '${player.firstName} ${player.lastName} added to squad',
        );
        _loadSchoolPlayers(_searchController.text);
      } else {
        AppToast.showError(
          context,
          title: 'Failed to add ${player.firstName} to squad',
        );
      }
    }
  }

  Future<void> _handleRegisterNewPlayer(String targetSquadId) async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();

    if (firstName.isEmpty) {
      AppToast.showError(context, title: 'Missing First Name', message: 'Please enter a first name');
      return;
    }
    if (lastName.isEmpty) {
      AppToast.showError(context, title: 'Missing Surname', message: 'Please enter a surname / last name');
      return;
    }
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      AppToast.showError(context, title: 'Invalid Email', message: 'Please enter a valid email address');
      return;
    }

    setState(() => _isRegistering = true);
    HapticFeedback.lightImpact();

    try {
      final success = await ref.read(rosterProvider.notifier).registerAndAddPlayer(
            firstName: firstName,
            lastName: lastName,
            email: email,
            ageGroup: widget.activeAgeGroup,
            squadId: targetSquadId,
          );

      if (mounted) {
        setState(() => _isRegistering = false);

        if (success) {
          AppToast.showSuccess(
            context,
            title: '$firstName $lastName registered & added to squad',
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegistering = false);
        AppToast.showError(
          context,
          title: 'Registration Error',
          message: e.toString(),
        );
      }
    }
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12.0),
      ),
      padding: const EdgeInsets.all(4.0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTabIndex = 0);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9.0),
                  boxShadow: _selectedTabIndex == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    'Search Existing',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: _selectedTabIndex == 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTabIndex = 1);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9.0),
                  boxShadow: _selectedTabIndex == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_add_rounded,
                        size: 16.0,
                        color: _selectedTabIndex == 1 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        'Register New',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: _selectedTabIndex == 1 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab(String squadId, String squadName) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4.0),
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20.0),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    'Registering player to school system & assigning to $squadName (${widget.activeAgeGroup}).',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),

          // First Name Field
          const Text(
            'First Name',
            style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6.0),
          TextField(
            controller: _firstNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'e.g. John',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF2563EB), size: 20.0),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14.0),

          // Last Name Field
          const Text(
            'Surname / Last Name',
            style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6.0),
          TextField(
            controller: _lastNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'e.g. Smith',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF2563EB), size: 20.0),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14.0),

          // Email Field
          const Text(
            'Email Address',
            style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6.0),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'e.g. john.smith@school.co.za',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF2563EB), size: 20.0),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24.0),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48.0,
            child: ElevatedButton.icon(
              onPressed: _isRegistering ? null : () => _handleRegisterNewPlayer(squadId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                elevation: 0,
              ),
              icon: _isRegistering
                  ? const SizedBox(
                      width: 18.0,
                      height: 18.0,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded, size: 20.0),
              label: Text(
                _isRegistering ? 'Registering Player...' : 'Register & Add to Squad',
                style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab(String targetSquadId) {
    return Column(
      children: [
        const SizedBox(height: 4.0),
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search player name or age group...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20.0),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18.0, color: Color(0xFF64748B)),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12.0),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                )
              : _filteredPlayers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_search_outlined, size: 48.0, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12.0),
                          const Text(
                            'No Players Found',
                            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'No players matching "${_searchController.text}"'
                                : 'No unassigned players available in the school system.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13.0, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredPlayers.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final player = _filteredPlayers[index];
                        final isAlreadyInSquad = player.assignedSquads.any((s) => s.id == targetSquadId);
                        final isAdding = _addingPlayerIds.contains(player.id);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: Text(
                              player.firstName.isNotEmpty ? player.firstName[0].toUpperCase() : 'P',
                              style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            '${player.firstName} ${player.lastName}',
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                          subtitle: Text(
                            '${player.ageGroup}${player.position.isNotEmpty ? ' • ${player.position}' : ''}',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                          trailing: isAdding
                              ? const SizedBox(
                                  width: 24.0,
                                  height: 24.0,
                                  child: CircularProgressIndicator(strokeWidth: 2.0, color: Color(0xFF2563EB)),
                                )
                              : isAlreadyInSquad
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      child: const Text(
                                        'In Squad',
                                        style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: () => _handleAddPlayer(player, targetSquadId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                      ),
                                      icon: const Icon(Icons.add_rounded, size: 16.0),
                                      label: const Text('Add', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                    ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final squads = ref.watch(squadsProvider);
    final activeSquad = squads.firstWhere(
      (s) => s.ageGroup == widget.activeAgeGroup,
      orElse: () => squads.isNotEmpty
          ? squads.first
          : SquadItem(
              id: 'default',
              name: '${widget.activeAgeGroup} Squad',
              ageGroup: widget.activeAgeGroup,
              description: '',
            ),
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 12.0,
        bottom: bottomInset + (safeBottom > 0 ? safeBottom : 16.0),
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
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
          const SizedBox(height: 12.0),

          // Header Title & Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Player to Roster',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    '${activeSquad.name} (${widget.activeAgeGroup})',
                    style: const TextStyle(
                      fontSize: 13.0,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          // Tab Bar Switcher
          _buildTabBar(),
          const SizedBox(height: 16.0),

          // Selected Tab Body
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildSearchTab(activeSquad.id)
                : _buildRegisterTab(activeSquad.id, activeSquad.name),
          ),
        ],
      ),
    );
  }
}
