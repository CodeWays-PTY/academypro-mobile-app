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
  bool _isLoading = true;
  List<dynamic> _events = [];
  List<dynamic> _metrics = [];
  List<dynamic> _roster = [];
  Map<String, Map<String, dynamic>> _completionData = {};
  dynamic _selectedEvent;
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
      final mRes = await api.getAndCache('/api/test-metrics');
      List<dynamic> metrics = [];
      if (mRes.statusCode == 200 && mRes.data['success'] == true) {
        metrics = mRes.data['data'] ?? [];
      }
      final rRes = await api.getAndCache('/api/rosters/${widget.ageGroup}');
      List<dynamic> roster = [];
      if (rRes.statusCode == 200 && rRes.data['success'] == true) {
        roster = rRes.data['data']['players'] ?? [];
      }
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

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 3))
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _selectedEvent == null ? _buildEventsList() : _buildAthletesList(),
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== HEADER ====================

  Widget _buildHeader() {
    if (_selectedEvent != null) {
      final eid = _selectedEvent.id.toString();
      final cData = _completionData[eid] ?? {'completed': 0, 'total': 0};
      final completed = cData['completed'] as int;
      final total = cData['total'] as int;
      final pct = total > 0 ? ((completed / total) * 100).round() : 0;
      DateTime? d = DateTime.tryParse(_selectedEvent.date);
      final dateStr = d != null ? DateFormat('EEEE, MMM d').format(d) : _selectedEvent.date;

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E40AF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _headerIconBtn(Icons.arrow_back_ios_new, () => setState(() => _selectedEvent = null)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedEvent.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                SizedBox(
                  width: 46, height: 46,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0,
                        strokeWidth: 3.5,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                      ),
                      Text('$pct%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _headerIconBtn(Icons.close, () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _chip(Icons.people_alt_outlined, '${_roster.length} Athletes'),
                const SizedBox(width: 6),
                _chip(Icons.analytics_outlined, '${_metrics.length} Metrics'),
                const SizedBox(width: 6),
                _chip(Icons.check_circle_outline, '$completed/$total Done'),
              ],
            ),
          ],
        ),
      );
    }

    // Events header
    final doneCount = _completionData.values.where((c) {
      final comp = c['completed'] as int? ?? 0;
      final tot = c['total'] as int? ?? 0;
      return tot > 0 && comp >= tot;
    }).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E40AF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.speed_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fitness Testing', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.3)),
                const SizedBox(height: 3),
                Text('${widget.ageGroup} · ${_events.length} events · $doneCount complete',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
          _headerIconBtn(Icons.close, () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _headerIconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85)), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  // ==================== EVENTS LIST ====================

  Widget _buildEventsList() {
    if (_events.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Color(0xFFE2E8F0), shape: BoxShape.circle),
              child: const Icon(Icons.event_busy_rounded, size: 36, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text('No Test Events', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            const Text('Create a fitness test event first.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey('events'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _events.length,
      itemBuilder: (context, i) {
        final ev = _events[i];
        final eid = ev.id.toString();
        final cData = _completionData[eid] ?? {'completed': 0, 'total': 0};
        final completed = cData['completed'] as int;
        final total = cData['total'] as int;
        final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
        final pct = (progress * 100).round();

        Color accent;
        String label;
        IconData icon;
        if (total > 0 && completed >= total) {
          accent = const Color(0xFF10B981);
          label = 'Complete';
          icon = Icons.check_circle_rounded;
        } else if (completed > 0) {
          accent = const Color(0xFFF59E0B);
          label = 'In Progress';
          icon = Icons.timelapse_rounded;
        } else {
          accent = const Color(0xFF94A3B8);
          label = 'Not Started';
          icon = Icons.circle_outlined;
        }

        DateTime? pd = DateTime.tryParse(ev.date);
        final dateStr = pd != null ? DateFormat('EEE, MMM d').format(pd) : ev.date;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => setState(() => _selectedEvent = ev),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48, height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(value: progress, strokeWidth: 3.5, backgroundColor: const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation(accent)),
                          Text('$pct%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accent)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ev.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(width: 10),
                            const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(ev.startTime, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ]),
                          const SizedBox(height: 5),
                          Row(children: [
                            Icon(icon, size: 13, color: accent),
                            const SizedBox(width: 4),
                            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent)),
                            const Spacer(),
                            Text('$completed/$total athletes', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== ATHLETES LIST ====================

  Widget _buildAthletesList() {
    if (_roster.isEmpty) {
      return Center(
        key: const ValueKey('empty_ath'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Color(0xFFE2E8F0), shape: BoxShape.circle), child: const Icon(Icons.group_off, size: 36, color: Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            const Text('No Athletes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            const Text('Add players to this squad first.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    final totalM = _metrics.length;
    final eid = _selectedEvent.id.toString();
    final scores = _eventScoresCache[eid] ?? {};

    return ListView.builder(
      key: const ValueKey('athletes'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _roster.length,
      itemBuilder: (context, i) {
        final a = _roster[i];
        final pid = a['id']?.toString() ?? '';
        final fn = a['firstName'] ?? '';
        final ln = a['lastName'] ?? '';
        final pos = a['position'] ?? '';
        final ini = ((fn.isNotEmpty ? fn[0] : '') + (ln.isNotEmpty ? ln[0] : '')).toUpperCase();
        final ps = scores[pid] as Map<String, dynamic>? ?? {};
        final scored = ps.length;

        Color bg, fg;
        IconData ic;
        String lbl;
        if (totalM > 0 && scored >= totalM) {
          bg = const Color(0xFFD1FAE5); fg = const Color(0xFF059669);
          ic = Icons.check_circle_rounded; lbl = 'Done';
        } else if (scored > 0) {
          bg = const Color(0xFFFEF3C7); fg = const Color(0xFFD97706);
          ic = Icons.timelapse_rounded; lbl = '$scored/$totalM';
        } else {
          bg = const Color(0xFFF1F5F9); fg = const Color(0xFF64748B);
          ic = Icons.edit_note_rounded; lbl = 'Enter';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () async {
                final result = await _showScoreSheet(a, ps);
                if (result == true) await _refreshEventScores(eid, _selectedEvent.date);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: scored >= totalM && totalM > 0 ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      child: Text(ini, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$fn $ln', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), letterSpacing: -0.2)),
                          if (pos.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 1), child: Text(pos, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(ic, size: 13, color: fg),
                        const SizedBox(width: 4),
                        Text(lbl, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== SCORE SHEET ====================

  Future<bool?> _showScoreSheet(Map<String, dynamic> athlete, Map<String, dynamic> existingScores) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ScoreEntrySheet(athlete: athlete, event: _selectedEvent, metrics: _metrics, savedScores: existingScores),
    );
  }
}

// ============================================================
// SCORE ENTRY BOTTOM SHEET
// ============================================================

class _ScoreEntrySheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> athlete;
  final dynamic event;
  final List<dynamic> metrics;
  final Map<String, dynamic> savedScores;
  const _ScoreEntrySheet({required this.athlete, required this.event, required this.metrics, required this.savedScores});
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
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final logs = <Map<String, dynamic>>[];
    final playerId = widget.athlete['id']?.toString() ?? '';
    _controllers.forEach((metricId, controller) {
      final text = controller.text.trim();
      if (text.isNotEmpty) {
        final val = double.tryParse(text);
        if (val != null) logs.add({'playerId': playerId, 'metricId': metricId, 'score': val});
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
        'eventId': widget.event.id, 'testDate': widget.event.date,
        'sessionName': widget.event.title, 'logs': logs,
      });
      if (!mounted) return;
      if (res.statusCode == 200 && res.data['success'] == true) {
        ref.invalidate(dashboardSummaryProvider);
        ref.invalidate(dashboardEventsProvider);
        AppToast.showSuccess(context, title: 'Saved', message: '${logs.length} score(s) recorded.');
        Navigator.pop(context, true);
      } else {
        AppToast.showError(context, title: 'Failed', message: res.data['message'] ?? 'Could not save.');
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
    final fn = widget.athlete['firstName'] ?? '';
    final ln = widget.athlete['lastName'] ?? '';
    final pos = widget.athlete['position'] ?? '';
    final ini = ((fn.isNotEmpty ? fn[0] : '') + (ln.isNotEmpty ? ln[0] : '')).toUpperCase();
    final bottomPad = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
            child: Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, child: Text(ini, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$fn $ln', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      if (pos.isNotEmpty) Text(pos, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Color(0xFF475569), size: 20)),
              ],
            ),
          ),
          const Divider(height: 1),
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
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                        if (category.isNotEmpty || unit.isNotEmpty)
                          Text([category, unit].where((s) => s.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ]),
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
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded, size: 20),
                label: Text(_isSaving ? 'Saving...' : 'Save Scores', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF93C5FD),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
