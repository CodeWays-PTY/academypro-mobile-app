import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/type_parsers.dart';

class SquadInfo {
  final String id;
  final String name;
  final String code;

  SquadInfo({required this.id, required this.name, required this.code});

  factory SquadInfo.fromJson(Map<String, dynamic> json) {
    return SquadInfo(
      id: TypeParsers.parseString(json['id']),
      name: TypeParsers.parseString(json['name']),
      code: TypeParsers.parseString(json['code']),
    );
  }
}

class RosterPlayer {
  final String id;
  final String firstName;
  final String lastName;
  final String ageGroup;
  String position;
  final String team;
  final String status;
  final int? age;
  final List<SquadInfo> assignedSquads;

  RosterPlayer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.ageGroup,
    required this.position,
    required this.team,
    required this.status,
    this.age,
    List<SquadInfo>? assignedSquads,
  })  : assignedSquads = assignedSquads ?? [];

  factory RosterPlayer.fromJson(Map<String, dynamic> json) {
    final rawSquads = json['assignedSquads'] as List<dynamic>? ?? [];
    return RosterPlayer(
      id: TypeParsers.parseString(json['id']),
      firstName: TypeParsers.parseString(json['firstName']),
      lastName: TypeParsers.parseString(json['lastName']),
      ageGroup: TypeParsers.parseString(json['ageGroup']),
      position: TypeParsers.parseString(json['position']),
      team: TypeParsers.parseString(json['team']),
      status: TypeParsers.parseString(json['status']),
      age: TypeParsers.parseNullableInt(json['age']),
      assignedSquads: rawSquads.map((s) => SquadInfo.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

class RosterState {
  final Map<String, List<RosterPlayer>> playersByAge;
  final bool loading;
  final String? error;

  RosterState({
    required this.playersByAge,
    required this.loading,
    this.error,
  });

  factory RosterState.initial() => RosterState(
        playersByAge: {},
        loading: true,
      );

  RosterState copyWith({
    Map<String, List<RosterPlayer>>? playersByAge,
    bool? loading,
    String? error,
  }) {
    return RosterState(
      playersByAge: playersByAge ?? this.playersByAge,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class RosterNotifier extends StateNotifier<RosterState> {
  final ApiClient _apiClient;

  RosterNotifier(this._apiClient) : super(RosterState.initial());

  Future<void> fetchRoster(String ageGroup) async {
    state = state.copyWith(loading: true);
    try {
      final response = await _apiClient.getAndCache('/api/rosters/$ageGroup');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List list = response.data['data']['players'] ?? [];
        final players = list.map((x) => RosterPlayer.fromJson(x)).toList();
        
        final newMap = Map<String, List<RosterPlayer>>.from(state.playersByAge);
        newMap[ageGroup] = players;
        
        state = state.copyWith(
          playersByAge: newMap,
          loading: false,
          error: null,
        );
      } else {
        final newMap = Map<String, List<RosterPlayer>>.from(state.playersByAge);
        newMap[ageGroup] = newMap[ageGroup] ?? [];
        state = state.copyWith(playersByAge: newMap, loading: false, error: response.data?['message'] ?? 'Failed to load roster');
      }
    } catch (e) {
      debugPrint('Error fetching roster for $ageGroup: $e');
      final newMap = Map<String, List<RosterPlayer>>.from(state.playersByAge);
      newMap[ageGroup] = newMap[ageGroup] ?? [];
      state = state.copyWith(playersByAge: newMap, loading: false, error: e.toString());
      AppToast.showError(null, title: 'Network Error', message: 'Failed to load roster.');
    }
  }

  Future<bool> updatePlayerSquads(String playerId, String ageGroup, List<String> squadIds) async {
    try {
      final response = await _apiClient.post(
        '/api/players/$playerId/squads',
        data: {'squadIds': squadIds},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchRoster(ageGroup);
        return true;
      }
      AppToast.showError(null, title: 'Update Failed', message: 'Could not update squad assignments.');
      return false;
    } catch (e) {
      debugPrint('Error in updatePlayerSquads: $e');
      AppToast.showError(null, title: 'Network Failure', message: 'Failed to update player squads.');
      return false;
    }
  }

  Future<List<RosterPlayer>> fetchSchoolPlayers([String query = '']) async {
    try {
      final qParam = query.trim().isNotEmpty ? '?q=${Uri.encodeComponent(query.trim())}' : '';
      final response = await _apiClient.getAndCache('/api/school/players$qParam');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        return list.map((x) => RosterPlayer.fromJson(x)).toList();
      }
    } catch (e) {
      debugPrint('Error in fetchSchoolPlayers: $e');
      AppToast.showError(null, title: 'Network Failure', message: 'Failed to search school players.');
    }
    return [];
  }

  Future<bool> addPlayerToSquad(String playerId, String squadId, String currentAgeGroup) async {
    try {
      final response = await _apiClient.post(
        '/api/squads/$squadId/players/add',
        data: {'playerId': playerId},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchRoster(currentAgeGroup);
        return true;
      }
      AppToast.showError(null, title: 'Squad Error', message: 'Could not add player to squad.');
      return false;
    } catch (e) {
      debugPrint('Error in addPlayerToSquad: $e');
      AppToast.showError(null, title: 'Network Failure', message: 'Failed to add player to squad.');
      return false;
    }
  }

  Future<bool> removePlayerFromSquad(String playerId, String squadId, String currentAgeGroup) async {
    try {
      final response = await _apiClient.post(
        '/api/squads/$squadId/players/remove',
        data: {'playerId': playerId},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchRoster(currentAgeGroup);
        return true;
      }
      AppToast.showError(null, title: 'Squad Error', message: 'Could not remove player from squad.');
      return false;
    } catch (e) {
      debugPrint('Error in removePlayerFromSquad: $e');
      AppToast.showError(null, title: 'Network Failure', message: 'Failed to remove player from squad.');
      return false;
    }
  }

  Future<bool> registerAndAddPlayer({
    required String firstName,
    required String lastName,
    required String email,
    required String ageGroup,
    required String squadId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/players',
        data: {
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'email': email.trim(),
          'ageGroup': ageGroup,
          'squadId': squadId,
          'position': 'Athlete',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchRoster(ageGroup);
        return true;
      }
      AppToast.showError(null, title: 'Registration Error', message: response.data?['message'] ?? 'Could not register new player.');
      return false;
    } catch (e) {
      debugPrint('Error in registerAndAddPlayer: $e');
      AppToast.showError(null, title: 'Network Failure', message: 'Failed to register player.');
      return false;
    }
  }

  Future<bool> updatePlayerPosition(RosterPlayer player, String newPosition) async {
    final cleanPosition = newPosition.trim();
    if (cleanPosition.isEmpty) return false;

    final previousState = state;

    // Optimistic UI mutation
    final newMap = Map<String, List<RosterPlayer>>.from(state.playersByAge);
    final playersList = newMap[player.ageGroup] ?? [];
    
    final updatedList = playersList.map((p) {
      if (p.id == player.id) {
        return RosterPlayer(
          id: p.id,
          firstName: p.firstName,
          lastName: p.lastName,
          ageGroup: p.ageGroup,
          position: cleanPosition,
          team: p.team,
          status: p.status,
          age: p.age,
          assignedSquads: p.assignedSquads,
        );
      }
      return p;
    }).toList();

    newMap[player.ageGroup] = updatedList;
    state = state.copyWith(playersByAge: newMap);

    try {
      final response = await _apiClient.post(
        '/api/players/${player.id}/position',
        data: {'position': cleanPosition},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchRoster(player.ageGroup);
        return true;
      } else {
        state = previousState;
        AppToast.showError(null, title: 'Sync Failure', message: 'Failed to update position on server.');
        return false;
      }
    } catch (e) {
      state = previousState;
      debugPrint('Error updating position on server: $e');
      AppToast.showError(null, title: 'Network Failure', message: 'Server sync failed. Position change reverted.');
      return false;
    }
  }
}

final rosterProvider = StateNotifierProvider<RosterNotifier, RState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RosterNotifier(apiClient);
});

typedef RState = RosterState;
