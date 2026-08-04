import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/type_parsers.dart';

class DynamicTestMetric {
  final String id;
  final String name;
  final String category;
  final String unit;
  final String goalDirection;
  final double targetBenchmark;
  final double initialBaseline;
  final double latestScore;
  final int targetPercent;
  final String trendText;
  final String latestTestDate;
  final String sessionName;

  DynamicTestMetric({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.goalDirection,
    required this.targetBenchmark,
    required this.initialBaseline,
    required this.latestScore,
    required this.targetPercent,
    required this.trendText,
    required this.latestTestDate,
    required this.sessionName,
  });

  factory DynamicTestMetric.fromJson(Map<String, dynamic> json) {
    return DynamicTestMetric(
      id: TypeParsers.parseString(json['id']),
      name: TypeParsers.parseString(json['name'], 'Test Metric'),
      category: TypeParsers.parseString(json['category'], 'General'),
      unit: TypeParsers.parseString(json['unit']),
      goalDirection: TypeParsers.parseString(json['goalDirection'], 'HIGHER_IS_BETTER'),
      targetBenchmark: TypeParsers.parseDouble(json['targetBenchmark']),
      initialBaseline: TypeParsers.parseDouble(json['initialBaseline']),
      latestScore: TypeParsers.parseDouble(json['latestScore']),
      targetPercent: TypeParsers.parseInt(json['targetPercent'], 100),
      trendText: TypeParsers.parseString(json['trendText'], 'Initial'),
      latestTestDate: TypeParsers.parseString(json['latestTestDate']),
      sessionName: TypeParsers.parseString(json['sessionName'], 'Evaluation'),
    );
  }
}

class StudentEvent {
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
  final String ageGroup;
  final String team;
  final String? workoutImagePath;

  StudentEvent({
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
    required this.ageGroup,
    required this.team,
    this.workoutImagePath,
  });

  factory StudentEvent.fromJson(Map<String, dynamic> json) {
    return StudentEvent(
      id: TypeParsers.parseString(json['id']),
      schoolId: TypeParsers.parseString(json['schoolId']),
      title: TypeParsers.parseString(json['title'], 'Training Session'),
      eventType: TypeParsers.parseString(json['eventType'], 'Field Session'),
      startTime: TypeParsers.parseString(json['startTime'], '00:00'),
      date: TypeParsers.parseString(json['date']),
      durationMins: TypeParsers.parseNullableInt(json['durationMins']),
      location: TypeParsers.parseString(json['location'], 'Grounds'),
      isImportant: TypeParsers.parseBool(json['isImportant']),
      completionCount: TypeParsers.parseNullableInt(json['completionCount']),
      ageGroup: TypeParsers.parseString(json['ageGroup'], 'U15'),
      team: TypeParsers.parseString(json['team']),
      workoutImagePath: json['workoutImagePath'] != null ? TypeParsers.parseString(json['workoutImagePath']) : null,
    );
  }
}

class StudentSquad {
  final String id;
  final String name;
  final String code;

  StudentSquad({required this.id, required this.name, required this.code});

  factory StudentSquad.fromJson(Map<String, dynamic> json) {
    return StudentSquad(
      id: TypeParsers.parseString(json['id']),
      name: TypeParsers.parseString(json['name']),
      code: TypeParsers.parseString(json['code']),
    );
  }
}

class StudentPortalData {
  final Map<String, dynamic> profile;
  final List<dynamic> academics;
  final Map<String, dynamic> fitness;
  final List<DynamicTestMetric> dynamicMetrics;
  final int readinessScore;
  final List<dynamic> matches;
  final List<dynamic> attendance;
  final List<StudentEvent> events;
  final List<StudentSquad> assignedSquads;

  StudentPortalData({
    required this.profile,
    required this.academics,
    required this.fitness,
    required this.dynamicMetrics,
    required this.readinessScore,
    required this.matches,
    required this.attendance,
    required this.events,
    required this.assignedSquads,
  });

  factory StudentPortalData.fromJson(Map<String, dynamic> json) {
    final profileObj = json['profile'] ?? {};
    final fitnessObj = json['fitness'] ?? {};
    final dynamicMetricsRaw = fitnessObj['dynamicMetrics'] as List<dynamic>? ?? [];
    final parsedMetrics = dynamicMetricsRaw
        .map((m) => DynamicTestMetric.fromJson(m as Map<String, dynamic>))
        .toList();

    final int parsedReadiness = (fitnessObj['readinessScore'] as num?)?.toInt() ?? 0;

    final eventsRaw = json['events'] as List<dynamic>? ?? [];
    final parsedEvents = eventsRaw
        .map((e) => StudentEvent.fromJson(e as Map<String, dynamic>))
        .toList();

    final assignedSquadsRaw = profileObj['assignedSquads'] as List<dynamic>? ?? [];
    final parsedSquads = assignedSquadsRaw
        .map((s) => StudentSquad.fromJson(s as Map<String, dynamic>))
        .toList();

    return StudentPortalData(
      profile: profileObj,
      academics: json['academics'] ?? [],
      fitness: fitnessObj,
      dynamicMetrics: parsedMetrics,
      readinessScore: parsedReadiness,
      matches: json['matches'] ?? [],
      attendance: json['attendance'] ?? [],
      events: parsedEvents,
      assignedSquads: parsedSquads,
    );
  }
}

class StudentController extends StateNotifier<AsyncValue<StudentPortalData>> {
  final ApiClient _apiClient;
  Timer? _pollingTimer;
  String? _lastSquadId;

  StudentController(this._apiClient) : super(const AsyncValue.loading()) {
    // Live automatic sync: polls database every 20 seconds (with ETag CDN edge caching for zero-cost)
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      fetchStudentData(squadId: _lastSquadId, silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchStudentData({String? squadId, bool silent = false}) async {
    _lastSquadId = squadId;
    if (!silent && state.asData?.value == null) {
      state = const AsyncValue.loading();
    }
    try {
      final queryParam = (squadId != null && squadId.isNotEmpty) ? '?squad_id=$squadId' : '';
      final response = await _apiClient.getAndCache('/api/student-portal$queryParam');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = StudentPortalData.fromJson(response.data['data']);
        state = AsyncValue.data(data);
      } else if (!silent) {
        state = AsyncValue.error(response.data['message'] ?? 'Failed to load data', StackTrace.current);
      }
    } catch (err, stack) {
      if (silent) return; // Keep existing UI intact during silent background poll
      String cleanMessage = 'Failed to load dashboard. Please try again.';
      if (err is DioException) {
        if (err.response?.data != null && err.response?.data is Map && err.response?.data['message'] != null) {
          cleanMessage = err.response?.data['message'].toString() ?? cleanMessage;
        } else if (err.type == DioExceptionType.connectionTimeout || err.type == DioExceptionType.connectionError) {
          cleanMessage = 'Network connection issue. Please check your internet connection.';
        }
      } else {
        cleanMessage = err.toString();
      }
      state = AsyncValue.error(cleanMessage, stack);
    }
  }
}

// Provider for Student Data
final studentControllerProvider = StateNotifierProvider<StudentController, AsyncValue<StudentPortalData>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return StudentController(apiClient);
});

// Provider for Active Student Selected Squad ID
final selectedStudentSquadIdProvider = StateProvider<String?>((ref) => null);
