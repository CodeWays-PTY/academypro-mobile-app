import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import 'roster_controller.dart';
import 'dashboard_controller.dart';

class CheckInPlayerRecord {
  final RosterPlayer player;
  final bool isCheckedIn;
  final DateTime? checkInTime;

  CheckInPlayerRecord({
    required this.player,
    required this.isCheckedIn,
    this.checkInTime,
  });

  CheckInPlayerRecord copyWith({
    bool? isCheckedIn,
    DateTime? checkInTime,
  }) {
    return CheckInPlayerRecord(
      player: player,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      checkInTime: checkInTime ?? this.checkInTime,
    );
  }
}

class CheckInScanResult {
  final bool success;
  final String message;
  final RosterPlayer? player;
  final bool isDuplicate;

  CheckInScanResult({
    required this.success,
    required this.message,
    this.player,
    this.isDuplicate = false,
  });
}

class CheckInState {
  final String activeAgeGroup;
  final String sessionType;
  final CoachEvent? selectedEvent;
  final Map<String, CheckInPlayerRecord> playerRecords;
  final bool loading;
  final String? error;
  final CheckInScanResult? lastScanResult;

  CheckInState({
    required this.activeAgeGroup,
    required this.sessionType,
    this.selectedEvent,
    required this.playerRecords,
    required this.loading,
    this.error,
    this.lastScanResult,
  });

  factory CheckInState.initial() => CheckInState(
        activeAgeGroup: 'U15',
        sessionType: 'Field Practice',
        selectedEvent: null,
        playerRecords: {},
        loading: false,
      );

  CheckInState copyWith({
    String? activeAgeGroup,
    String? sessionType,
    CoachEvent? selectedEvent,
    bool clearSelectedEvent = false,
    Map<String, CheckInPlayerRecord>? playerRecords,
    bool? loading,
    String? error,
    CheckInScanResult? lastScanResult,
  }) {
    return CheckInState(
      activeAgeGroup: activeAgeGroup ?? this.activeAgeGroup,
      sessionType: sessionType ?? this.sessionType,
      selectedEvent: clearSelectedEvent ? null : (selectedEvent ?? this.selectedEvent),
      playerRecords: playerRecords ?? this.playerRecords,
      loading: loading ?? this.loading,
      error: error,
      lastScanResult: lastScanResult ?? this.lastScanResult,
    );
  }

  int get totalCount => playerRecords.length;
  int get checkedInCount => playerRecords.values.where((r) => r.isCheckedIn).length;
  double get progressPercentage => totalCount > 0 ? (checkedInCount / totalCount) : 0.0;
}

class CheckInNotifier extends StateNotifier<CheckInState> {
  final ApiClient _apiClient;
  final Ref _ref;

  CheckInNotifier(this._apiClient, this._ref) : super(CheckInState.initial());

  void initRoster(String ageGroup, List<RosterPlayer> roster) {
    final newMap = <String, CheckInPlayerRecord>{};
    for (final player in roster) {
      final existing = state.playerRecords[player.id];
      newMap[player.id] = CheckInPlayerRecord(
        player: player,
        isCheckedIn: existing?.isCheckedIn ?? false,
        checkInTime: existing?.checkInTime,
      );
    }
    state = state.copyWith(
      activeAgeGroup: ageGroup,
      playerRecords: newMap,
      loading: false,
    );
  }

  void clearSelectedEvent() {
    state = state.copyWith(clearSelectedEvent: true);
  }

  void changeAgeGroup(String ageGroup, List<RosterPlayer> roster) {
    initRoster(ageGroup, roster);
    if (state.selectedEvent != null) {
      final currentEvent = state.selectedEvent!;
      final matchesNewAge = ageGroup == 'All' ||
          currentEvent.ageGroup.toLowerCase() == ageGroup.toLowerCase() ||
          currentEvent.team.toLowerCase().contains(ageGroup.toLowerCase());
      if (!matchesNewAge) {
        clearSelectedEvent();
      }
    }
  }


  Future<void> selectEvent(CoachEvent event) async {
    final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (event.date.compareTo(nowStr) < 0) {
      // Past event check-in is disabled
      return;
    }

    final sessionType = event.eventType == 'Field Session'
        ? 'Field Practice'
        : (event.eventType == 'Gym Session' ? 'Gym Session' : 'Match Session');

    final resetRecords = <String, CheckInPlayerRecord>{};
    state.playerRecords.forEach((id, record) {
      resetRecords[id] = CheckInPlayerRecord(
        player: record.player,
        isCheckedIn: false,
        checkInTime: null,
      );
    });

    state = state.copyWith(
      selectedEvent: event,
      sessionType: sessionType,
      playerRecords: resetRecords,
    );

    await fetchEventAttendance(event.id);
  }

  Future<void> fetchEventAttendance(String eventId) async {
    try {
      final res = await _apiClient.getAndCache('/api/dashboard/events/$eventId/attendance');
      if (res.statusCode == 200 && res.data['success'] == true) {
        final List<dynamic> checkedInIds = res.data['data']['checkedInPlayerIds'] ?? [];
        final checkedInSet = Set<String>.from(checkedInIds.map((e) => e.toString()));

        final updatedRecords = <String, CheckInPlayerRecord>{};
        state.playerRecords.forEach((id, record) {
          final isChecked = checkedInSet.contains(id);
          updatedRecords[id] = CheckInPlayerRecord(
            player: record.player,
            isCheckedIn: isChecked,
            checkInTime: isChecked ? (record.checkInTime ?? DateTime.now()) : null,
          );
        });

        state = state.copyWith(playerRecords: updatedRecords);
      }
    } catch (_) {}
  }

  CheckInScanResult toggleCheckIn(String playerId) {
    final record = state.playerRecords[playerId];
    if (record == null) {
      return CheckInScanResult(success: false, message: 'Player not found on roster');
    }

    final newStatus = !record.isCheckedIn;
    final now = DateTime.now();
    final updatedMap = Map<String, CheckInPlayerRecord>.from(state.playerRecords);

    updatedMap[playerId] = record.copyWith(
      isCheckedIn: newStatus,
      checkInTime: newStatus ? now : null,
    );

    final playerName = '${record.player.firstName} ${record.player.lastName}';
    final result = CheckInScanResult(
      success: true,
      message: newStatus ? '$playerName checked in successfully' : '$playerName check-in cancelled',
      player: record.player,
    );

    state = state.copyWith(
      playerRecords: updatedMap,
      lastScanResult: result,
    );

    HapticFeedback.lightImpact();
    return result;
  }

  /// Toggle + immediately save to API (fire-and-forget)
  Future<CheckInScanResult> toggleAndSaveCheckIn(String playerId) async {
    final result = toggleCheckIn(playerId);
    if (!result.success || state.selectedEvent == null) return result;

    // Fire-and-forget: save this individual check-in to the server
    try {
      final checkedInIds = state.playerRecords.values
          .where((r) => r.isCheckedIn)
          .map((r) => r.player.id)
          .toList();

      final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await _apiClient.post('/api/dashboard/checkin', data: {
        'eventId': state.selectedEvent?.id,
        'eventTitle': state.selectedEvent?.title,
        'sessionType': state.selectedEvent?.eventType ?? (state.sessionType == 'Field Practice' ? 'Field' : 'Gym'),
        'date': state.selectedEvent?.date ?? nowStr,
        'ageGroup': state.activeAgeGroup,
        'checkedInPlayerIds': checkedInIds,
      });
      // Silently refresh dashboard summary
      _ref.read(dashboardSummaryProvider.notifier).fetchSummary(ageGroup: state.activeAgeGroup);
    } catch (_) {
      // Silent fail — the toggle is already applied locally
    }

    return result;
  }

  CheckInScanResult processQRScan(String rawQrData) {
    String cleanId = rawQrData.trim();
    if (cleanId.contains('"playerId"')) {
      final match = RegExp(r'"playerId"\s*:\s*"([^"]+)"').firstMatch(cleanId);
      if (match != null) {
        cleanId = match.group(1) ?? cleanId;
      }
    }

    final record = state.playerRecords[cleanId];
    if (record == null) {
      final match = state.playerRecords.values.firstWhere(
        (r) => r.player.id.toLowerCase() == cleanId.toLowerCase(),
        orElse: () => CheckInPlayerRecord(
          player: RosterPlayer(
            id: cleanId,
            firstName: 'Athlete',
            lastName: '(#$cleanId)',
            ageGroup: state.activeAgeGroup,
            position: '',
            team: '',
            status: 'Active',
          ),
          isCheckedIn: false,
        ),
      );

      if (!state.playerRecords.containsKey(match.player.id)) {
        HapticFeedback.vibrate();
        final res = CheckInScanResult(
          success: false,
          message: 'Unknown QR Code: $cleanId',
        );
        state = state.copyWith(lastScanResult: res);
        return res;
      }
      cleanId = match.player.id;
    }

    final target = state.playerRecords[cleanId]!;
    if (target.isCheckedIn) {
      HapticFeedback.selectionClick();
      final res = CheckInScanResult(
        success: true,
        isDuplicate: true,
        message: '${target.player.firstName} ${target.player.lastName} is already checked in',
        player: target.player,
      );
      state = state.copyWith(lastScanResult: res);
      return res;
    }

    final now = DateTime.now();
    final updatedMap = Map<String, CheckInPlayerRecord>.from(state.playerRecords);
    updatedMap[cleanId] = target.copyWith(
      isCheckedIn: true,
      checkInTime: now,
    );

    HapticFeedback.mediumImpact();
    final playerName = '${target.player.firstName} ${target.player.lastName}';
    final res = CheckInScanResult(
      success: true,
      isDuplicate: false,
      message: 'CHECKED IN: $playerName',
      player: target.player,
    );

    state = state.copyWith(
      playerRecords: updatedMap,
      lastScanResult: res,
    );

    return res;
  }


  Future<bool> submitAttendance() async {
    final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final eventDate = state.selectedEvent?.date ?? nowStr;

    if (eventDate.compareTo(nowStr) < 0) {
      state = state.copyWith(
        loading: false,
        error: 'Cannot submit check-in for past events. Check-in is closed.',
      );
      return false;
    }

    state = state.copyWith(loading: true);
    try {
      final checkedInIds = state.playerRecords.values
          .where((r) => r.isCheckedIn)
          .map((r) => r.player.id)
          .toList();

      final payload = {
        'eventId': state.selectedEvent?.id,
        'eventTitle': state.selectedEvent?.title,
        'sessionType': state.selectedEvent?.eventType ?? (state.sessionType == 'Field Practice' ? 'Field' : 'Gym'),
        'date': eventDate,
        'ageGroup': state.activeAgeGroup,
        'checkedInPlayerIds': checkedInIds,
      };

      final res = await _apiClient.post('/api/dashboard/checkin', data: payload);
      state = state.copyWith(loading: false);

      if (res.statusCode == 200 || res.statusCode == 201) {
        // Refresh dashboard summary KPI attendance percentage
        _ref.read(dashboardSummaryProvider.notifier).fetchSummary(ageGroup: state.activeAgeGroup);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Failed to submit attendance');
      return false;
    }
  }
}

final checkInProvider = StateNotifierProvider<CheckInNotifier, CheckInState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CheckInNotifier(apiClient, ref);
});
