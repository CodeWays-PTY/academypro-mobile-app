import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';
import '../controllers/dashboard_controller.dart';


class AthleteScoreSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> athlete;
  final dynamic event; // CoachEvent model
  final List<dynamic> metrics;
  final Map<String, dynamic> savedScores;

  const AthleteScoreSheet({
    Key? key,
    required this.athlete,
    required this.event,
    required this.metrics,
    required this.savedScores,
  }) : super(key: key);

  static Future<bool?> show(
    BuildContext context, {
    required Map<String, dynamic> athlete,
    required dynamic event,
    required List<dynamic> metrics,
    required Map<String, dynamic> savedScores,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AthleteScoreSheet(
        athlete: athlete,
        event: event,
        metrics: metrics,
        savedScores: savedScores,
      ),
    );
  }

  @override
  ConsumerState<AthleteScoreSheet> createState() => _AthleteScoreSheetState();
}

class _AthleteScoreSheetState extends ConsumerState<AthleteScoreSheet> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final metric in widget.metrics) {
      final metricId = metric['id'].toString();
      final savedValue = widget.savedScores[metricId];
      String initialText = '';
      if (savedValue != null) {
        if (savedValue is double && savedValue == savedValue.toInt()) {
          initialText = savedValue.toInt().toString();
        } else {
          initialText = savedValue.toString();
        }
      }
      _controllers[metricId] = TextEditingController(text: initialText);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveScores() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final List<Map<String, dynamic>> logs = [];
      final playerId = widget.athlete['id'].toString();

      for (final metric in widget.metrics) {
        final metricId = metric['id'].toString();
        final text = _controllers[metricId]?.text.trim() ?? '';
        if (text.isNotEmpty) {
          final score = double.tryParse(text);
          if (score != null) {
            logs.add({
              'playerId': playerId,
              'metricId': metricId,
              'score': score,
            });
          }
        }
      }

      final apiClient = ref.read(apiClientProvider);
      
      // Post all valid metric logs for this athlete in a batch
      final response = await apiClient.post('/api/test-logs/batch', data: {
        'eventId': widget.event.id,
        'metricId': logs.isNotEmpty ? logs.first['metricId'] : null, // Assuming endpoint might need a sample or just ignore this field during batch logs saving based on pattern
        'testDate': widget.event.date,
        'sessionName': widget.event.title,
        'logs': logs,
      });

      if (mounted) {
        setState(() => _isSaving = false);
        if (response.statusCode == 200 || response.statusCode == 201) {
          AppToast.showSuccess(context, title: 'Scores Recorded', message: 'Successfully logged scores.');
          
          // Invalidate providers
          try {
            ref.invalidate(dashboardSummaryProvider);
            ref.invalidate(dashboardEventsProvider);
          } catch (_) {}
          
          Navigator.of(context).pop(true);
        } else {
          AppToast.showError(context, title: 'Error', message: 'Something went wrong.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.showError(context, title: 'Error', message: 'Something went wrong.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add extra padding to deal with the keyboard safely
    final bottomPadding = MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom;
    
    final firstName = widget.athlete['firstName'] ?? '';
    final lastName = widget.athlete['lastName'] ?? '';
    final position = widget.athlete['position'] ?? 'Unknown Position';
    
    DateTime? parsedDate;
    if (widget.event.date != null) {
      parsedDate = DateTime.tryParse(widget.event.date!);
    }
    final dateStr = parsedDate != null ? DateFormat('MMM d, yyyy').format(parsedDate) : (widget.event.date ?? '');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    child: Text('${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$firstName $lastName', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text(position, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Sub-header Context Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: const Color(0xFFF8FAFC),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.event.title ?? 'Event', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                ],
              ),
            ),
            
            // Metrics List
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                itemCount: widget.metrics.length,
                separatorBuilder: (context, index) => const Divider(height: 32, color: Color(0xFFE2E8F0)),
                itemBuilder: (context, index) {
                  final metric = widget.metrics[index];
                  final metricId = metric['id'].toString();
                  final name = metric['name'] ?? 'Metric';
                  final unit = metric['unit'] ?? '';
                  final category = metric['category'] ?? 'General';
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _controllers[metricId],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: 'Enter $unit',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                                ),
                              ),
                              style: const TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
                            ),
                          ),
                          if (unit.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Text(unit, style: const TextStyle(fontSize: 16, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                            const SizedBox(width: 16),
                          ]
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            
            // Save Button
            Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding > 0 ? bottomPadding + 16 : 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveScores,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSaving 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Scores', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
