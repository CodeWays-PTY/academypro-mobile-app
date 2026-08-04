import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';

class ManageMetricsModal extends ConsumerStatefulWidget {
  const ManageMetricsModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const ManageMetricsModal(),
    );
  }

  @override
  ConsumerState<ManageMetricsModal> createState() => _ManageMetricsModalState();
}

class _ManageMetricsModalState extends ConsumerState<ManageMetricsModal> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _metrics = [];

  final _nameController = TextEditingController();
  final _unitController = TextEditingController(text: 'seconds');
  final _targetController = TextEditingController();
  String _selectedCategory = 'Speed';
  String _selectedGoalDirection = 'LOWER_IS_BETTER';

  final List<String> _categories = ['Speed', 'Strength', 'Endurance', 'Agility', 'Power', 'General'];

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _fetchMetrics() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.getAndCache('/api/test-metrics');
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _metrics = response.data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMetric() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/api/test-metrics', data: {
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'unit': _unitController.text.trim(),
        'goalDirection': _selectedGoalDirection,
        'targetBenchmark': double.tryParse(_targetController.text.trim()) ?? 0.0,
      });

      if (!mounted) return;
      if (response.statusCode == 200 && response.data['success'] == true) {
        _nameController.clear();
        _targetController.clear();
        AppToast.showSuccess(context, title: 'Metric Added', message: 'Test metric saved successfully.');
        await _fetchMetrics();
      } else {
        AppToast.showError(context, title: 'Save Failed', message: 'Could not save the metric. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, title: 'Something Went Wrong', message: 'Could not save the metric. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteMetric(String id) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete('/api/test-metrics/$id');
      await _fetchMetrics();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
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
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Dynamic Test Metrics',
                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 2.0),
                  Text(
                    'Configure tests & benchmarks for your team',
                    style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 24.0),

          // Add New Metric Form
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Test Name (e.g. Bronco Test)',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        borderRadius: BorderRadius.circular(16.0),
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          prefixIcon: const Icon(Icons.category_outlined, size: 18.0, color: Color(0xFF2563EB)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                        ),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)))).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: InputDecoration(
                          labelText: 'Unit (e.g. sec, kg, reps)',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: TextFormField(
                        controller: _targetController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Target Benchmark',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGoalDirection,
                        borderRadius: BorderRadius.circular(16.0),
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Goal Direction',
                          prefixIcon: const Icon(Icons.trending_up, size: 18.0, color: Color(0xFF2563EB)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.0), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'LOWER_IS_BETTER', child: Text('Lower is Better (Times/Sprint)', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'HIGHER_IS_BETTER', child: Text('Higher is Better (Reps/PB/Jump)', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600))),
                        ],
                        onChanged: (val) => setState(() => _selectedGoalDirection = val!),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveMetric,
                      icon: _isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add, size: 16.0),
                      label: const Text('Add Test'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          const Text(
            'ACTIVE TEAM TEST METRICS',
            style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
          ),
          const SizedBox(height: 8.0),

          // List of Active Metrics
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _metrics.isEmpty
                    ? const Center(child: Text('No custom test metrics added yet.', style: TextStyle(color: Color(0xFF94A3B8))))
                    : ListView.separated(
                        itemCount: _metrics.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8.0),
                        itemBuilder: (context, index) {
                          final item = _metrics[index];
                          return Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                  child: Text(
                                    item['category']?.toString().toUpperCase() ?? '',
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                  ),
                                ),
                                const SizedBox(width: 10.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        'Target: ${item['targetBenchmark'] ?? '-'} ${item['unit']} (${item['goalDirection'] == 'LOWER_IS_BETTER' ? 'Lower better' : 'Higher better'})',
                                        style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20.0),
                                  onPressed: () => _deleteMetric(item['id']),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
