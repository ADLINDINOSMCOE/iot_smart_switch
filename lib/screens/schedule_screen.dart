import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/schedule_service.dart';

class ScheduleScreen extends StatefulWidget {
  final List<Map<String, dynamic>> switches;

  const ScheduleScreen({
    super.key,
    required this.switches,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleService _scheduleService = ScheduleService();

  String? _selectedDeviceId;

  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _turnOn = true;

  final List<String> _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  final Set<String> _selectedDays = {};

  @override
  void initState() {
    super.initState();

    if (widget.switches.isNotEmpty) {
      _selectedDeviceId = _getDeviceId(widget.switches.first);
    }
  }

  @override
  void didUpdateWidget(covariant ScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.switches.isEmpty) {
      _selectedDeviceId = null;
      return;
    }

    final exists = widget.switches.any(
      (device) => _getDeviceId(device) == _selectedDeviceId,
    );

    if (!exists) {
      setState(() {
        _selectedDeviceId = _getDeviceId(widget.switches.first);
      });
    }
  }

  // =========================================================
  // HELPERS
  // =========================================================

  String _getDeviceId(Map<String, dynamic> device) {
    return device['deviceId']?.toString() ??
        device['id']?.toString() ??
        '';
  }

  Map<String, dynamic>? get _selectedSwitch {
    if (_selectedDeviceId == null) return null;

    for (final device in widget.switches) {
      if (_getDeviceId(device) == _selectedDeviceId) {
        return device;
      }
    }

    return null;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  // =========================================================
  // SELECT TIME
  // =========================================================

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // =========================================================
  // SHOW SWITCH PICKER
  // =========================================================

  void _showSwitchPicker() {
    if (widget.switches.isEmpty) {
      _showMessage('No switches available');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Switch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...widget.switches.map(
                  (device) {
                    final deviceId = _getDeviceId(device);
                    final name = device['name']?.toString() ?? 'Switch';
                    final room = device['room']?.toString() ?? '';
                    final isSelected = deviceId == _selectedDeviceId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1C3D5C)
                            : const Color(0xFF0D2234),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF287FF0)
                              : const Color(0xFF1C3447),
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E8B47),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.power_settings_new,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: room.isNotEmpty
                            ? Text(
                                room,
                                style: const TextStyle(
                                  color: Color(0xFF91A1AF),
                                  fontSize: 13,
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF5AA9FF),
                              )
                            : const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF91A1AF),
                              ),
                        onTap: () {
                          setState(() {
                            _selectedDeviceId = deviceId;
                          });

                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // SAVE SCHEDULE
  // =========================================================

  Future<void> _saveSchedule() async {
    if (_selectedDeviceId == null || _selectedDeviceId!.isEmpty) {
      _showMessage('Please select a switch');
      return;
    }

    final selected = _selectedSwitch;
    if (selected != null && selected['canControl'] == false) {
      _showMessage('View-only access: You cannot create schedules on this device');
      return;
    }

    if (_selectedDays.isEmpty) {
      _showMessage('Please select at least one day');
      return;
    }

    try {
      await _scheduleService.addSchedule(
        deviceId: _selectedDeviceId!,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        days: _selectedDays.toList(),
        action: _turnOn ? 'on' : 'off',
      );

      if (!mounted) return;

      _showMessage('Schedule created successfully');

      setState(() {
        _selectedDays.clear();
      });
    } catch (e) {
      _showMessage('Unable to create schedule: $e');
    }
  }

  // =========================================================
  // DELETE SCHEDULE
  // =========================================================

  Future<void> _deleteSchedule(String scheduleId) async {
    if (_selectedDeviceId == null) return;

    final selected = _selectedSwitch;
    if (selected != null && selected['canControl'] == false) {
      _showMessage('View-only access: You cannot delete schedules');
      return;
    }

    try {
      await _scheduleService.deleteSchedule(
        deviceId: _selectedDeviceId!,
        scheduleId: scheduleId,
      );

      if (!mounted) return;

      _showMessage('Schedule deleted');
    } catch (_) {
      _showMessage('Unable to delete schedule');
    }
  }

  // =========================================================
  // TOGGLE SCHEDULE
  // =========================================================

  Future<void> _toggleSchedule(
    String scheduleId,
    bool enabled,
  ) async {
    if (_selectedDeviceId == null) return;

    final selected = _selectedSwitch;
    if (selected != null && selected['canControl'] == false) {
      _showMessage('View-only access: You cannot toggle schedules');
      return;
    }

    try {
      await _scheduleService.updateScheduleStatus(
        deviceId: _selectedDeviceId!,
        scheduleId: scheduleId,
        enabled: enabled,
      );
    } catch (_) {
      _showMessage('Unable to update schedule');
    }
  }

  // =========================================================
  // SNACKBAR
  // =========================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10293B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final selectedSwitch = _selectedSwitch;

    return Scaffold(
      backgroundColor: const Color(0xFF081726),
      body: SafeArea(
        child: widget.switches.isEmpty
            ? const Center(
                child: Text(
                  'No switches available',
                  style: TextStyle(
                    color: Color(0xFF91A1AF),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  24,
                ),
                children: [
                  const SizedBox(
                    height: 42,
                    child: Center(
                      child: Text(
                        'Schedule',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildCreateScheduleCard(selectedSwitch),
                  const SizedBox(height: 26),
                  const Text(
                    'Scheduled Tasks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildScheduleList(),
                ],
              ),
      ),
    );
  }

  // =========================================================
  // CREATE SCHEDULE CARD
  // =========================================================

  Widget _buildCreateScheduleCard(Map<String, dynamic>? selectedSwitch) {
    final switchName = selectedSwitch?['name']?.toString() ?? 'Select Switch';
    final room = selectedSwitch?['room']?.toString() ?? '';
    final bool canControl = selectedSwitch?['canControl'] != false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2234),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF1C3447),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!canControl) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF282315),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF59451C)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Color(0xFFE5B558), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'View-Only permission: Schedule creation is disabled for this switch.',
                      style: TextStyle(color: Color(0xFFE5B558), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // SWITCH SELECTOR
          const Text(
            'Select Switch',
            style: TextStyle(
              color: Color(0xFF91A1AF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          InkWell(
            onTap: _showSwitchPicker,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF1C3447),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E8B47),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.power_settings_new,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switchName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (room.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            room,
                            style: const TextStyle(
                              color: Color(0xFF91A1AF),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF91A1AF),
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // TIME
          const Text(
            'Time',
            style: TextStyle(
              color: Color(0xFF91A1AF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          InkWell(
            onTap: canControl ? _selectTime : null,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF10293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF1C3447),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    color: Color(0xFF5AA9FF),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatTime(_selectedTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (canControl)
                    const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF91A1AF),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ACTION
          const Text(
            'Action',
            style: TextStyle(
              color: Color(0xFF91A1AF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  title: 'Turn ON',
                  icon: Icons.power_settings_new,
                  selected: _turnOn,
                  onTap: canControl
                      ? () {
                          setState(() {
                            _turnOn = true;
                          });
                        }
                      : () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  title: 'Turn OFF',
                  icon: Icons.power_off_outlined,
                  selected: !_turnOn,
                  onTap: canControl
                      ? () {
                          setState(() {
                            _turnOn = false;
                          });
                        }
                      : () {},
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // DAYS
          const Text(
            'Repeat On',
            style: TextStyle(
              color: Color(0xFF91A1AF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _days.map((day) {
              final selected = _selectedDays.contains(day);

              return InkWell(
                onTap: canControl
                    ? () {
                        setState(() {
                          if (selected) {
                            _selectedDays.remove(day);
                          } else {
                            _selectedDays.add(day);
                          }
                        });
                      }
                    : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF287FF0)
                        : const Color(0xFF10293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF287FF0)
                          : const Color(0xFF1C3447),
                    ),
                  ),
                  child: Text(
                    day,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF91A1AF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 26),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: canControl ? _saveSchedule : null,
              icon: const Icon(
                Icons.add_circle_outline,
              ),
              label: Text(
                canControl ? 'Create Schedule' : 'View Only (Locked)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF287FF0),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF294354),
                disabledForegroundColor: const Color(0xFF91A1AF),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ACTION BUTTON
  // =========================================================

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF287FF0) : const Color(0xFF10293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF287FF0) : const Color(0xFF1C3447),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFF91A1AF),
              size: 20,
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF91A1AF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SCHEDULE LIST (SUBCOLLECTION)
  // =========================================================

  Widget _buildScheduleList() {
    if (_selectedDeviceId == null || _selectedDeviceId!.isEmpty) {
      return _emptyScheduleCard(
        icon: Icons.calendar_today_outlined,
        text: 'Select a switch to view schedules',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _scheduleService.getSchedules(_selectedDeviceId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyScheduleCard(
            icon: Icons.error_outline,
            text: 'Unable to load schedules: ${snapshot.error}',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: Color(0xFF5AA9FF),
              ),
            ),
          );
        }

        final schedules = snapshot.data?.docs ?? [];

        if (schedules.isEmpty) {
          return _emptyScheduleCard(
            icon: Icons.calendar_today_outlined,
            text: 'No schedules created for this switch',
          );
        }

        return Column(
          children: schedules.map((doc) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: _buildScheduleTile(
                doc.id,
                doc.data(),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // =========================================================
  // SCHEDULE TILE
  // =========================================================

  Widget _buildScheduleTile(
    String scheduleId,
    Map<String, dynamic> data,
  ) {
    final deviceId = data['deviceId']?.toString() ?? '';
    final hour = (data['hour'] ?? 0) as int;
    final minute = (data['minute'] ?? 0) as int;
    final action = data['action']?.toString() ?? 'on';
    final enabled = data['enabled'] == true;
    final bool canControl = _selectedSwitch?['canControl'] != false;

    final List<dynamic> days =
        data['days'] is List ? data['days'] as List<dynamic> : [];

    String switchName = 'Switch';
    for (final device in widget.switches) {
      if (_getDeviceId(device) == deviceId) {
        switchName = device['name']?.toString() ?? 'Switch';
        break;
      }
    }

    final time = TimeOfDay(
      hour: hour,
      minute: minute,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2234),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF1C3447),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: action == 'on'
                  ? const Color(0xFF2E8B47)
                  : const Color(0xFF3B2B35),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              action == 'on'
                  ? Icons.power_settings_new
                  : Icons.power_off_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switchName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatTime(time)} • ${action.toUpperCase()}',
                  style: const TextStyle(
                    color: Color(0xFF91A1AF),
                    fontSize: 13,
                  ),
                ),
                if (days.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    days.join(', '),
                    style: const TextStyle(
                      color: Color(0xFF5AA9FF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: enabled,
                activeColor: const Color(0xFF287FF0),
                onChanged: canControl
                    ? (value) {
                        _toggleSchedule(
                          scheduleId,
                          value,
                        );
                      }
                    : (value) {
                        _showMessage('View-only access: Cannot modify schedule');
                      },
              ),
              if (canControl)
                IconButton(
                  onPressed: () {
                    _showDeleteDialog(
                      scheduleId,
                    );
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFFF6B6B),
                    size: 20,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // EMPTY SCHEDULE CARD
  // =========================================================

  Widget _emptyScheduleCard({
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2234),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF1C3447),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF607080),
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF91A1AF),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DELETE DIALOG
  // =========================================================

  void _showDeleteDialog(
    String scheduleId,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10293B),
          title: const Text(
            'Delete Schedule?',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: const Text(
            'This schedule will be permanently deleted.',
            style: TextStyle(
              color: Color(0xFF91A1AF),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF91A1AF),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteSchedule(scheduleId);
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}