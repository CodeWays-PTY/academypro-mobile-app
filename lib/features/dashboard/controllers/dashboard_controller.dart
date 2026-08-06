import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/type_parsers.dart';

class DashboardSummaryState {
  final int attendancePercent;
  final double teamPerformanceAvg;
  final int totalPlayers;
  final int uniReady;
  final int onTrack;
  final int atRisk;
  final int danger;
  final int flagged;
  final bool loading;
  final String? error;

  DashboardSummaryState({
    required this.attendancePercent,
    required this.teamPerformanceAvg,
    required this.totalPlayers,
    required this.uniReady,
    required this.onTrack,
    required this.atRisk,
    required this.danger,
    required this.flagged,
    required this.loading,
    this.error,
  });

  factory DashboardSummaryState.initial() => DashboardSummaryState(
        attendancePercent: 0,
        teamPerformanceAvg: 0.0,
        totalPlayers: 0,
        uniReady: 0,
        onTrack: 0,
        atRisk: 0,
        danger: 0,
        flagged: 0,
        loading: true,
      );

  DashboardSummaryState copyWith({
    int? attendancePercent,
    double? teamPerformanceAvg,
    int? totalPlayers,
    int? uniReady,
    int? onTrack,
    int? atRisk,
    int? danger,
    int? flagged,
    bool? loading,
    String? error,
  }) {
    return DashboardSummaryState(
      attendancePercent: attendancePercent ?? this.attendancePercent,
      teamPerformanceAvg: teamPerformanceAvg ?? this.teamPerformanceAvg,
      totalPlayers: totalPlayers ?? this.totalPlayers,
      uniReady: uniReady ?? this.uniReady,
      onTrack: onTrack ?? this.onTrack,
      atRisk: atRisk ?? this.atRisk,
      danger: danger ?? this.danger,
      flagged: flagged ?? this.flagged,
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}

class DashboardSummaryNotifier extends StateNotifier<DashboardSummaryState> {
  final ApiClient _apiClient;

  DashboardSummaryNotifier(this._apiClient) : super(DashboardSummaryState.initial());

  Future<void> fetchSummary({String ageGroup = 'U15', bool isUserInitiated = false}) async {
    state = state.copyWith(loading: true);
    try {
      final response = await _apiClient.getAndCache('/api/dashboard/summary?ageGroup=$ageGroup');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final kpis = data['kpis'] ?? {};

        state = state.copyWith(
          attendancePercent: data['attendancePercent'] ?? 0,
          teamPerformanceAvg: (data['teamPerformanceAvg'] as num?)?.toDouble() ?? 0.0,
          totalPlayers: kpis['totalPlayers'] ?? 0,
          uniReady: kpis['uniReady'] ?? 0,
          onTrack: kpis['onTrack'] ?? 0,
          atRisk: kpis['atRisk'] ?? 0,
          danger: kpis['danger'] ?? 0,
          flagged: kpis['flagged'] ?? 0,
          loading: false,
          error: null,
        );
      } else {
        state = state.copyWith(loading: false, error: response.data?['message'] ?? 'Failed to load summary');
      }
    } catch (e) {
      debugPrint('Error in fetchSummary: $e');
      state = state.copyWith(loading: false, error: e.toString());
      if (isUserInitiated) {
        AppToast.showError(null, title: 'Connection Issue', message: 'Could not load your dashboard. Please try again.');
      }
    }
  }
}

class FlaggedPlayer {
  final String id;
  final String name;
  final String firstName;
  final String lastName;
  final String team;
  final String position;
  final String ageGroup;
  final String reason;
  final String flagReason;
  final String flagType;
  final String severity;

  FlaggedPlayer({
    required this.id,
    required this.name,
    String? firstName,
    String? lastName,
    required this.team,
    String? position,
    String? ageGroup,
    required this.reason,
    String? flagReason,
    required this.flagType,
    String? severity,
  })  : firstName = firstName ?? (name.contains(' ') ? name.split(' ').first : name),
        lastName = lastName ?? (name.contains(' ') ? name.split(' ').sublist(1).join(' ') : ''),
        position = position ?? 'Forward',
        ageGroup = ageGroup ?? 'U15',
        flagReason = flagReason ?? reason,
        severity = severity ?? flagType;

  factory FlaggedPlayer.fromJson(Map<String, dynamic> json) {
    final fullName = TypeParsers.parseString(json['name'] ?? json['playerName']);
    return FlaggedPlayer(
      id: TypeParsers.parseString(json['id']),
      name: fullName,
      firstName: json['firstName'] != null ? TypeParsers.parseString(json['firstName']) : null,
      lastName: json['lastName'] != null ? TypeParsers.parseString(json['lastName']) : null,
      team: TypeParsers.parseString(json['team']),
      position: TypeParsers.parseString(json['position'], 'Forward'),
      ageGroup: TypeParsers.parseString(json['ageGroup'], 'U15'),
      reason: TypeParsers.parseString(json['reason'] ?? json['flagReason']),
      flagReason: json['flagReason'] != null ? TypeParsers.parseString(json['flagReason']) : null,
      flagType: TypeParsers.parseString(json['flagType'], 'atRisk'),
      severity: TypeParsers.parseString(json['severity'] ?? json['flagType'], 'atRisk'),
    );
  }
}

class DashboardFlagsNotifier extends StateNotifier<AsyncValue<List<FlaggedPlayer>>> {
  final ApiClient _apiClient;

  DashboardFlagsNotifier(this._apiClient)
      : super(const AsyncValue.loading());

  Future<void> fetchFlags({String? ageGroup}) async {
    state = const AsyncValue.loading();
    try {
      final path = ageGroup != null ? '/api/dashboard/flags?ageGroup=$ageGroup' : '/api/dashboard/flags';
      final response = await _apiClient.getAndCache(path);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        final flags = list.map((x) => FlaggedPlayer.fromJson(x)).toList();
        state = AsyncValue.data(flags);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      state = const AsyncValue.data([]);
    }
  }
}

class RisingStarPlayer {
  final String id;
  final String name;
  final String firstName;
  final String lastName;
  final String team;
  final String position;
  final String ageGroup;
  final int streakWeeks;
  final int gymConsistencyWeeks;
  final int gradeImprovement;
  final int attendancePercent;
  final int gymProgressPercent;
  final String highlights;

  RisingStarPlayer({
    required this.id,
    required this.name,
    String? firstName,
    String? lastName,
    required this.team,
    String? position,
    String? ageGroup,
    required this.streakWeeks,
    int? gymConsistencyWeeks,
    int? gradeImprovement,
    int? attendancePercent,
    int? gymProgressPercent,
    required this.highlights,
  })  : firstName = firstName ?? (name.contains(' ') ? name.split(' ').first : name),
        lastName = lastName ?? (name.contains(' ') ? name.split(' ').sublist(1).join(' ') : ''),
        position = position ?? 'Forward',
        ageGroup = ageGroup ?? 'U15',
        gymConsistencyWeeks = gymConsistencyWeeks ?? streakWeeks,
        gradeImprovement = gradeImprovement ?? AppConfig.gradeImprovementDefault,
        attendancePercent = attendancePercent ?? 0,
        gymProgressPercent = gymProgressPercent ?? 0;

  bool get isQualifiedForRisingStar => streakWeeks >= 5 || gymConsistencyWeeks >= 5;

  factory RisingStarPlayer.fromJson(Map<String, dynamic> json) {
    final fullName = TypeParsers.parseString(json['name'] ?? json['playerName']);
    return RisingStarPlayer(
      id: TypeParsers.parseString(json['id']),
      name: fullName,
      firstName: json['firstName'] != null ? TypeParsers.parseString(json['firstName']) : null,
      lastName: json['lastName'] != null ? TypeParsers.parseString(json['lastName']) : null,
      team: TypeParsers.parseString(json['team']),
      position: TypeParsers.parseString(json['position'], 'Athlete'),
      ageGroup: TypeParsers.parseString(json['ageGroup'], 'U15'),
      streakWeeks: TypeParsers.parseInt(json['streakWeeks']),
      gymConsistencyWeeks: TypeParsers.parseInt(json['gymConsistencyWeeks'] ?? json['streakWeeks']),
      gradeImprovement: TypeParsers.parseInt(json['gradeImprovement']),
      attendancePercent: TypeParsers.parseInt(json['attendancePercent']),
      gymProgressPercent: TypeParsers.parseInt(json['gymProgressPercent']),
      highlights: TypeParsers.parseString(json['highlights']),
    );
  }
}

class RisingStarsNotifier extends StateNotifier<AsyncValue<List<RisingStarPlayer>>> {
  final ApiClient _apiClient;

  RisingStarsNotifier(this._apiClient)
      : super(const AsyncValue.loading());

  Future<void> fetchStars({String? ageGroup}) async {
    state = const AsyncValue.loading();
    try {
      final path = ageGroup != null ? '/api/dashboard/rising-stars?ageGroup=$ageGroup' : '/api/dashboard/rising-stars';
      final response = await _apiClient.getAndCache(path);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        final stars = list.map((x) => RisingStarPlayer.fromJson(x)).toList();
        state = AsyncValue.data(stars);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> fetchRisingStars({String? ageGroup}) async {
    await fetchStars(ageGroup: ageGroup);
  }
}

class CoachActionItem {
  final String id;
  final String title;
  final String type;
  final String category;
  final String deadline;
  final String dateAdded;
  final bool isCompleted;
  final String? completedAt;
  final String? playerId;
  final String playerName;
  final String parentName;
  final String playerPhone;
  final String notes;

  CoachActionItem({
    required this.id,
    required this.title,
    required this.type,
    String? category,
    required this.deadline,
    String? dateAdded,
    this.isCompleted = false,
    this.completedAt,
    this.playerId,
    this.playerName = '',
    this.parentName = '',
    this.playerPhone = '',
    this.notes = 'Follow up required with coaching staff.',
  })  : category = category ?? type,
        dateAdded = dateAdded ?? 'Today';

  CoachActionItem copyWith({
    String? id,
    String? title,
    String? type,
    String? category,
    String? deadline,
    String? dateAdded,
    bool? isCompleted,
    String? completedAt,
    String? playerId,
    String? playerName,
    String? parentName,
    String? playerPhone,
    String? notes,
  }) {
    return CoachActionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      category: category ?? this.category,
      deadline: deadline ?? this.deadline,
      dateAdded: dateAdded ?? this.dateAdded,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      parentName: parentName ?? this.parentName,
      playerPhone: playerPhone ?? this.playerPhone,
      notes: notes ?? this.notes,
    );
  }
}

class CoachActionNotifier extends StateNotifier<List<CoachActionItem>> {
  final ApiClient _apiClient;

  CoachActionNotifier(this._apiClient) : super([]) {
    fetchActions();
  }

  Future<void> fetchActions({bool isUserInitiated = false}) async {
    try {
      final res = await _apiClient.getAndCache('/api/dashboard/actions');
      if (res.statusCode == 200 && res.data != null && res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        const twentyFourHoursMs = 24 * 60 * 60 * 1000;

        final items = <CoachActionItem>[];
        for (final x in list) {
          final isDone = x['isCompleted'] == true;
          final completedAtStr = x['completedAt']?.toString();
          if (isDone && completedAtStr != null && completedAtStr.isNotEmpty) {
            final completedDt = DateTime.tryParse(completedAtStr);
            if (completedDt != null && (nowMs - completedDt.millisecondsSinceEpoch) >= twentyFourHoursMs) {
              continue; // Skip completed actions older than 24 hours (1 day)
            }
          }

          items.add(CoachActionItem(
            id: x['id'].toString(),
            title: x['title'] ?? '',
            type: x['type'] ?? 'General',
            category: x['category'] ?? 'General',
            deadline: x['deadline'] ?? 'Today',
            dateAdded: x['dateAdded'] ?? 'Today',
            isCompleted: isDone,
            completedAt: completedAtStr,
            playerId: x['playerId'],
            playerName: x['playerName'] ?? '',
            parentName: x['parentName'] ?? '',
            playerPhone: x['playerPhone'] ?? '',
            notes: x['notes'] ?? 'Follow up required with coaching staff.',
          ));
        }
        state = items;
      }
    } catch (e) {
      debugPrint('Error in fetchActions: $e');
      if (isUserInitiated) {
        AppToast.showError(null, title: 'Connection Issue', message: 'Could not load your action plans. Please try again.');
      }
    }
  }

  Future<void> addAction({
    String? playerId,
    String playerName = '',
    required String title,
    String category = 'General',
    String type = 'General',
    String deadline = 'Today, 17:00',
  }) async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newItem = CoachActionItem(
      id: newId,
      title: title,
      type: type,
      category: category,
      deadline: deadline,
      playerId: playerId,
      playerName: playerName,
      isCompleted: false,
    );
    final previousState = state;
    state = [newItem, ...previousState];

    try {
      final res = await _apiClient.post('/api/dashboard/actions', data: {
        'id': newId,
        'title': title,
        'type': type,
        'category': category,
        'deadline': deadline,
        'playerId': playerId,
        'playerName': playerName,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        await fetchActions();
      } else {
        state = previousState;
        AppToast.showError(null, title: 'Save Failed', message: 'Could not save the action plan. Please try again.');
      }
    } catch (e) {
      state = previousState;
      debugPrint('Error in addAction: $e');
      AppToast.showError(null, title: 'Connection Issue', message: 'Could not add the action plan. Please check your connection.');
    }
  }

  Future<void> toggleAction(String actionId) async {
    final previousState = state;
    state = state.map((item) {
      if (item.id == actionId) {
        return item.copyWith(isCompleted: !item.isCompleted);
      }
      return item;
    }).toList();

    try {
      final res = await _apiClient.post('/api/dashboard/actions/$actionId/toggle');
      if (res.statusCode != 200 && res.statusCode != 201) {
        state = previousState;
        AppToast.showError(null, title: 'Update Failed', message: 'Could not update the action status. Please try again.');
      }
    } catch (e) {
      state = previousState;
      debugPrint('Error in toggleAction: $e');
      AppToast.showError(null, title: 'Connection Issue', message: 'Could not update the action. Please check your connection.');
    }
  }
}

class SquadItem {
  final String id;
  final String name;
  final String ageGroup;
  final String description;

  SquadItem({
    required this.id,
    required this.name,
    required this.ageGroup,
    this.description = '',
  });

  factory SquadItem.fromJson(Map<String, dynamic> json) {
    return SquadItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['title'] ?? '',
      ageGroup: json['ageGroup'] ?? json['code'] ?? json['age_group'] ?? 'U15',
      description: json['description'] ?? '',
    );
  }
}

class SquadsNotifier extends StateNotifier<List<SquadItem>> {
  final ApiClient _apiClient;

  SquadsNotifier(this._apiClient) : super([]) {
    fetchSquads();
  }

  Future<void> _updateHiveCache(List<SquadItem> squads) async {
    final jsonList = squads.map((s) => {
      'id': s.id,
      'name': s.name,
      'ageGroup': s.ageGroup,
      'description': s.description,
    }).toList();
    await LocalStorage.cacheData('/api/squads', jsonList);
  }

  Future<void> fetchSquads() async {
    final currentSquads = state;
    try {
      final res = await _apiClient.getAndCache('/api/squads');
      if (res.statusCode == 200 && res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        final fetchedSquads = list.map((x) => SquadItem.fromJson(x)).toList();

        final Map<String, SquadItem> mergedMap = {};
        for (var s in fetchedSquads) {
          mergedMap[s.ageGroup.toUpperCase()] = s;
        }
        for (var s in currentSquads) {
          if (!mergedMap.containsKey(s.ageGroup.toUpperCase())) {
            mergedMap[s.ageGroup.toUpperCase()] = s;
          }
        }

        final allSquadItem = SquadItem(id: 'all', name: 'All Managed Squads', ageGroup: 'All');
        final finalSquads = [allSquadItem, ...mergedMap.values.where((s) => s.ageGroup != 'ALL' && s.ageGroup != 'All')];
        state = finalSquads;
        await _updateHiveCache(finalSquads);
        return;
      }
    } catch (e) {
      debugPrint('Error in fetchSquads: $e');
    }

    if (state.isEmpty) {
      final cachedRaw = LocalStorage.getCachedData('/api/squads');
      if (cachedRaw is List && cachedRaw.isNotEmpty) {
        final cachedItems = cachedRaw.map((x) => SquadItem.fromJson(Map<String, dynamic>.from(x))).toList();
        final allSquadItem = SquadItem(id: 'all', name: 'All Managed Squads', ageGroup: 'All');
        state = [allSquadItem, ...cachedItems.where((s) => s.ageGroup != 'ALL' && s.ageGroup != 'All')];
      } else {
        state = [SquadItem(id: 'all', name: 'All Managed Squads', ageGroup: 'All')];
      }
    }
  }

  Future<SquadItem> createSquad({
    required String name,
    required String ageGroup,
    String description = '',
  }) async {
    final newId = 'sq-${DateTime.now().millisecondsSinceEpoch}';
    final formattedAge = ageGroup.trim().toUpperCase();
    final newSquad = SquadItem(
      id: newId,
      name: name.trim(),
      ageGroup: formattedAge,
      description: description,
    );

    final updatedList = [...state.where((s) => s.ageGroup.toUpperCase() != formattedAge), newSquad];
    state = updatedList;
    await _updateHiveCache(updatedList);

    try {
      await _apiClient.post('/api/squads', data: {
        'id': newId,
        'name': name.trim(),
        'ageGroup': formattedAge,
        'description': description,
      });
    } catch (e) {
      debugPrint('Error in createSquad: $e');
      AppToast.showError(null, title: 'Connection Issue', message: 'Could not create the squad. Please check your connection.');
    }

    return newSquad;
  }
}

// Providers
final squadsProvider = StateNotifierProvider<SquadsNotifier, List<SquadItem>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SquadsNotifier(apiClient);
});

final selectedAgeGroupProvider = StateProvider<String>((ref) {
  final squads = ref.watch(squadsProvider);
  final cached = LocalStorage.getCachedData('selected_age_group');
  if (cached is String && cached.isNotEmpty && cached != 'None' && squads.any((s) => s.ageGroup == cached)) {
    return cached;
  }
  return 'All';
});

final dashboardTabProvider = StateProvider<int>((ref) => 0);

final dashboardSummaryProvider = StateNotifierProvider<DashboardSummaryNotifier, DashboardSummaryState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DashboardSummaryNotifier(apiClient);
});

final dashboardFlagsProvider = StateNotifierProvider<DashboardFlagsNotifier, AsyncValue<List<FlaggedPlayer>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DashboardFlagsNotifier(apiClient);
});

final risingStarsProvider = StateNotifierProvider<RisingStarsNotifier, AsyncValue<List<RisingStarPlayer>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RisingStarsNotifier(apiClient);
});

final coachActionProvider = StateNotifierProvider<CoachActionNotifier, List<CoachActionItem>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CoachActionNotifier(apiClient);
});

class CoachEvent {
  final String id;
  final String schoolId;
  final String title;
  final String eventType;
  final String startTime;
  final String date;
  final int? durationMins;
  final String location;
  final bool isImportant;
  final int? completionCount;
  final String recurrenceRule;
  final String? workoutImagePath;
  final String team;
  final String ageGroup;

  CoachEvent({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.eventType,
    required this.startTime,
    required this.date,
    this.durationMins,
    required this.location,
    required this.isImportant,
    this.completionCount,
    this.recurrenceRule = 'Does Not Repeat',
    this.workoutImagePath,
    this.team = '',
    this.ageGroup = 'U15',
  });

  CoachEvent copyWith({
    String? id,
    String? schoolId,
    String? title,
    String? eventType,
    String? startTime,
    String? date,
    int? durationMins,
    String? location,
    bool? isImportant,
    int? completionCount,
    String? recurrenceRule,
    String? workoutImagePath,
    String? team,
    String? ageGroup,
  }) {
    return CoachEvent(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      title: title ?? this.title,
      eventType: eventType ?? this.eventType,
      startTime: startTime ?? this.startTime,
      date: date ?? this.date,
      durationMins: durationMins ?? this.durationMins,
      location: location ?? this.location,
      isImportant: isImportant ?? this.isImportant,
      completionCount: completionCount ?? this.completionCount,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      workoutImagePath: workoutImagePath ?? this.workoutImagePath,
      team: team ?? this.team,
      ageGroup: ageGroup ?? this.ageGroup,
    );
  }

  factory CoachEvent.fromJson(Map<String, dynamic> json) {
    return CoachEvent(
      id: json['id'] != null ? json['id'].toString() : 'EVT-${DateTime.now().millisecondsSinceEpoch}',
      schoolId: TypeParsers.parseString(json['schoolId']),
      title: TypeParsers.parseString(json['title']),
      eventType: TypeParsers.parseString(json['eventType'], 'Field'),
      startTime: TypeParsers.parseString(json['startTime']),
      date: TypeParsers.parseString(json['date']),
      durationMins: TypeParsers.parseNullableInt(json['durationMins']),
      location: TypeParsers.parseString(json['location']),
      isImportant: TypeParsers.parseBool(json['isImportant']),
      completionCount: TypeParsers.parseNullableInt(json['completionCount']),
      recurrenceRule: TypeParsers.parseString(json['recurrenceRule'], 'Does Not Repeat'),
      workoutImagePath: json['workoutImagePath'] != null ? TypeParsers.parseString(json['workoutImagePath']) : (json['workoutAttachmentName'] != null ? TypeParsers.parseString(json['workoutAttachmentName']) : null),
      team: TypeParsers.parseString(json['team'] ?? json['ageGroup'] ?? json['age_group']),
      ageGroup: TypeParsers.parseString(json['ageGroup'] ?? json['age_group'], 'U15'),
    );
  }
}

class DashboardEventsNotifier extends StateNotifier<AsyncValue<List<CoachEvent>>> {
  final ApiClient _apiClient;
  final Ref _ref;
  Timer? _pollingTimer;

  DashboardEventsNotifier(this._apiClient, this._ref)
      : super(const AsyncValue.loading()) {
    fetchEvents();
    // Live automatic sync: polls database every 20 seconds (with ETag CDN edge caching for zero-cost)
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      fetchEvents(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateHiveCache(List<CoachEvent> events, String? ageGroup) async {
    final jsonList = events.map((e) => {
      'id': e.id,
      'schoolId': e.schoolId,
      'title': e.title,
      'eventType': e.eventType,
      'startTime': e.startTime,
      'date': e.date,
      'durationMins': e.durationMins,
      'location': e.location,
      'isImportant': e.isImportant,
      'recurrenceRule': e.recurrenceRule,
      'workoutImagePath': e.workoutImagePath,
      'team': e.team,
      'ageGroup': e.ageGroup,
    }).toList();

    await LocalStorage.cacheData('/api/dashboard/events', jsonList);
    await LocalStorage.cacheData('/api/dashboard/events{}', jsonList);
    if (ageGroup != null) {
      await LocalStorage.cacheData('/api/dashboard/events?ageGroup=$ageGroup', jsonList);
    }
  }

  Future<void> fetchEvents({String? ageGroup, bool silent = false}) async {
    final currentEvents = state.asData?.value ?? [];
    if (currentEvents.isEmpty && !silent) {
      state = const AsyncValue.loading();
    }
    try {
      final query = ageGroup != null ? '?ageGroup=$ageGroup' : '';
      final response = await _apiClient.getAndCache('/api/dashboard/events$query');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        final fetchedEvents = list.map((x) => CoachEvent.fromJson(x)).toList();

        final Map<String, CoachEvent> mergedMap = {};
        for (var e in fetchedEvents) {
          mergedMap[e.id.toString()] = e;
        }
        for (var e in currentEvents) {
          if (!mergedMap.containsKey(e.id.toString())) {
            mergedMap[e.id.toString()] = e;
          }
        }

        final finalEvents = mergedMap.values.toList();
        state = AsyncValue.data(finalEvents);
        await _updateHiveCache(finalEvents, ageGroup);
      } else if (currentEvents.isNotEmpty) {
        state = AsyncValue.data(currentEvents);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      if (currentEvents.isNotEmpty) {
        state = AsyncValue.data(currentEvents);
      } else {
        state = const AsyncValue.data([]);
      }
    }
  }

  Future<bool> createEvent({
    required String title,
    required String eventType,
    required String startTime,
    required String date,
    required String location,
    int? durationMins,
    bool isImportant = false,
    String recurrenceRule = 'Does Not Repeat',
    String? workoutImagePath,
    String? ageGroup,
    String? team,
  }) async {
    final String activeAge = (ageGroup != null && ageGroup.isNotEmpty)
        ? ageGroup
        : (_ref.read(selectedAgeGroupProvider) ?? '');
    final String assignedTeam = (team != null && team.isNotEmpty) ? team : activeAge;
    final eventId = 'EVT-${DateTime.now().millisecondsSinceEpoch}';

    // Strict client-side validation prior to network dispatch
    if (title.trim().isEmpty || location.trim().isEmpty || startTime.trim().isEmpty || date.trim().isEmpty) {
      debugPrint('[Create Event Error] Missing required fields in client payload.');
      return false;
    }

    final currentList = state.asData?.value ?? [];

    try {
      final res = await _apiClient.post('/api/dashboard/events', data: {
        'id': eventId,
        'title': title.trim(),
        'eventType': eventType.trim(),
        'startTime': startTime.trim(),
        'date': date.trim(),
        'location': location.trim(),
        'durationMins': durationMins,
        'isImportant': isImportant,
        'recurrenceRule': recurrenceRule,
        'workoutImagePath': workoutImagePath,
        'ageGroup': activeAge,
        'team': assignedTeam,
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        final newEvent = CoachEvent(
          id: eventId,
          schoolId: res.data?['data']?['schoolId'] ?? '',
          title: title.trim(),
          eventType: eventType.trim(),
          startTime: startTime.trim(),
          date: date.trim(),
          durationMins: durationMins,
          location: location.trim(),
          isImportant: isImportant,
          recurrenceRule: recurrenceRule,
          workoutImagePath: workoutImagePath,
          team: assignedTeam,
          ageGroup: activeAge,
        );

        final updatedList = [newEvent, ...currentList];
        state = AsyncValue.data(updatedList);
        await _updateHiveCache(updatedList, activeAge);
        await fetchEvents(ageGroup: activeAge);
        return true;
      } else {
        debugPrint('[Create Event Error] Backend rejected creation: ${res.data?['message']} (HTTP ${res.statusCode})');
        return false;
      }
    } catch (e) {
      debugPrint('[Create Event Error] Network failure or API exception saving to database: $e');
      return false;
    }
  }

  Future<bool> updateEvent(CoachEvent event) async {
    final currentList = state.asData?.value ?? [];

    try {
      final res = await _apiClient.post('/api/dashboard/events/${event.id}', data: {
        'title': event.title.trim(),
        'eventType': event.eventType.trim(),
        'startTime': event.startTime.trim(),
        'date': event.date.trim(),
        'location': event.location.trim(),
        'durationMins': event.durationMins,
        'isImportant': event.isImportant,
        'recurrenceRule': event.recurrenceRule,
        'workoutImagePath': event.workoutImagePath,
        'ageGroup': event.ageGroup,
        'team': event.team,
      });

      if ((res.statusCode == 200 || res.statusCode == 201) && res.data?['success'] != false) {
        final updatedList = currentList.map((e) => e.id.toString() == event.id.toString() ? event : e).toList();
        state = AsyncValue.data(updatedList);
        await _updateHiveCache(updatedList, event.ageGroup);
        await fetchEvents(ageGroup: event.ageGroup);
        return true;
      } else {
        debugPrint('[Update Event Error] Backend rejected update: ${res.data?['message']} (HTTP ${res.statusCode})');
        return false;
      }
    } catch (e) {
      debugPrint('[Update Event Error] Exception updating event: $e');
      return false;
    }
  }

  Future<bool> deleteEvent(dynamic eventId) async {
    final targetIdStr = eventId.toString();
    final currentList = state.asData?.value ?? [];

    try {
      final res = await _apiClient.post('/api/dashboard/events/$targetIdStr/delete');
      if (res.statusCode == 200 || res.statusCode == 201) {
        final updatedList = currentList.where((e) => e.id.toString() != targetIdStr).toList();
        state = AsyncValue.data(updatedList);
        await _updateHiveCache(updatedList, null);
        return true;
      } else {
        debugPrint('[Delete Event Error] Backend rejected deletion: ${res.data?['message']} (HTTP ${res.statusCode})');
        return false;
      }
    } catch (e) {
      debugPrint('[Delete Event Error] Exception deleting event: $e');
      return false;
    }
  }
}

final dashboardEventsProvider = StateNotifierProvider<DashboardEventsNotifier, AsyncValue<List<CoachEvent>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DashboardEventsNotifier(apiClient, ref);
});
