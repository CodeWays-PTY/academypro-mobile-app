import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';
import '../controllers/dashboard_controller.dart';

class SinglePlayerBaselineModal extends ConsumerStatefulWidget {
  final String playerId;
  final String playerName;
  final CoachEvent? initialEvent;

  const SinglePlayerBaselineModal({
    super.key,
    required this.playerId,
    required this.playerName,
    this.initialEvent,
  });

  static Future<void> show(
    BuildContext context, {
    required String playerId,
    required String playerName,
    CoachEvent? initialEvent,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SinglePlayerBaselineModal(
        playerId: playerId,
        playerName: playerName,
        initialEvent: initialEvent,
      ),
    );
  }

  @override
  ConsumerState<SinglePlayerBaselineModal> createState() => _SinglePlayerBaselineModalState();
}

class _SinglePlayerBaselineModalState extends ConsumerState<SinglePlayerBaselineModal> {
  bool _isLoading = true;
  bool _isSaving = false;

  List<CoachEvent> _testEvents = [];
  String? _selectedEventId;

  List<dynamic> _testMetrics = [];

  // Controllers map per metric: [metricId] -> TextEditingController
  final Map<String, TextEditingController> _metricControllers = {};

  // Baseline reference values map: [metricId] -> String (e.g. "5.42")
  final Map<String, String> _previousBaselines = {};

  final _sessionController = TextEditingController(text: 'Fitness Testing Session');
  final _dateController = TextEditingController(text: DateTime.now().toString().split(' ')[0]);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _sessionController.dispose();
    _dateController.dispose();
    for (var controller in _metricControllers.values) {
      controller.dispose();
    }
    _metricControllers.clear();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);

      // 1. Fetch Events & filter strictly for Fitness Test / Test Day events, sorted by date DESC (most recent first)
      final eventsRes = await apiClient.getAndCache('/api/dashboard/events?event_type=Fitness Test');
      if (eventsRes.statusCode == 200 && eventsRes.data['success'] == true) {
        final rawEvents = (eventsRes.data['data'] as List? ?? []).map((json) {
          return CoachEvent(
            id: json['id'] ?? '',
            schoolId: json['school_id'] ?? json['schoolId'] ?? 1,
            title: json['title'] ?? 'Event',
            eventType: json['event_type'] ?? json['eventType'] ?? 'General',
            startTime: json['start_time'] ?? json['startTime'] ?? '09:00',
            date: json['date'] ?? '',
            durationMins: json['duration_mins'] ?? json['durationMins'],
            location: json['location'] ?? 'Field',
            isImportant: (json['is_important'] == 1 || json['isImportant'] == true),
            completionCount: json['completion_count'] ?? json['completionCount'],
            recurrenceRule: json['recurrence_rule'] ?? json['recurrenceRule'] ?? 'Does Not Repeat',
            workoutImagePath: json['workout_image_path'] ?? json['workoutImagePath'],
            team: json['team'] ?? json['age_group'] ?? json['ageGroup'] ?? '',
            ageGroup: json['age_group'] ?? json['ageGroup'] ?? 'U15',
          );
        }).toList();

        // Filter to Fitness Test / Test Day category, falling back to all events if no specific test events exist
        _testEvents = rawEvents.where((e) {
          final type = e.eventType.toLowerCase().trim();
          return type == 'fitness test' || type == 'test day' || type == 'fitness' || type == 'test' || type.contains('fitness') || type.contains('test');
        }).toList();

        if (_testEvents.isEmpty) {
          _testEvents = rawEvents;
        }

        if (_testEvents.isEmpty) {
          final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          _testEvents = [
            CoachEvent(
              id: 'EVT-GEN-TEST',
              schoolId: '1',
              title: 'General Fitness Testing Session',
              eventType: 'Fitness Test',
              startTime: '09:00',
              date: nowStr,
              durationMins: 60,
              location: 'High Performance Center',
              isImportant: true,
              recurrenceRule: 'Does Not Repeat',
              ageGroup: 'U15',
            )
          ];
        }

        // Sort by date DESC (most recent date first)
        _testEvents.sort((a, b) {
          final dateCmp = b.date.compareTo(a.date);
          if (dateCmp != 0) return dateCmp;
          return b.startTime.compareTo(a.startTime);
        });

        // If launched from a specific event, ensure initialEvent is present & auto-selected
        if (widget.initialEvent != null) {
          _selectedEventId = widget.initialEvent!.id;
          _sessionController.text = widget.initialEvent!.title;
          _dateController.text = widget.initialEvent!.date;
          if (!_testEvents.any((e) => e.id == widget.initialEvent!.id)) {
            _testEvents.insert(0, widget.initialEvent!);
          }
        } else if (_testEvents.isNotEmpty) {
          _selectedEventId = _testEvents.first.id;
          _sessionController.text = _testEvents.first.title;
          _dateController.text = _testEvents.first.date;
        }
      }

      // 2. Fetch Test Metrics Definitions
      final metricsRes = await apiClient.getAndCache('/api/test-metrics');
      if (metricsRes.statusCode == 200 && metricsRes.data['success'] == true) {
        _testMetrics = metricsRes.data['data'] ?? [];
      }

      // 3. Fetch Player's Previous Baseline Data
      final studentPortalRes = await apiClient.getAndCache('/api/student-portal?player_id=${widget.playerId}');
      if (studentPortalRes.statusCode == 200 && studentPortalRes.data['success'] == true) {
        final data = studentPortalRes.data['data'] ?? {};
        final dynamicMetrics = data['fitness']?['dynamicMetrics'] ?? data['dynamicMetrics'] ?? [];
        if (dynamicMetrics is List) {
          for (var m in dynamicMetrics) {
            final mId = m['id'] ?? m['metricId'] ?? m['metric_id'];
            final latestScore = m['latestScore'] ?? m['latest_score'] ?? m['score'];
            if (mId != null && latestScore != null) {
              _previousBaselines[mId.toString()] = latestScore.toString();
            }
          }
        }
      }

      // Initialize text controllers for ALL metrics (starting empty by default)
      for (var m in _testMetrics) {
        final mId = m['id'];
        _metricControllers[mId] = TextEditingController();
      }
    } catch (e) {
      debugPrint('Error loading player baseline modal data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onEventSelected(String? eventId) {
    if (eventId == null) return;
    final evt = _testEvents.firstWhere((e) => e.id == eventId, orElse: () => _testEvents.first);
    setState(() {
      _selectedEventId = evt.id;
      _sessionController.text = evt.title;
      _dateController.text = evt.date;
    });
  }

  Future<void> _handleSave() async {
    final List<Map<String, dynamic>> logs = [];

    _metricControllers.forEach((metricId, controller) {
      final text = controller.text.trim();
      if (text.isNotEmpty) {
        final val = double.tryParse(text);
        if (val != null) {
          logs.add({
            'playerId': widget.playerId,
            'metricId': metricId,
            'score': val,
          });
        }
      }
    });

    if (logs.isEmpty) {
      AppToast.showError(context, title: 'No Scores Entered', message: 'Please enter at least one test score to save.');
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final apiClient = ref.read(apiClientProvider);
      
      // Submit batch logs for this player across all entered metrics
      final response = await apiClient.post('/api/test-logs/batch', data: {
        'eventId': _selectedEventId,
        'testDate': _dateController.text.trim(),
        'sessionName': _sessionController.text.trim(),
        'logs': logs,
      });

      if (mounted) {
        setState(() => _isSaving = false);
        if (response.statusCode == 200 && response.data['success'] == true) {
          Navigator.pop(context, true);
          AppToast.showSuccess(
            context,
            title: 'Test Metrics Saved',
            message: 'Recorded ${logs.length} metric score(s) for ${widget.playerName}.',
          );
        } else {
          AppToast.showError(
            context,
            title: 'Save Failed',
            message: response.data['message'] ?? 'Could not save test scores.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.showError(context, title: 'Connection Error', message: 'Failed to record test metrics: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 16.0,
        bottom: 20.0 + bottomInset + safeBottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              width: 40.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          const SizedBox(height: 14.0),

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update Test Metrics',
                      style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      'Record test metrics for ${widget.playerName}',
                      style: const TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12.0),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20.0),
                child: Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 18.0, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // 1. EVENT & SESSION CONFIGURATION CARD
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.initialEvent != null ? 'FITNESS TEST EVENT (LOCKED)' : 'SELECT FITNESS TEST EVENT',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6.0),
                  DropdownButtonFormField<String>(
                    initialValue: (_testEvents.any((e) => e.id == _selectedEventId)) ? _selectedEventId : null,
                    isDense: true,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(14.0),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        widget.initialEvent != null ? Icons.lock_clock : Icons.event_available,
                        size: 18.0,
                        color: widget.initialEvent != null ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                      ),
                      filled: true,
                      fillColor: widget.initialEvent != null ? const Color(0xFFF1F5F9) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                    hint: const Text('Select Test Event', style: TextStyle(fontSize: 13.0)),
                    items: _testEvents.isEmpty
                        ? [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('General Fitness Testing Session', style: TextStyle(fontSize: 12.0, color: Color(0xFF0F172A))),
                            )
                          ]
                        : _testEvents.map((evt) {
                            return DropdownMenuItem<String>(
                              value: evt.id,
                              child: Text(
                                '${evt.title} (${evt.date})',
                                style: TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w600,
                                  color: widget.initialEvent != null ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                    onChanged: widget.initialEvent != null ? null : _onEventSelected,
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _sessionController,
                          style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Session Name',
                            labelStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _dateController,
                          style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Date',
                            labelStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14.0),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ENTER TEST METRIC RESULTS',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
                ),
                Text(
                  '${_testMetrics.length} Metrics Configured',
                  style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ],
            ),
            const SizedBox(height: 8.0),

            // 2. LIST ALL METRICS AS TEXT INPUT BOXES
            Expanded(
              child: _testMetrics.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14.0),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.assessment_outlined, size: 32.0, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(height: 12.0),
                            const Text(
                              'No Fitness Metrics Configured',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4.0),
                            const Text(
                              'Metrics created in Web Admin will appear here for baseline entry.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _testMetrics.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10.0),
                      itemBuilder: (context, index) {
                        final metric = _testMetrics[index];
                        final metricId = metric['id'];
                        final controller = _metricControllers[metricId];
                        final unit = metric['unit'] ?? '';
                        final prevBaseline = _previousBaselines[metricId] ?? '--';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36.0,
                                height: 36.0,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: const Icon(Icons.bolt, color: Color(0xFF2563EB), size: 20.0),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      metric['name'] ?? 'Metric',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      '${metric['category'] ?? 'Performance'} • Unit: $unit',
                                      style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    width: 110.0,
                                    child: TextFormField(
                                      controller: controller,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. ${metric['targetBenchmark'] ?? 'Score'}',
                                        hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                                        fillColor: Colors.white,
                                        filled: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3.0),
                                  // Baseline reference underneath text box as requested
                                  Text(
                                    'Prev: ${prevBaseline != '--' ? '$prevBaseline $unit' : '--'}',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12.0),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48.0,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 18.0),
                label: Text(_isSaving ? 'Saving Scores...' : 'Save Test Results', style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003EC7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
