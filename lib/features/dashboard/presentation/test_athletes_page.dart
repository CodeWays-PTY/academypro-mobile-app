import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';

import 'athlete_score_sheet.dart';

class TestAthletesPage extends ConsumerStatefulWidget {
  final dynamic event;
  final String ageGroup;

  const TestAthletesPage({super.key, required this.event, required this.ageGroup});

  static void show(BuildContext context, {required dynamic event, required String ageGroup}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TestAthletesPage(event: event, ageGroup: ageGroup),
    );
  }

  @override
  ConsumerState<TestAthletesPage> createState() => _TestAthletesPageState();
}

class _TestAthletesPageState extends ConsumerState<TestAthletesPage> {
  bool _isLoading = true;
  List<dynamic> _roster = [];
  List<dynamic> _metrics = [];
  Map<String, dynamic> _savedScores = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);

      // Fetch squad roster
      final rosterRes = await apiClient.getAndCache('/api/rosters/${widget.ageGroup}');
      List<dynamic> roster = [];
      if (rosterRes.statusCode == 200 && rosterRes.data['success'] == true) {
        roster = rosterRes.data['data']['players'] ?? [];
      }

      // Fetch metrics
      final metricRes = await apiClient.getAndCache('/api/test-metrics');
      List<dynamic> metrics = [];
      if (metricRes.statusCode == 200 && metricRes.data['success'] == true) {
        metrics = metricRes.data['data'] ?? [];
      }

      // Fetch current logged scores for this event
      final eventId = widget.event.id;
      final date = widget.event.date;
      final scoreRes = await apiClient.getAndCache('/api/test-logs/by-event?eventId=$eventId&testDate=$date');
      Map<String, dynamic> savedScores = {};
      if (scoreRes.statusCode == 200 && scoreRes.data['success'] == true) {
        savedScores = scoreRes.data['data'] ?? {};
      }

      if (mounted) {
        setState(() {
          _roster = roster;
          _metrics = metrics;
          _savedScores = savedScores;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, title: 'Error', message: 'Failed to load athlete data.');
      }
    }
  }

  String _getInitials(String firstName, String lastName) {
    String first = firstName.isNotEmpty ? firstName[0] : '';
    String last = lastName.isNotEmpty ? lastName[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    DateTime? parsedDate;
    if (widget.event.date != null) {
      parsedDate = DateTime.tryParse(widget.event.date!);
    }
    final dateStr = parsedDate != null ? DateFormat('MMM d, yyyy').format(parsedDate) : (widget.event.date ?? '');

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.event.title ?? 'Event', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(dateStr, style: const TextStyle(color: Color(0xFF475569), fontSize: 14)),
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
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _roster.isEmpty
                    ? _buildEmptyState()
                    : _buildAthletesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 100),
        Icon(Icons.group_off, size: 64, color: Color(0xFF94A3B8)),
        SizedBox(height: 16),
        Text(
          'No Athletes Found',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        SizedBox(height: 8),
        Text(
          'There are no players on this squad roster to test.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  Widget _buildAthletesList() {
    final totalMetrics = _metrics.length;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _roster.length,
      itemBuilder: (context, index) {
        final athlete = _roster[index];
        final playerId = athlete['id']?.toString() ?? '';
        final firstName = athlete['firstName'] ?? '';
        final lastName = athlete['lastName'] ?? '';
        final position = athlete['position'] ?? 'Unknown Position';

        final playerScores = _savedScores[playerId] as Map<String, dynamic>? ?? {};
        final scoredCount = playerScores.length;

        IconData statusIcon;
        Color statusColor;
        if (totalMetrics > 0 && scoredCount >= totalMetrics) {
          statusIcon = Icons.check_circle;
          statusColor = const Color(0xFF10B981); // Complete (Green)
        } else if (scoredCount > 0) {
          statusIcon = Icons.warning;
          statusColor = const Color(0xFFD97706); // Partial (Amber)
        } else {
          statusIcon = Icons.radio_button_unchecked;
          statusColor = const Color(0xFF94A3B8); // Not Started (Grey)
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () async {
              final result = await AthleteScoreSheet.show(
                context,
                athlete: athlete,
                event: widget.event,
                metrics: _metrics,
                savedScores: playerScores,
              );
              if (result == true) {
                // Refresh scores after return
                _fetchData();
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    child: Text(_getInitials(firstName, lastName), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$firstName $lastName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        Text(position, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 24),
                      const SizedBox(height: 4),
                      Text('$scoredCount/$totalMetrics metrics', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
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
}
