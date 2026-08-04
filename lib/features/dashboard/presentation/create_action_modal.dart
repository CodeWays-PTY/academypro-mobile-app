import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_toast.dart';
import '../controllers/dashboard_controller.dart';

class CreateActionModal extends ConsumerStatefulWidget {
  final String playerId;
  final String playerName;

  const CreateActionModal({
    super.key,
    required this.playerId,
    required this.playerName,
  });

  static Future<void> show(BuildContext context, {required String playerId, required String playerName}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) => CreateActionModal(playerId: playerId, playerName: playerName),
    );
  }

  @override
  ConsumerState<CreateActionModal> createState() => _CreateActionModalState();
}

class _CreateActionModalState extends ConsumerState<CreateActionModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String _selectedCategory = 'School & Academics';

  final List<String> _categories = [
    'School & Academics',
    'Training & Physical Fitness',
    'Attendance & Discipline',
    'Medical & Rehab',
    'Parent Consultation',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveAction() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();

    ref.read(coachActionProvider.notifier).addAction(
          playerId: widget.playerId,
          playerName: widget.playerName,
          title: _titleController.text.trim(),
          category: _selectedCategory,
        );

    Navigator.pop(context);

    AppToast.showSuccess(
      context,
      title: 'Action Item Assigned',
      message: '${_titleController.text.trim()} assigned to ${widget.playerName}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.0, 16.0, 20.0, MediaQuery.of(context).padding.bottom + 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'COACH CUSTOM ACTION',
                            style: TextStyle(
                              fontSize: 10.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            'Action Plan for ${widget.playerName}',
                            style: const TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Pillar Category',
                    style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        borderRadius: BorderRadius.circular(16.0),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB)),
                        style: const TextStyle(fontSize: 14.0, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        items: _categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Action Plan Description (Coach Defined)',
                    style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6.0),
                  TextFormField(
                    controller: _titleController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14.0, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'e.g. Schedule 1-on-1 Math tutor, extra gym session, or parent conference...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.0),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.all(14.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter a description for the action item';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton.icon(
                    onPressed: _saveAction,
                    icon: const Icon(Icons.check, size: 18.0),
                    label: const Text(
                      'Save Action Plan',
                      style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
