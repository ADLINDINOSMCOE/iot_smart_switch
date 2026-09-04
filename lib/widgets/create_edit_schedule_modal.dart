import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../models/switch_model.dart';
import '../services/schedule_service.dart';
import '../services/switch_service.dart';

class CreateEditScheduleModal extends StatefulWidget {
  final SwitchModel? initialSwitch;
  final ScheduleModel? existingSchedule;
  final ScheduleService? scheduleService;
  final SwitchService? switchService;

  const CreateEditScheduleModal({
    super.key,
    this.initialSwitch,
    this.existingSchedule,
    this.scheduleService,
    this.switchService,
  });

  static Future<void> show(
    BuildContext context, {
    SwitchModel? initialSwitch,
    ScheduleModel? existingSchedule,
    ScheduleService? scheduleService,
    SwitchService? switchService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateEditScheduleModal(
        initialSwitch: initialSwitch,
        existingSchedule: existingSchedule,
        scheduleService: scheduleService,
        switchService: switchService,
      ),
    );
  }

  @override
  State<CreateEditScheduleModal> createState() =>
      _CreateEditScheduleModalState();
}

class _CreateEditScheduleModalState extends State<CreateEditScheduleModal> {
  late final ScheduleService _scheduleService;
  late final SwitchService _switchService;

  String? _selectedSwitchId;
  String _selectedAction = 'on'; // "on" or "off"
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  List<String> _selectedDays = [];
  bool _isSubmitting = false;

  List<SwitchModel> _availableSwitches = [];
  bool _loadingSwitches = true;

  @override
  void initState() {
    super.initState();
    _scheduleService = widget.scheduleService ?? ScheduleService.instance;
    _switchService = widget.switchService ?? SwitchService.instance;

    if (widget.existingSchedule != null) {
      final s = widget.existingSchedule!;
      _selectedSwitchId = s.switchId;
      _selectedAction = s.action;
      _selectedDays = List.from(s.repeatDays);
      final localTime = s.time.toLocal();
      _selectedDate = DateTime(localTime.year, localTime.month, localTime.day);
      _selectedTime =
          TimeOfDay(hour: localTime.hour, minute: localTime.minute);
    } else {
      _selectedSwitchId = widget.initialSwitch?.id;
      // Default to 1 hour from now
      final now = DateTime.now().add(const Duration(hours: 1));
      _selectedDate = DateTime(now.year, now.month, now.day);
      _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
    }

    _loadSwitches();
  }

  Future<void> _loadSwitches() async {
    if (widget.initialSwitch != null) {
      setState(() {
        _availableSwitches = [widget.initialSwitch!];
        _selectedSwitchId ??= widget.initialSwitch!.id;
        _loadingSwitches = false;
      });
      return;
    }

    try {
      final switches = await _switchService.getSwitches();
      if (mounted) {
        setState(() {
          _availableSwitches = switches;
          if (_selectedSwitchId == null && switches.isNotEmpty) {
            _selectedSwitchId = switches.first.id;
          }
          _loadingSwitches = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _availableSwitches = SwitchService.sampleSwitches;
          _selectedSwitchId ??= SwitchService.sampleSwitches.first.id;
          _loadingSwitches = false;
        });
      }
    }
  }

  DateTime _computeTargetDateTime() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _handleSave() async {
    if (_selectedSwitchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a target switch.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final targetDateTime = _computeTargetDateTime();

    if (targetDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduled time must be in the future.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.existingSchedule != null) {
        await _scheduleService.updateSchedule(
          scheduleId: widget.existingSchedule!.id,
          action: _selectedAction,
          targetTime: targetDateTime,
          repeatDays: _selectedDays,
        );
      } else {
        await _scheduleService.createSchedule(
          switchId: _selectedSwitchId!,
          action: _selectedAction,
          targetTime: targetDateTime,
          repeatDays: _selectedDays,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingSchedule != null
                  ? 'Schedule updated successfully.'
                  : 'Schedule created for ${_formatTime(targetDateTime)}.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save schedule: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final targetDateTime = _computeTargetDateTime();
    final tzOffset = DateTime.now().timeZoneOffset;
    final tzOffsetHours = tzOffset.inHours;
    final tzOffsetMins = (tzOffset.inMinutes % 60).abs();
    final tzString =
        'UTC${tzOffsetHours >= 0 ? "+" : ""}$tzOffsetHours:${tzOffsetMins.toString().padLeft(2, "0")} (${DateTime.now().timeZoneName})';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: Color(0xFF0284C7),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existingSchedule != null
                            ? 'Edit Schedule'
                            : 'Create New Schedule',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        'Stored in UTC • Displayed in Local Time',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Target Switch Selector
            const Text(
              'Target Switch',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (_loadingSwitches)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                value: _selectedSwitchId,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                ),
                items: _availableSwitches.map((sw) {
                  return DropdownMenuItem<String>(
                    value: sw.id,
                    child: Text('${sw.name} (${sw.room})'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedSwitchId = val);
                },
              ),
            const SizedBox(height: 16),

            // Action Selector (Turn ON vs Turn OFF)
            const Text(
              'Action',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'on',
                  label: Text('Turn ON'),
                  icon: Icon(Icons.power_rounded),
                ),
                ButtonSegment<String>(
                  value: 'off',
                  label: Text('Turn OFF'),
                  icon: Icon(Icons.power_off_rounded),
                ),
              ],
              selected: {_selectedAction},
              onSelectionChanged: (newSelection) {
                setState(() => _selectedAction = newSelection.first);
              },
            ),
            const SizedBox(height: 16),

            // Time & Date Picker Controls
            Row(
              children: [
                // Time Picker
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Time',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (picked != null) {
                            setState(() => _selectedTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedTime.format(context),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const Icon(Icons.access_time, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Date Picker
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const Icon(Icons.calendar_month, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Repeat Days Selector
            const Text(
              'Repeat (Optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                  FilterChip(
                    label: Text(day, style: const TextStyle(fontSize: 12)),
                    selected: _selectedDays.contains(day.toLowerCase()),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(day.toLowerCase());
                        } else {
                          _selectedDays.remove(day.toLowerCase());
                        }
                      });
                    },
                    selectedColor: const Color(0xFF0284C7).withAlpha(50),
                    checkmarkColor: const Color(0xFF0284C7),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Timezone Indicator
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.public_rounded,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Timezone: $tzString',
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSave,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.existingSchedule != null
                            ? 'Save Schedule Changes'
                            : 'Set Schedule (${_selectedAction.toUpperCase()} at ${_formatTime(targetDateTime)})',
                        style: const TextStyle(fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
