import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';
import '../controllers/dashboard_controller.dart';

// ─── Design tokens ──────────────────────────────────────────
const _navy = Color(0xFF0F172A);
const _blue = Color(0xFF2563EB);
const _green = Color(0xFF10B981);
const _greenLight = Color(0xFFD1FAE5);
const _greenDark = Color(0xFF059669);
const _amber = Color(0xFFF59E0B);
const _amberLight = Color(0xFFFEF3C7);
const _amberDark = Color(0xFFD97706);
const _slate100 = Color(0xFFF1F5F9);
const _slate200 = Color(0xFFE2E8F0);
const _slate300 = Color(0xFFCBD5E1);
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _radius = 18.0;

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

  // ─── DATA ─────────────────────────────────────────────────
  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final evRes = await api.getAndCache('/api/dashboard/events?event_type=Fitness Test');
      List<dynamic> events = [];
      if (evRes.statusCode == 200 && evRes.data['success'] == true) {
        events = (evRes.data['data'] as List).map((e) => CoachEvent.fromJson(e)).where((e) {
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
      if (mRes.statusCode == 200 && mRes.data['success'] == true) metrics = mRes.data['data'] ?? [];
      final rRes = await api.getAndCache('/api/rosters/${widget.ageGroup}');
      List<dynamic> roster = [];
      if (rRes.statusCode == 200 && rRes.data['success'] == true) roster = rRes.data['data']['players'] ?? [];

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
      if (mounted) setState(() { _events = events; _metrics = metrics; _roster = roster; _completionData = completion; _isLoading = false; });
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); AppToast.showError(context, title: 'Error', message: 'Failed to load test data.'); }
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
        if (mounted) setState(() => _completionData[eventId] = {'completed': done, 'total': _roster.length});
      }
    } catch (_) {}
  }

  // ─── ROOT BUILD ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: _slate100,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag pill
          Center(child: Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 4, decoration: BoxDecoration(color: _slate300, borderRadius: BorderRadius.circular(2)))),
          // Header
          _buildHeader(),
          // Body
          Expanded(
            child: _isLoading
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: _blue)),
                    const SizedBox(height: 14),
                    Text('Loading data…', style: TextStyle(fontSize: 13, color: _slate400)),
                  ]))
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _selectedEvent == null ? _buildEventsList() : _buildAthletesList(),
                  ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader() {
    if (_selectedEvent != null) return _athleteHeader();
    return _eventsHeader();
  }

  Widget _eventsHeader() {
    final done = _completionData.values.where((c) => (c['total'] as int? ?? 0) > 0 && (c['completed'] as int? ?? 0) >= (c['total'] as int? ?? 0)).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(children: [
            // Icon container
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Fitness Testing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.4, height: 1.2)),
              const SizedBox(height: 3),
              Text('${widget.ageGroup} Squad', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w500)),
            ])),
            _closeBtn(),
          ]),
          const SizedBox(height: 14),
          // Stat row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              _statCol('${_events.length}', 'Events'),
              _divider(),
              _statCol('${_roster.length}', 'Athletes'),
              _divider(),
              _statCol('$done', 'Complete'),
              _divider(),
              _statCol('${_metrics.length}', 'Metrics'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _athleteHeader() {
    final eid = _selectedEvent.id.toString();
    final cData = _completionData[eid] ?? {'completed': 0, 'total': 0};
    final completed = cData['completed'] as int;
    final total = cData['total'] as int;
    final pct = total > 0 ? ((completed / total) * 100).round() : 0;
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    DateTime? d = DateTime.tryParse(_selectedEvent.date);
    final dateStr = d != null ? DateFormat('EEEE, MMM d').format(d) : _selectedEvent.date;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Row(children: [
          _backBtn(),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selectedEvent.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
          ])),
          const SizedBox(width: 8),
          // Progress ring
          SizedBox(width: 48, height: 48, child: Stack(alignment: Alignment.center, children: [
            SizedBox(width: 48, height: 48, child: CircularProgressIndicator(value: progress, strokeWidth: 3.5, strokeCap: StrokeCap.round, backgroundColor: Colors.white.withValues(alpha: 0.12), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)))),
            Text('$pct%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
          ])),
          const SizedBox(width: 6),
          _closeBtn(),
        ]),
        const SizedBox(height: 12),
        // Chips row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            _statCol('${_roster.length}', 'Athletes'),
            _divider(),
            _statCol('${_metrics.length}', 'Metrics'),
            _divider(),
            _statCol('$completed', 'Done'),
            _divider(),
            _statCol('${total - completed}', 'Remaining'),
          ]),
        ),
      ]),
    );
  }

  Widget _statCol(String value, String label) {
    return Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
    ]));
  }

  Widget _divider() => Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.1));

  Widget _backBtn() => InkWell(
    onTap: () => setState(() => _selectedEvent = null),
    borderRadius: BorderRadius.circular(10),
    child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 15)),
  );

  Widget _closeBtn() => InkWell(
    onTap: () => Navigator.pop(context),
    borderRadius: BorderRadius.circular(10),
    child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.close_rounded, color: Colors.white, size: 15)),
  );

  // ═══════════════════════════════════════════════════════════
  //  EVENTS LIST
  // ═══════════════════════════════════════════════════════════

  Widget _buildEventsList() {
    if (_events.isEmpty) return _emptyState(key: 'empty_ev', icon: Icons.event_busy_rounded, title: 'No Test Events', sub: 'Create a fitness test event from the Events tab.');

    return ListView.builder(
      key: const ValueKey('ev_list'),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 32),
      itemCount: _events.length,
      itemBuilder: (_, i) => _eventCard(_events[i]),
    );
  }

  Widget _eventCard(dynamic ev) {
    final eid = ev.id.toString();
    final cData = _completionData[eid] ?? {'completed': 0, 'total': 0};
    final completed = cData['completed'] as int;
    final total = cData['total'] as int;
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).round();

    Color accent; String label; IconData icon;
    if (total > 0 && completed >= total) { accent = _green; label = 'Complete'; icon = Icons.check_circle_rounded; }
    else if (completed > 0) { accent = _amber; label = 'In Progress'; icon = Icons.timelapse_rounded; }
    else { accent = _slate400; label = 'Not Started'; icon = Icons.circle_outlined; }

    DateTime? pd = DateTime.tryParse(ev.date);
    final dayLabel = pd != null ? DateFormat('d').format(pd) : '--';
    final monthLabel = pd != null ? DateFormat('MMM').format(pd).toUpperCase() : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => setState(() => _selectedEvent = ev),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _slate200)),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Date block
              Container(
                width: 52, height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(dayLabel, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: accent, height: 1)),
                  const SizedBox(height: 1),
                  Text(monthLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent.withValues(alpha: 0.7), letterSpacing: 0.5)),
                ]),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ev.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _navy, letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Row(children: [
                  Icon(Icons.schedule_rounded, size: 12, color: _slate400),
                  const SizedBox(width: 3),
                  Text(ev.startTime, style: const TextStyle(fontSize: 12, color: _slate500)),
                  const SizedBox(width: 12),
                  Icon(icon, size: 12, color: accent),
                  const SizedBox(width: 3),
                  Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
                ]),
                const SizedBox(height: 8),
                // Progress bar
                Row(children: [
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: _slate200, valueColor: AlwaysStoppedAnimation(accent)))),
                  const SizedBox(width: 10),
                  Text('$pct%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
                ]),
              ])),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: _slate300, size: 22),
            ]),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ATHLETES LIST
  // ═══════════════════════════════════════════════════════════

  Widget _buildAthletesList() {
    if (_roster.isEmpty) return _emptyState(key: 'empty_ath', icon: Icons.group_off_rounded, title: 'No Athletes', sub: 'Add players to this squad first.');

    final totalM = _metrics.length;
    final eid = _selectedEvent.id.toString();
    final scores = _eventScoresCache[eid] ?? {};

    return ListView.builder(
      key: const ValueKey('ath_list'),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 32),
      itemCount: _roster.length,
      itemBuilder: (_, i) => _athleteTile(_roster[i], scores, totalM, eid),
    );
  }

  Widget _athleteTile(Map<String, dynamic> a, Map<String, dynamic> scores, int totalM, String eid) {
    final pid = a['id']?.toString() ?? '';
    final fn = a['firstName'] ?? '';
    final ln = a['lastName'] ?? '';
    final pos = a['position'] ?? '';
    final ini = ((fn.isNotEmpty ? fn[0] : '') + (ln.isNotEmpty ? ln[0] : '')).toUpperCase();
    final ps = scores[pid] as Map<String, dynamic>? ?? {};
    final scored = ps.length;

    final bool isDone = totalM > 0 && scored >= totalM;
    final bool isPartial = scored > 0 && !isDone;

    Color avBg, badgeBg, badgeFg;
    IconData badgeIcon;
    String badgeLabel;
    if (isDone) {
      avBg = _green; badgeBg = _greenLight; badgeFg = _greenDark; badgeIcon = Icons.check_circle_rounded; badgeLabel = 'Done';
    } else if (isPartial) {
      avBg = _amberDark; badgeBg = _amberLight; badgeFg = _amberDark; badgeIcon = Icons.timelapse_rounded; badgeLabel = '$scored/$totalM';
    } else {
      avBg = _blue; badgeBg = const Color(0xFFEFF6FF); badgeFg = _blue; badgeIcon = Icons.edit_rounded; badgeLabel = 'Enter';
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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: isDone ? _green.withValues(alpha: 0.2) : _slate200)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              // Avatar
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [avBg, avBg.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(ini, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$fn $ln', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _navy, letterSpacing: -0.2)),
                if (pos.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 1), child: Text(pos, style: const TextStyle(fontSize: 11, color: _slate400))),
              ])),
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(badgeIcon, size: 13, color: badgeFg),
                  const SizedBox(width: 4),
                  Text(badgeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeFg)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  EMPTY STATE
  // ═══════════════════════════════════════════════════════════

  Widget _emptyState({required String key, required IconData icon, required String title, required String sub}) {
    return Center(
      key: ValueKey(key),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: _slate200, shape: BoxShape.circle), child: Icon(icon, size: 34, color: _slate400)),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _navy)),
        const SizedBox(height: 6),
        Text(sub, style: const TextStyle(fontSize: 13, color: _slate500)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SCORE SHEET LAUNCHER
  // ═══════════════════════════════════════════════════════════

  Future<bool?> _showScoreSheet(Map<String, dynamic> athlete, Map<String, dynamic> existing) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ScoreSheet(athlete: athlete, event: _selectedEvent, metrics: _metrics, saved: existing),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  SCORE ENTRY BOTTOM SHEET
// ═════════════════════════════════════════════════════════════

class _ScoreSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> athlete;
  final dynamic event;
  final List<dynamic> metrics;
  final Map<String, dynamic> saved;
  const _ScoreSheet({required this.athlete, required this.event, required this.metrics, required this.saved});
  @override
  ConsumerState<_ScoreSheet> createState() => _ScoreSheetState();
}

class _ScoreSheetState extends ConsumerState<_ScoreSheet> {
  final Map<String, TextEditingController> _ctrls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final m in widget.metrics) {
      final mid = m['id']?.toString() ?? '';
      final ex = widget.saved[mid];
      String pre = '';
      if (ex != null) {
        final n = double.tryParse(ex.toString());
        pre = (n != null && n == n.roundToDouble()) ? n.toInt().toString() : ex.toString();
      }
      _ctrls[mid] = TextEditingController(text: pre);
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final logs = <Map<String, dynamic>>[];
    final pid = widget.athlete['id']?.toString() ?? '';
    _ctrls.forEach((mid, c) {
      final t = c.text.trim();
      if (t.isNotEmpty) { final v = double.tryParse(t); if (v != null) logs.add({'playerId': pid, 'metricId': mid, 'score': v}); }
    });
    if (logs.isEmpty) { AppToast.showError(context, title: 'No Scores', message: 'Enter at least one score.'); return; }
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/api/test-logs/batch', data: { 'eventId': widget.event.id, 'testDate': widget.event.date, 'sessionName': widget.event.title, 'logs': logs });
      if (!mounted) return;
      if (res.statusCode == 200 && res.data['success'] == true) {
        ref.invalidate(dashboardSummaryProvider); ref.invalidate(dashboardEventsProvider);
        AppToast.showSuccess(context, title: 'Saved', message: '${logs.length} score(s) recorded.');
        Navigator.pop(context, true);
      } else {
        AppToast.showError(context, title: 'Failed', message: res.data['message'] ?? 'Could not save.'); setState(() => _saving = false);
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, title: 'Error', message: 'Network error.'); setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fn = widget.athlete['firstName'] ?? '';
    final ln = widget.athlete['lastName'] ?? '';
    final pos = widget.athlete['position'] ?? '';
    final ini = ((fn.isNotEmpty ? fn[0] : '') + (ln.isNotEmpty ? ln[0] : '')).toUpperCase();
    final bottomPad = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16;
    DateTime? d = DateTime.tryParse(widget.event.date);
    final dateStr = d != null ? DateFormat('MMM d, yyyy').format(d) : '';

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag pill
        Center(child: Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 4, decoration: BoxDecoration(color: _slate300, borderRadius: BorderRadius.circular(2)))),

        // ── Player header ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(ini, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$fn $ln', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Row(children: [
                if (pos.isNotEmpty) ...[Text(pos, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))), const SizedBox(width: 8)],
                Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
              ]),
            ])),
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16)),
            ),
          ]),
        ),

        const SizedBox(height: 6),

        // ── Metrics label ──
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 4),
          child: Row(children: [
            Text('METRICS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _slate400, letterSpacing: 1.2)),
            const Spacer(),
            Text('${widget.metrics.length} total', style: TextStyle(fontSize: 11, color: _slate400)),
          ]),
        ),

        // ── Metric inputs ──
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            itemCount: widget.metrics.length,
            itemBuilder: (_, i) {
              final m = widget.metrics[i];
              final mid = m['id']?.toString() ?? '';
              final name = m['name'] ?? 'Metric';
              final unit = m['unit'] ?? '';
              final category = m['category'] ?? '';
              final hasValue = _ctrls[mid]?.text.trim().isNotEmpty ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: hasValue ? _blue.withValues(alpha: 0.03) : _slate100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: hasValue ? _blue.withValues(alpha: 0.15) : _slate200),
                ),
                child: Row(children: [
                  // Metric icon
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: hasValue ? _blue.withValues(alpha: 0.08) : _slate200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _metricIcon(name),
                      size: 17,
                      color: hasValue ? _blue : _slate400,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
                    if (category.isNotEmpty || unit.isNotEmpty)
                      Text([category, unit].where((s) => s.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 10, color: _slate400)),
                  ])),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 80,
                    height: 40,
                    child: TextField(
                      controller: _ctrls[mid],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _navy),
                      decoration: InputDecoration(
                        hintText: unit.isNotEmpty ? unit : '--',
                        hintStyle: const TextStyle(color: _slate300, fontWeight: FontWeight.w400, fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _blue, width: 2)),
                      ),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),

        // ── Save button ──
        Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPad),
          child: SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue, foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF93C5FD),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Save All Scores', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2)),
                    ]),
            ),
          ),
        ),
      ]),
    );
  }

  IconData _metricIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('speed') || n.contains('sprint') || n.contains('run')) return Icons.directions_run_rounded;
    if (n.contains('jump') || n.contains('leap') || n.contains('height')) return Icons.height_rounded;
    if (n.contains('push') || n.contains('press') || n.contains('strength')) return Icons.fitness_center_rounded;
    if (n.contains('agility') || n.contains('shuttle')) return Icons.swap_calls_rounded;
    if (n.contains('endurance') || n.contains('beep') || n.contains('vo2')) return Icons.monitor_heart_rounded;
    if (n.contains('flex') || n.contains('stretch') || n.contains('sit')) return Icons.self_improvement_rounded;
    if (n.contains('throw') || n.contains('ball') || n.contains('kick')) return Icons.sports_soccer_rounded;
    if (n.contains('weight') || n.contains('mass') || n.contains('bmi')) return Icons.scale_rounded;
    return Icons.straighten_rounded;
  }
}
