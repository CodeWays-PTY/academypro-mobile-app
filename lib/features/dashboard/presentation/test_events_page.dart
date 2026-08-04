import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';
import '../controllers/dashboard_controller.dart';

import 'test_athletes_page.dart';

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
  Map<String, Map<String, dynamic>> _completionData = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);

      // Fetch fitness test events
      final eventsRes = await apiClient.getAndCache('/api/dashboard/events?event_type=Fitness Test');
      List<dynamic> loadedEvents = [];
      if (eventsRes.statusCode == 200 && eventsRes.data['success'] == true) {
        final data = eventsRes.data['data'] as List;
        loadedEvents = data.map((e) => CoachEvent.fromJson(e)).where((e) {
          final type = e.eventType.toLowerCase();
          final title = e.title.toLowerCase();
          return type.contains('test') || type.contains('fitness') || title.contains('test') || title.contains('fitness');
        }).toList();

        // Sort by date DESC
        loadedEvents.sort((a, b) {
          final dateA = DateTime.tryParse(a.date) ?? DateTime.now();
          final dateB = DateTime.tryParse(b.date) ?? DateTime.now();
          return dateB.compareTo(dateA);
        });
      }

      // Fetch squad roster size
      int rosterCount = 0;
      final rosterRes = await apiClient.getAndCache('/api/rosters/${widget.ageGroup}');
      if (rosterRes.statusCode == 200 && rosterRes.data['success'] == true) {
        final players = rosterRes.data['data']['players'] as List?;
        rosterCount = players?.length ?? 0;
      }

      // Fetch test metrics total
      int metricCount = 0;
      final metricRes = await apiClient.getAndCache('/api/test-metrics');
      if (metricRes.statusCode == 200 && metricRes.data['success'] == true) {
        final metrics = metricRes.data['data'] as List?;
        metricCount = metrics?.length ?? 0;
      }

      // Calculate completion for each event
      Map<String, Map<String, dynamic>> completionData = {};
      for (final event in loadedEvents) {
        final eventId = event.id;
        final date = event.date;
        final scoreRes = await apiClient.getAndCache('/api/test-logs/by-event?eventId=$eventId&testDate=$date');
        
        int completedAthletes = 0;
        if (scoreRes.statusCode == 200 && scoreRes.data['success'] == true) {
          final Map<String, dynamic> playerScores = scoreRes.data['data'] ?? {};
          for (final playerId in playerScores.keys) {
            final metricsData = playerScores[playerId] as Map<String, dynamic>;
            if (metricsData.length >= metricCount && metricCount > 0) {
              completedAthletes++;
            }
          }
        }
        completionData[eventId.toString()] = {
          'completed': completedAthletes,
          'total': rosterCount,
        };
      }

      if (mounted) {
        setState(() {
          _events = loadedEvents;
          _completionData = completionData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, title: 'Error', message: 'Failed to load test events.');
      }
    }
  }

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Squad Test Events', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(widget.ageGroup, style: const TextStyle(color: Color(0xFF475569), fontSize: 14)),
                  ],
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
                : _events.isEmpty
                    ? _buildEmptyState()
                    : _buildEventsList(),
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
        Icon(Icons.event_busy, size: 64, color: Color(0xFF94A3B8)),
        SizedBox(height: 16),
        Text(
          'No Test Events Found',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        SizedBox(height: 8),
        Text(
          'There are no upcoming or past fitness tests scheduled for this squad.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  Widget _buildEventsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        final eventId = event.id.toString();
        final cData = _completionData[eventId] ?? {'completed': 0, 'total': 0};
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

        DateTime? parsedDate;
        if (event.date != null) {
          parsedDate = DateTime.tryParse(event.date!);
        }
        final dateStr = parsedDate != null ? DateFormat('EEE, MMM d, yyyy').format(parsedDate) : (event.date ?? 'Unknown Date');

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.pop(context); // Close events modal
              TestAthletesPage.show(context, event: event, ageGroup: widget.ageGroup);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: const Border(left: BorderSide(color: Color(0xFFD97706), width: 6)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.title ?? 'Unnamed Event',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF475569)),
                      const SizedBox(width: 4),
                      Text(dateStr, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, size: 14, color: Color(0xFF475569)),
                      const SizedBox(width: 4),
                      Text(event.startTime ?? 'Time TBD', style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Completion', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      Text('$completed / $total Athletes', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFF1F5F9), // slate-100
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
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
