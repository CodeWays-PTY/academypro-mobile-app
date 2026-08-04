import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';
import '../controllers/dashboard_controller.dart';

class TestEventsPage extends ConsumerStatefulWidget {
  final String ageGroup;

  const TestEventsPage({super.key, required this.ageGroup});

  static void show(BuildContext context, {String ageGroup = 'U15'}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TestEventsPage(ageGroup: ageGroup),
    );
  }

  @override
  ConsumerState<TestEventsPage> createState() => _TestEventsPageState();
}

class _TestEventsPageState extends ConsumerState<TestEventsPage> {
  // --- Shared state ---
  bool _isLoading = true;
  List<dynamic> _events = [];
  List<dynamic> _metrics = [];
  List<dynamic> _roster = [];
  Map<String, Map<String, dynamic>> _completionData = {};

  // --- Step navigation ---
  // null = events list, non-null = athletes list for that event
  dynamic _selectedEvent;

  // --- Per-event scores (cached so we don't re-fetch) ---
  // eventId -> { playerId -> { metricId -> score } }
  final Map<String, Map<String, dynamic>> _eventScoresCache = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);

      // 1. Fetch fitness test events
      final evRes = await api.getAndCache('/api/dashboard/events?event_type=Fitness Test');
      List<dynamic> events = [];
      if (evRes.statusCode == 200 && evRes.data['success'] == true) {
        events = (evRes.data['data'] as List)
            .map((e) => CoachEvent.fromJson(e))
            .where((e) {
          final t = e.eventType.toLowerCase();
          return t.contains('test') || t.contains('fitness');
        }).toList();
        events.sort((a, b) {
          final da = DateTime.tryParse(a.date) ?? DateTime(2000);
          final db = DateTime.tryParse(b.date) ?? DateTime(2000);
          return db.compareTo(da);
        });
      }

      // 2. Fetch metrics
      final mRes = await api.getAndCache('/api/test-metrics');
      List<dynamic> metrics = [];
      if (mRes.statusCode == 200 && mRes.data['success'] == true) {
        metrics = mRes.data['data'] ?? [];
      }

      // 3. Fetch roster
      final rRes = await api.getAndCache('/api/rosters/${widget.ageGroup}');
      List<dynamic> roster = [];
      if (rRes.statusCode == 200 && rRes.data['success'] == true) {
        roster = rRes.data['data']['players'] ?? [];
      }

      // 4. Compute completion per event
      final Map<String, Map<String, dynamic>> completion = {};
      for (final ev in events) {
        final eid = ev.id.toString();
        try {
          final sRes = await api.getAndCache('/api/test-logs/by-event?eventId=$eid&testDate=${ev.date}');
          if (sRes.statusCode == 200 && sRes.data['success'] == true) {
            final scoreMap = (sRes.data['data'] as Map<String, dynamic>?) ?? {};
            _eventScoresCache[eid] = scoreMap;
            int done = 0;
            for (final pid in roster.map((p) => p['id']?.toString() ?? '')) {
              final ps = scoreMap[pid] as Map<String, dynamic>?;
              if (ps != null && ps.length >= metrics.length && metrics.isNotEmpty) done++;
            }
            completion[eid] = {'completed': done, 'total': roster.length};
          } else {
            completion[eid] = {'completed': 0, 'total': roster.length};
          }
        } catch (_) {
          completion[eid] = {'completed': 0, 'total': roster.length};
        }
      }

      if (mounted) {
        setState(() {
          _events = events;
          _metrics = metrics;
          _roster = roster;
          _completionData = completion;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, title: 'Error', message: 'Failed to load test data.');
      }
    }
  }

  /// Refresh scores for a single event (after saving)
  Future<void> _refreshEventScores(String eventId, String date) async {
    try {
      final api = ref.read(apiClientProvider);
      final sRes = await api.getAndCache('/api/test-logs/by-event?eventId=$eventId&testDate=$date');
      if (sRes.statusCode == 200 && sRes.data['success'] == true) {
        final scoreMap = (sRes.data['data'] as Map<String, dynamic>?) ?? {};
        _eventScoresCache[eventId] = scoreMap;
        int done = 0;
        for (final p in _roster) {
          final pid = p['id']?.toString() ?? '';
          final ps = scoreMap[pid] as Map<String, dynamic>?;
          if (ps != null && ps.length >= _metrics.length && _metrics.isNotEmpty) done++;
        }
        if (mounted) {
          setState(() {
            _completionData[eventId] = {'completed': done, 'total': _roster.length};
          });
        }
      }
    } catch (_) {}
  }

  // ========== BUILD ==========

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          _buildHeader(),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _selectedEvent == null
                    ? _buildEventsList()
                    : _buildAthletesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    if (_selectedEvent != null) {
      // Athletes list header — with back button
      DateTime? d = DateTime.tryParse(_selectedEvent.date);
      final dateStr = d != null ? DateFormat('MMM d, yyyy').format(d) : _selectedEvent.date;
      return Padding(
        padding: const EdgeInsets.only(left: 4, right: 12, top: 8, bottom: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _selectedEvent = null),
              icon: const Icon(Icons.arrow_back, color: Color(0xFF475569)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedEvent.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(dateStr, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Color(0xFF475569)),
            ),
          ],
        ),
      );
    }

    // Events list header
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Squad Test Events', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text(widget.ageGroup, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  // ========== STEP 1: EVENTS LIST ==========

  Widget _buildEventsList() {
    if (_events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.event_busy, size: 56, color: Color(0xFF94A3B8)),
              SizedBox(height: 16),
              Text('No Test Events', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              SizedBox(height: 8),
              Text('No fitness test events found for this squad.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        final eid = event.id.toString();
        final cData = _completionData[eid] ?? {'completed': 0, 'total': 0};
        final completed = cData['completed'] as int;
        final total = cData['total'] as int;
        final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

        String statusText;
        Color statusColor;
        if (total > 0 && completed >= total) {
          statusText = 'Complete';
          statusColor = const Color(0xFF10B981);
        } else if (completed > 0) {
          statusText = 'In Progress';
          statusColor = const Color(0xFFD97706);
        } else {
          statusText = 'Not Started';
          statusColor = const Color(0xFF94A3B8);
        }

        DateTime? pd = DateTime.tryParse(event.date);
        final dateStr = pd != null ? DateFormat('EEE, MMM d, yyyy').format(pd) : event.date;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => _selectedEvent = event),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: const Border(left: BorderSide(color: Color(0xFFD97706), width: 5)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 13, color: Color(0xFF475569)),
                      const SizedBox(width: 4),
                      Text(dateStr, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, size: 13, color: Color(0xFF475569)),
                      const SizedBox(width: 4),
                      Text(event.startTime, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('$completed/$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ========== STEP 2: ATHLETES LIST ==========

  Widget _buildAthletesList() {
    if (_roster.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.group_off, size: 56, color: Color(0xFF94A3B8)),
              SizedBox(height: 16),
              Text('No Athletes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              SizedBox(height: 8),
              Text('No players on this squad roster.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
            ],
          ),
        ),
      );
    }

    final totalMetrics = _metrics.length;
    final eid = _selectedEvent.id.toString();
    final scores = _eventScoresCache[eid] ?? {};

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _roster.length,
      itemBuilder: (context, index) {
        final athlete = _roster[index];
        final pid = athlete['id']?.toString() ?? '';
        final firstName = athlete['firstName'] ?? '';
        final lastName = athlete['lastName'] ?? '';
        final position = athlete['position'] ?? '';
        final initials = ((firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '')).toUpperCase();

        final playerScores = scores[pid] as Map<String, dynamic>? ?? {};
        final scored = playerScores.length;

        IconData icon;
        Color color;
        if (totalMetrics > 0 && scored >= totalMetrics) {
          icon = Icons.check_circle;
          color = const Color(0xFF10B981);
        } else if (scored > 0) {
          icon = Icons.warning_amber_rounded;
          color = const Color(0xFFD97706);
        } else {
          icon = Icons.radio_button_unchecked;
          color = const Color(0xFF94A3B8);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () async {
              final result = await _showScoreSheet(athlete, playerScores);
              if (result == true) {
                await _refreshEventScores(eid, _selectedEvent.date);
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$firstName $lastName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                        if (position.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(position, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(icon, color: color, size: 22),
                      const SizedBox(height: 2),
                      Text('$scored/$totalMetrics', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ========== STEP 3: SCORE ENTRY SHEET ==========

  Future<bool?> _showScoreSheet(Map<String, dynamic> athlete, Map<String, dynamic> existingScores) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ScoreEntrySheet(
        athlete: athlete,
        event: _selectedEvent,
        metrics: _metrics,
        savedScores: existingScores,
      ),
    );
  }
}

// ============================================================
// SCORE ENTRY BOTTOM SHEET (self-contained inside this file)
// ============================================================

class _ScoreEntrySheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> athlete;
  final dynamic event;
  final List<dynamic> metrics;
  final Map<String, dynamic> savedScores;

  const _ScoreEntrySheet({
    required this.athlete,
    required this.event,
    required this.metrics,
    required this.savedScores,
  });

  @override
  ConsumerState<_ScoreEntrySheet> createState() => _ScoreEntrySheetState();
}

class _ScoreEntrySheetState extends ConsumerState<_ScoreEntrySheet> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final m in widget.metrics) {
      final mid = m['id']?.toString() ?? '';
      final existing = widget.savedScores[mid];
      String prefill = '';
      if (existing != null) {
        final num = double.tryParse(existing.toString());
        if (num != null && num == num.roundToDouble()) {
          prefill = num.toInt().toString();
        } else {
          prefill = existing.toString();
        }
      }
      _controllers[mid] = TextEditingController(text: prefill);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final List<Map<String, dynamic>> logs = [];
    final playerId = widget.athlete['id']?.toString() ?? '';

    _controllers.forEach((metricId, controller) {
      final text = controller.text.trim();
      if (text.isNotEmpty) {
        final val = double.tryParse(text);
        if (val != null) {
          logs.add({'playerId': playerId, 'metricId': metricId, 'score': val});
        }
      }
    });

    if (logs.isEmpty) {
      AppToast.showError(context, title: 'No Scores', message: 'Enter at least one score.');
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/api/test-logs/batch', data: {
        'eventId': widget.event.id,
        'testDate': widget.event.date,
        'sessionName': widget.event.title,
        'logs': logs,
      });

      if (!mounted) return;

      if (res.statusCode == 200 && res.data['success'] == true) {
        ref.invalidate(dashboardSummaryProvider);
        ref.invalidate(dashboardEventsProvider);
        AppToast.showSuccess(context, title: 'Saved', message: '${logs.length} score(s) recorded.');
        Navigator.pop(context, true);
      } else {
        AppToast.showError(context, title: 'Failed', message: res.data['message'] ?? 'Could not save scores.');
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, title: 'Error', message: 'Network error saving scores.');
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.athlete['firstName'] ?? '';
    final lastName = widget.athlete['lastName'] ?? '';
    final position = widget.athlete['position'] ?? '';
    final initials = ((firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '')).toUpperCase();
    final bottomPad = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$firstName $lastName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      if (position.isNotEmpty) Text(position, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Metric inputs
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              itemCount: widget.metrics.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final m = widget.metrics[index];
                final mid = m['id']?.toString() ?? '';
                final name = m['name'] ?? 'Metric';
                final unit = m['unit'] ?? '';
                final category = m['category'] ?? '';

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                          if (category.isNotEmpty || unit.isNotEmpty)
                            Text([category, unit].where((s) => s.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _controllers[mid],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: unit.isNotEmpty ? unit : '0',
                          hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.normal),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Save button
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 20),
                label: Text(_isSaving ? 'Saving...' : 'Save Scores', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF93C5FD),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
