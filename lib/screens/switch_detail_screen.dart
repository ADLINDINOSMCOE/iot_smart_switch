import 'dart:async';

import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class SwitchDetailScreen extends StatefulWidget {
  final String deviceId;
  final String name;
  final String room;
  final bool isOn;
  final IconData icon;
  final ValueChanged<bool> onChanged;
  final VoidCallback onBack;
  final bool canControl;
  final String role;

  const SwitchDetailScreen({
    super.key,
    required this.deviceId,
    required this.name,
    required this.room,
    required this.isOn,
    required this.icon,
    required this.onChanged,
    required this.onBack,
    this.canControl = true,
    this.role = 'Owner',
  });

  @override
  State<SwitchDetailScreen> createState() =>
      _SwitchDetailScreenState();
}

class _SwitchDetailScreenState
    extends State<SwitchDetailScreen> {
  final FirestoreService _firestoreService =
  FirestoreService();

  late bool isOn;

  // Selected statistics date.
  DateTime _selectedDate = DateTime.now();

  // Statistics values.
  int _runtimeSeconds = 0;
  double _energyKwh = 0.0;

  bool _loadingStatistics = true;

  Timer? _statisticsTimer;

  // Used to prevent an older async request from
  // replacing a newer date's statistics.
  int _statisticsRequestId = 0;

  @override
  void initState() {
    super.initState();

    isOn = widget.isOn;

    _loadStatistics();

    // Refresh today's statistics every 10 seconds.
    _statisticsTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) {
        if (_isToday(_selectedDate)) {
          _loadStatistics();
        }
      },
    );
  }

  @override
  void didUpdateWidget(
      covariant SwitchDetailScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    // Update ON/OFF state from parent.
    if (oldWidget.isOn != widget.isOn) {
      setState(() {
        isOn = widget.isOn;
      });

      _loadStatistics();
    }

    // If a different device is opened in the same screen,
    // load that device's statistics.
    if (oldWidget.deviceId != widget.deviceId) {
      setState(() {
        _selectedDate = DateTime.now();
        _runtimeSeconds = 0;
        _energyKwh = 0.0;
        _loadingStatistics = true;
      });

      _loadStatistics();
    }
  }

  @override
  void dispose() {
    _statisticsTimer?.cancel();
    super.dispose();
  }

  // =========================================================
  // DATE HELPERS
  // =========================================================

  bool _isToday(DateTime date) {
    final now = DateTime.now();

    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(
      const Duration(days: 1),
    );

    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  String _formatDate(DateTime date) {
    if (_isToday(date)) {
      return 'Today';
    }

    if (_isYesterday(date)) {
      return 'Yesterday';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // =========================================================
  // LOAD POWER STATISTICS
  // =========================================================

  Future<void> _loadStatistics() async {
    final requestId = ++_statisticsRequestId;

    try {
      final statistics =
      await _firestoreService.getPowerStatistics(
        deviceId: widget.deviceId,
        date: _selectedDate,
      );

      if (!mounted) {
        return;
      }

      // Ignore an older request if another request
      // has already started.
      if (requestId != _statisticsRequestId) {
        return;
      }

      final runtimeValue =
      statistics['runtimeSeconds'];

      final energyValue =
      statistics['energyKwh'];

      setState(() {
        _runtimeSeconds =
        runtimeValue is num
            ? runtimeValue.toInt()
            : 0;

        _energyKwh =
        energyValue is num
            ? energyValue.toDouble()
            : 0.0;

        _loadingStatistics = false;
      });
    } catch (e) {
      debugPrint(
        'POWER STATISTICS ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      if (requestId != _statisticsRequestId) {
        return;
      }

      setState(() {
        _loadingStatistics = false;
      });
    }
  }

  // =========================================================
  // DATE PICKER
  // =========================================================

  Future<void> _selectDate() async {
    final today = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,

      initialDate: _selectedDate.isAfter(today)
          ? today
          : _selectedDate,

      firstDate: DateTime(2020),

      lastDate: DateTime(
        today.year,
        today.month,
        today.day,
      ),

      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF5AA9FF),
              surface: Color(0xFF0D2234),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF0D2234),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );

      _loadingStatistics = true;
      _runtimeSeconds = 0;
      _energyKwh = 0.0;
    });

    await _loadStatistics();
  }

  // =========================================================
  // RUNTIME FORMAT
  // =========================================================

  String _formatRuntime(int seconds) {
    if (seconds <= 0) {
      return '0m';
    }

    final hours = seconds ~/ 3600;

    final minutes =
        (seconds % 3600) ~/ 60;

    if (hours > 0) {
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }

      return '${hours}h';
    }

    return '${minutes}m';
  }

  // =========================================================
  // TOGGLE SWITCH
  // =========================================================

  void _toggleSwitch() {
    if (!widget.canControl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'View-only access. You cannot toggle this relay.',
          ),
          backgroundColor: Color(0xFF10293B),
        ),
      );

      return;
    }

    final newValue = !isOn;

    setState(() {
      isOn = newValue;
    });

    widget.onChanged(newValue);

    // Give Firestore a moment to update and then
    // refresh today's statistics.
    Future.delayed(
      const Duration(milliseconds: 700),
          () {
        if (!mounted) {
          return;
        }

        if (_isToday(_selectedDate)) {
          _loadStatistics();
        }
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24,
        ),
        child: Column(
          children: [
            // =================================================
            // BACK + DEVICE INFO + ROLE
            // =================================================

            Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 25,
                  ),
                ),

                const SizedBox(width: 4),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        widget.room,
                        style: const TextStyle(
                          color: Color(0xFF91A1AF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.canControl
                        ? const Color(0xFF1C4232)
                        : const Color(0xFF353022),
                    borderRadius:
                    BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.role,
                    style: TextStyle(
                      color: widget.canControl
                          ? const Color(0xFF5DD879)
                          : const Color(0xFFE5B558),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            // =================================================
            // VIEW ONLY MESSAGE
            // =================================================

            if (!widget.canControl) ...[
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF282315),
                  borderRadius:
                  BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF59451C),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: Color(0xFFE5B558),
                      size: 18,
                    ),

                    SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        'You have View-Only access to this device.',
                        style: TextStyle(
                          color: Color(0xFFE5B558),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // =================================================
            // POWER BUTTON
            // =================================================

            GestureDetector(
              onTap: _toggleSwitch,
              child: AnimatedContainer(
                duration:
                const Duration(milliseconds: 250),
                width: 174,
                height: 174,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF132B3C),
                  border: Border.all(
                    color: isOn
                        ? const Color(0xFF52D66C)
                        : const Color(0xFF344554),
                    width: 4,
                  ),
                  boxShadow: isOn
                      ? [
                    BoxShadow(
                      color: const Color(
                        0xFF45B85D,
                      ).withValues(alpha: 0.20),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ]
                      : [],
                ),
                child: Center(
                  child: Container(
                    width: 145,
                    height: 145,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                      const Color(0xFF081726),
                      border: Border.all(
                        color: isOn
                            ? const Color(0xFF52D66C)
                            : const Color(0xFF344554),
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.power_settings_new,
                      size: 62,
                      color: isOn
                          ? Colors.white
                          : const Color(0xFF8A99A8),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // STATUS
            // =================================================

            Row(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Text(
                  isOn ? 'ON' : 'OFF',
                  style: TextStyle(
                    color: isOn
                        ? const Color(0xFF5DD879)
                        : const Color(0xFF8A99A8),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(width: 16),

                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOn
                        ? const Color(0xFF5DD879)
                        : const Color(0xFF7E8C98),
                  ),
                ),

                const SizedBox(width: 6),

                const Text(
                  'Online',
                  style: TextStyle(
                    color: Color(0xFF91A1AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // =================================================
            // POWER STATISTICS
            // =================================================

            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.fromLTRB(
                14,
                12,
                14,
                16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2234),
                borderRadius:
                BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF1C3447),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // -------------------------------------------
                  // TITLE + DATE DROPDOWN
                  // -------------------------------------------

                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Power Statistics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      InkWell(
                        onTap: _selectDate,
                        borderRadius:
                        BorderRadius.circular(6),
                        child: Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color:
                            const Color(0xFF10293B),
                            borderRadius:
                            BorderRadius.circular(6),
                            border: Border.all(
                              color:
                              const Color(0xFF294354),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _formatDate(
                                  _selectedDate,
                                ),
                                style:
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),

                              const SizedBox(width: 4),

                              const Icon(
                                Icons
                                    .keyboard_arrow_down,
                                color:
                                Color(0xFF91A1AF),
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // -------------------------------------------
                  // STATISTICS
                  // -------------------------------------------

                  Row(
                    children: [
                      Expanded(
                        child: _statItem(
                          title: 'Runtime',
                          value: _loadingStatistics
                              ? 'Loading...'
                              : _formatRuntime(
                            _runtimeSeconds,
                          ),
                        ),
                      ),

                      Expanded(
                        child: _statItem(
                          title: 'Energy Used',
                          value: _loadingStatistics
                              ? 'Loading...'
                              : '${_energyKwh.toStringAsFixed(2)} kWh',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // STAT ITEM
  // =========================================================

  Widget _statItem({
    required String title,
    required String value,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF91A1AF),
            fontSize: 11,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}