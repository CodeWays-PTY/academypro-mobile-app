import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/app_toast.dart';
import '../controllers/dashboard_controller.dart';

class CreateEventModal extends ConsumerStatefulWidget {
  final CoachEvent? eventToEdit;

  const CreateEventModal({super.key, this.eventToEdit});

  static Future<void> show(BuildContext context, {CoachEvent? eventToEdit}) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
        child: CreateEventModal(eventToEdit: eventToEdit),
      ),
    );
  }

  @override
  ConsumerState<CreateEventModal> createState() => _CreateEventModalState();
}

class _CreateEventModalState extends ConsumerState<CreateEventModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _durationController = TextEditingController(text: '90');

  String _selectedEventType = 'Field';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 16, minute: 30);
  String _selectedRecurrence = 'Does Not Repeat';
  bool _isImportant = false;
  bool _isSubmitting = false;
  String? _attachedImagePath;
  String _selectedTeam = '';

  Map<String, List<String>> _userLocationHistory = {};
  Map<String, List<String>> _userTitleHistory = {};

  final List<String> _eventTypes = [
    'Field',
    'Fitness Test',
    'Gym',
    'Match',
  ];

  final List<int> _durationOptions = [30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _loadLocationHistory();
    _loadTitleHistory();

    if (widget.eventToEdit != null) {
      final e = widget.eventToEdit!;
      _titleController.text = e.title;
      _locationController.text = e.location;
      _durationController.text = (e.durationMins ?? 90).toString();
      _selectedEventType = e.eventType;
      _isImportant = e.isImportant;
      _selectedRecurrence = e.recurrenceRule;
      _attachedImagePath = e.workoutImagePath;
      _selectedTeam = e.team;
      if (e.date.isNotEmpty) {
        _selectedDate = DateTime.tryParse(e.date) ?? DateTime.now();
      }
      if (e.startTime.isNotEmpty && e.startTime.contains(':')) {
        final parts = e.startTime.split(':');
        _selectedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 16,
          minute: int.tryParse(parts[1]) ?? 30,
        );
      }
    }
  }

  Future<void> _loadLocationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyMap = <String, List<String>>{};
    for (final type in _eventTypes) {
      final saved = prefs.getStringList('user_locations_$type') ?? [];
      historyMap[type] = saved;
    }
    if (mounted) {
      setState(() {
        _userLocationHistory = historyMap;
      });
    }
  }

  Future<void> _loadTitleHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyMap = <String, List<String>>{};
    for (final type in _eventTypes) {
      final saved = prefs.getStringList('user_titles_$type') ?? [];
      historyMap[type] = saved;
    }
    if (mounted) {
      setState(() {
        _userTitleHistory = historyMap;
      });
    }
  }

  Future<void> _saveLocationToHistory(String type, String loc) async {
    final cleanLoc = loc.trim();
    if (cleanLoc.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList('user_locations_$type') ?? [];
    if (!current.contains(cleanLoc)) {
      final updated = [cleanLoc, ...current].take(8).toList();
      await prefs.setStringList('user_locations_$type', updated);
    }
  }

  Future<void> _saveTitleToHistory(String type, String title) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList('user_titles_$type') ?? [];
    if (!current.contains(cleanTitle)) {
      final updated = [cleanTitle, ...current].take(8).toList();
      await prefs.setStringList('user_titles_$type', updated);
    }
  }

  Future<void> _pickWorkoutImage() async {
    HapticFeedback.lightImpact();

    // Show source choice modal (Camera or Gallery)
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Upload Workout Routine Picture',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16.0),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF003EC7)),
                title: const Text('Take Photo With Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF003EC7)),
                title: const Text('Choose From Photo Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: source, imageQuality: 85);

      // Only update state if a picture was ACTUALLY chosen
      if (file != null) {
        setState(() {
          _attachedImagePath = file.path;
        });
        if (mounted) {
          AppToast.showSuccess(
            context,
            title: 'Workout Photo Attached',
            message: 'Routine photo attached. Will be purged automatically 7 days after the event.',
          );
        }
      }
    } catch (e) {
      // Ignore cancelled or unsupported camera errors silently
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialDate = _selectedDate.isBefore(today) ? today : _selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF003EC7),
              onPrimary: Colors.white,
              onSurface: Color(0xFF131B2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF003EC7),
              onPrimary: Colors.white,
              onSurface: Color(0xFF131B2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _formatDateStr(DateTime dt) {
    final year = dt.year;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatTimeStr(TimeOfDay tod) {
    final hour = tod.hour.toString().padLeft(2, '0');
    final min = tod.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final selectedStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (selectedStart.isBefore(todayStart)) {
      AppToast.showError(context, title: 'Invalid Event Date', message: 'Events cannot be scheduled in the past.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final title = _titleController.text.trim();
    final location = _locationController.text.trim();
    final durationMins = int.tryParse(_durationController.text.trim()) ?? 90;
    final dateStr = _formatDateStr(_selectedDate);
    final timeStr = _formatTimeStr(_selectedTime);

    // Save title & location to user history for this training type
    await _saveLocationToHistory(_selectedEventType, location);
    await _saveTitleToHistory(_selectedEventType, title);

    bool success = false;

    // Match Days never store workout images
    final imagePathToSave = _selectedEventType == 'Match' ? null : _attachedImagePath;

    final activeAge = ref.read(selectedAgeGroupProvider);

    if (widget.eventToEdit != null) {
      final updated = widget.eventToEdit!.copyWith(
        title: title,
        eventType: _selectedEventType,
        startTime: timeStr,
        date: dateStr,
        location: location,
        durationMins: durationMins,
        isImportant: _isImportant,
        recurrenceRule: _selectedRecurrence,
        workoutImagePath: imagePathToSave,
        team: _selectedTeam,
        ageGroup: activeAge,
      );
      success = await ref.read(dashboardEventsProvider.notifier).updateEvent(updated);
    } else {
      success = await ref.read(dashboardEventsProvider.notifier).createEvent(
            title: title,
            eventType: _selectedEventType,
            startTime: timeStr,
            date: dateStr,
            location: location,
            durationMins: durationMins,
            isImportant: _isImportant,
            recurrenceRule: _selectedRecurrence,
            workoutImagePath: imagePathToSave,
            ageGroup: activeAge,
            team: _selectedTeam,
          );
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        Navigator.pop(context);
        AppToast.showSuccess(
          context,
          title: widget.eventToEdit != null ? 'Event Updated' : 'New Event Scheduled',
          message: '${_titleController.text.trim()} scheduled for $_selectedTeam on $_selectedDate.',
        );
      } else {
        AppToast.showError(
          context,
          title: 'Event Save Failed',
          message: 'Failed to save event. Please verify all required fields and try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final userLocations = _userLocationHistory[_selectedEventType] ?? [];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Drag Handle & Title Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 16.0, 12.0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999.0),
                    ),
                  ),
                ),
                const SizedBox(height: 14.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: const Icon(Icons.event_note, color: Color(0xFF003EC7), size: 20.0),
                        ),
                        const SizedBox(width: 10.0),
                        Text(
                          widget.eventToEdit != null ? 'Edit Event' : 'Create Event',
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24.0, 16.0, 24.0, bottomInset + bottomSafeArea + 32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 0. ASSIGNED TEAM SELECTOR
                    const Text(
                      'ASSIGNED TEAM',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Consumer(
                        builder: (context, ref, child) {
                          final squads = ref.watch(squadsProvider);
                          final availableTeams = squads.map((s) => s.name).toList();
                          if (availableTeams.isEmpty) {
                            availableTeams.add('Unassigned');
                          }

                          final activeTeam = availableTeams.contains(_selectedTeam) 
                              ? _selectedTeam 
                              : availableTeams.first;

                          return DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: activeTeam,
                              borderRadius: BorderRadius.circular(16.0),
                              isExpanded: true,
                              icon: const Icon(Icons.groups_outlined, color: Color(0xFF003EC7)),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14.0),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedTeam = val);
                                }
                              },
                              items: availableTeams.map((t) {
                                return DropdownMenuItem<String>(
                                  value: t,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.shield_outlined, size: 16.0, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 8.0),
                                      Text(t == 'Unassigned' ? 'Unassigned (No Active Squad)' : t),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final squads = ref.watch(squadsProvider);
                        if (squads.isNotEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 14.0, color: Color(0xFFD97706)),
                              const SizedBox(width: 6.0),
                              const Expanded(
                                child: Text(
                                  'No active squads assigned. Squads are managed in Admin Dashboard.',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFFD97706)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20.0),

                    // 1. TRAINING TYPE SELECTOR
                    const Text(
                      'TYPE OF TRAINING',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: _eventTypes.map((type) {
                        final isSel = _selectedEventType == type;
                        IconData typeIcon = Icons.sports_soccer;
                        if (type == 'Gym') typeIcon = Icons.fitness_center;
                        if (type == 'Fitness Test' || type == 'Test Day') typeIcon = Icons.timer_outlined;
                        if (type == 'Match') typeIcon = Icons.emoji_events_outlined;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3.0),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedEventType = type;
                                  if (type == 'Match' || type == 'Fitness Test' || type == 'Test Day') {
                                    _isImportant = true;
                                  } else {
                                    _isImportant = false;
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFF003EC7) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: isSel ? const Color(0xFF003EC7) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(typeIcon, color: isSel ? Colors.white : const Color(0xFF64748B), size: 18.0),
                                    const SizedBox(height: 4.0),
                                    Text(
                                      type,
                                      style: TextStyle(
                                        color: isSel ? Colors.white : const Color(0xFF0F172A),
                                        fontSize: 11.5,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20.0),

                    // 2. EVENT TITLE (BLANK BY DEFAULT - CUSTOM USER INPUT)
                    const Text(
                      'EVENT TITLE',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Enter event title...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14.0),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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
                          borderSide: const BorderSide(color: Color(0xFF003EC7), width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter an event title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8.0),

                    // Displays user's previously entered event titles for this training type
                    if ((_userTitleHistory[_selectedEventType] ?? []).isNotEmpty) ...[
                      const Text(
                        'Recent Event Titles:',
                        style: TextStyle(fontSize: 11.0, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4.0),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: (_userTitleHistory[_selectedEventType]!).map((t) {
                          return ActionChip(
                            avatar: const Icon(Icons.history, size: 13.0, color: Color(0xFF003EC7)),
                            label: Text(t),
                            backgroundColor: const Color(0xFFEFF6FF),
                            labelStyle: const TextStyle(color: Color(0xFF003EC7), fontSize: 11.5, fontWeight: FontWeight.w600),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _titleController.text = t;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 20.0),

                    // 3. LOCATION INPUT WITH USER-ENTERED HISTORY MEMORY
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'LOCATION',
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        hintText: 'Enter location...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14.0),
                        prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF64748B), size: 20.0),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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
                          borderSide: const BorderSide(color: Color(0xFF003EC7), width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please specify the event location';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8.0),

                    // Displays ONLY user's previously entered locations for this training type
                    if (userLocations.isNotEmpty) ...[
                      const Text(
                        'Recent Locations:',
                        style: TextStyle(fontSize: 11.0, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4.0),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: userLocations.map((loc) {
                          return ActionChip(
                            avatar: const Icon(Icons.history, size: 13.0, color: Color(0xFF003EC7)),
                            label: Text(loc),
                            backgroundColor: const Color(0xFFEFF6FF),
                            labelStyle: const TextStyle(color: Color(0xFF003EC7), fontSize: 11.5, fontWeight: FontWeight.w600),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _locationController.text = loc;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 20.0),

                    // 4. DATE, TIME & DURATION (CRITICAL FIELDS)
                    Row(
                      children: [
                        // DATE PICKER
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DATE',
                                style: TextStyle(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              InkWell(
                                onTap: _pickDate,
                                borderRadius: BorderRadius.circular(12.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 16.0, color: Color(0xFF003EC7)),
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                        child: Text(
                                          _formatDateStr(_selectedDate),
                                          style: const TextStyle(
                                            fontSize: 13.0,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10.0),

                        // TIME PICKER
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'START TIME',
                                style: TextStyle(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              InkWell(
                                onTap: _pickTime,
                                borderRadius: BorderRadius.circular(12.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 16.0, color: Color(0xFF003EC7)),
                                      const SizedBox(width: 6.0),
                                      Text(
                                        _formatTimeStr(_selectedTime),
                                        style: const TextStyle(
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16.0),

                    // DURATION SELECTOR (FIXED: CUSTOM SEGMENTED BUTTONS, ZERO TEXT CUTOFF)
                    const Text(
                      'DURATION (MINS)',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: _durationOptions.map((dur) {
                        final isSel = _durationController.text == dur.toString();
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3.0),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _durationController.text = dur.toString();
                                });
                              },
                              borderRadius: BorderRadius.circular(10.0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 11.0),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFF003EC7) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10.0),
                                  border: Border.all(
                                    color: isSel ? const Color(0xFF003EC7) : const Color(0xFFE2E8F0),
                                    width: isSel ? 1.5 : 1.0,
                                  ),
                                  boxShadow: isSel
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF003EC7).withValues(alpha: 0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '${dur}m',
                                    style: TextStyle(
                                      color: isSel ? Colors.white : const Color(0xFF0F172A),
                                      fontSize: 13.0,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20.0),

                    // 5. WORKOUT ROUTINE PICTURE UPLOAD (HIDDEN ON MATCH DAYS)
                    if (_selectedEventType != 'Match') ...[
                      Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: const Icon(Icons.add_a_photo, color: Color(0xFF003EC7), size: 18.0),
                                ),
                                const SizedBox(width: 12.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'WORKOUT ROUTINE PHOTO',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF475569),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 2.0),
                                      Text(
                                        _attachedImagePath != null ? 'Photo attached & saved' : 'Optional picture upload for athletes',
                                        style: TextStyle(
                                          fontSize: 12.0,
                                          color: _attachedImagePath != null ? const Color(0xFF166534) : const Color(0xFF94A3B8),
                                          fontWeight: _attachedImagePath != null ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                OutlinedButton.icon(
                                  onPressed: _pickWorkoutImage,
                                  icon: Icon(_attachedImagePath != null ? Icons.edit : Icons.camera_alt, size: 14.0),
                                  label: Text(_attachedImagePath != null ? 'Change' : 'Upload'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF003EC7),
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                                  ),
                                ),
                              ],
                            ),

                            // Thumbnail preview if image was ACTUALLY chosen
                            if (_attachedImagePath != null) ...[
                              const SizedBox(height: 12.0),
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12.0),
                                    child: Container(
                                      height: 140.0,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.black12,
                                        borderRadius: BorderRadius.circular(12.0),
                                      ),
                                      child: _attachedImagePath!.startsWith('assets/')
                                          ? Image.asset(_attachedImagePath!, fit: BoxFit.cover)
                                          : Image.file(File(_attachedImagePath!), fit: BoxFit.cover),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8.0,
                                    right: 8.0,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _attachedImagePath = null;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6.0),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 16.0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),
                    ],

                    // IMPORTANT / HIGH PRIORITY SWITCH TILE
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: _isImportant ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(color: _isImportant ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0)),
                      ),
                      child: SwitchListTile(
                        value: _isImportant,
                        onChanged: (val) {
                          setState(() {
                            _isImportant = val;
                          });
                        },
                        activeThumbColor: const Color(0xFFD97706),
                        title: const Text(
                          'Mark as High Priority / Important',
                          style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        subtitle: const Text(
                          'Flags this session with a star badge on player dashboards',
                          style: TextStyle(fontSize: 11.0, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24.0),

                    // SUBMIT EVENT BUTTON (SAFEAREA AWARE WITH SOLID BACKGROUND PADDING)
                    SafeArea(
                      top: false,
                      bottom: true,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003EC7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                                )
                              : Text(
                                  widget.eventToEdit != null ? 'Update Event Details' : 'Create Event',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
