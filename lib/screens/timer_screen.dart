import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TimerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> switches;

  const TimerScreen({
    super.key,
    required this.switches,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedDeviceId;
  Timer? _uiTimer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();

    if (widget.switches.isNotEmpty) {
      _selectedDeviceId = _getDeviceId(widget.switches.first);
    }

    _uiTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (mounted) {
          _updateTimer();
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSelectedTimer();
    });
  }

  @override
  void didUpdateWidget(covariant TimerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.switches.isEmpty) {
      _selectedDeviceId = null;
      return;
    }

    final exists = widget.switches.any(
          (device) => _getDeviceId(device) == _selectedDeviceId,
    );

    if (!exists) {
      _selectedDeviceId = _getDeviceId(widget.switches.first);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSelectedTimer();
      });
    }
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
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

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 0) {
      totalSeconds = 0;
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    int hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$hour:$minute $period';
  }

  // =========================================================
  // LOAD SELECTED TIMER
  // =========================================================
  Future<void> _loadSelectedTimer() async {
    if (_selectedDeviceId == null || _selectedDeviceId!.isEmpty) {
      return;
    }

    try {
      final doc = await _firestore
          .collection('switches')
          .doc(_selectedDeviceId)
          .get();

      if (!mounted) return;

      final data = doc.data();
      if (data == null) {
        setState(() {
          _elapsedSeconds = 0;
          _isRunning = false;
        });
        return;
      }

      final isActive = data['timerActive'] == true;
      final startedAt = data['timerStartedAt'];

      if (isActive && startedAt is Timestamp) {
        final startTime = startedAt.toDate();
        int seconds = DateTime.now().difference(startTime).inSeconds;
        if (seconds < 0) seconds = 0;

        setState(() {
          _elapsedSeconds = seconds;
          _isRunning = true;
        });
      } else {
        setState(() {
          _elapsedSeconds = 0;
          _isRunning = false;
        });
      }
    } catch (_) {}
  }

  // =========================================================
  // UPDATE TIMER EVERY SECOND
  // =========================================================
  Future<void> _updateTimer() async {
    if (!_isRunning) return;
    if (_selectedDeviceId == null || _selectedDeviceId!.isEmpty) return;

    try {
      final doc = await _firestore
          .collection('switches')
          .doc(_selectedDeviceId)
          .get();

      if (!mounted || !doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      final isActive = data['timerActive'] == true;
      final startedAt = data['timerStartedAt'];

      if (!isActive || startedAt is! Timestamp) {
        if (mounted) {
          setState(() {
            _isRunning = false;
            _elapsedSeconds = 0;
          });
        }
        return;
      }

      int seconds = DateTime.now().difference(startedAt.toDate()).inSeconds;
      if (seconds < 0) seconds = 0;

      if (mounted) {
        setState(() {
          _elapsedSeconds = seconds;
          _isRunning = true;
        });
      }
    } catch (_) {}
  }

  // =========================================================
  // START TIMER
  // =========================================================
  Future<void> _startTimer() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      _showMessage('Please login to start a timer');
      return;
    }

    if (_selectedDeviceId == null || _selectedDeviceId!.isEmpty) {
      _showMessage('Please select a switch');
      return;
    }

    final selected = _selectedSwitch;
    if (selected != null && selected['canControl'] == false) {
      _showMessage('View-only permission: You cannot start timers on this device');
      return;
    }

    if (_isRunning) {
      _showMessage('Timer is already running');
      return;
    }

    try {
      final now = DateTime.now();
      final switchRef = _firestore.collection('switches').doc(_selectedDeviceId);

      // Create history document in subcollection
      final historyRef = await switchRef.collection('timerHistory').add({
        'startedAt': Timestamp.fromDate(now),
        'stoppedAt': null,
        'durationSeconds': 0,
        'status': 'active',
        'mode': 'countUp',
        'startedBy': currentUid,
      });

      // Set active timer
      await switchRef.set(
        {
          'timerActive': true,
          'timerStartedAt': Timestamp.fromDate(now),
          'timerDurationSeconds': 0,
          'activeTimerHistoryId': historyRef.id,
          'lastUpdatedBy': currentUid,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _elapsedSeconds = 0;
        _isRunning = true;
      });

      _showMessage('Timer started');
    } catch (e) {
      _showMessage('Unable to start timer: $e');
    }
  }

  // =========================================================
  // STOP TIMER + SAVE HISTORY
  // =========================================================
  Future<void> _stopTimer(
      String deviceId,
      Map<String, dynamic> data,
      ) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      _showMessage('Please login to perform this action');
      return;
    }

    final dev = widget.switches.firstWhere(
      (s) => _getDeviceId(s) == deviceId,
      orElse: () => {},
    );
    if (dev.isNotEmpty && dev['canControl'] == false) {
      _showMessage('View-only access: You cannot stop timers on this device');
      return;
    }

    try {
      final switchRef = _firestore.collection('switches').doc(deviceId);
      final startedAt = data['timerStartedAt'];

      int durationSeconds = 0;
      if (startedAt is Timestamp) {
        durationSeconds = DateTime.now().difference(startedAt.toDate()).inSeconds;
        if (durationSeconds < 0) durationSeconds = 0;
      }

      final historyId = data['activeTimerHistoryId']?.toString();
      final batch = _firestore.batch();

      // Stop timer in switch document
      batch.set(
        switchRef,
        {
          'timerActive': false,
          'timerStartedAt': FieldValue.delete(),
          'timerDurationSeconds': durationSeconds,
          'activeTimerHistoryId': FieldValue.delete(),
          'lastUpdatedBy': currentUid,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Update timer history
      if (historyId != null && historyId.isNotEmpty) {
        final historyRef = switchRef.collection('timerHistory').doc(historyId);
        batch.set(
          historyRef,
          {
            'stoppedAt': Timestamp.now(),
            'durationSeconds': durationSeconds,
            'status': 'stopped',
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (!mounted) return;

      if (deviceId == _selectedDeviceId) {
        setState(() {
          _isRunning = false;
          _elapsedSeconds = 0;
        });
      }

      _showMessage('Timer stopped and saved to history');
    } catch (e) {
      _showMessage('Unable to stop timer: $e');
    }
  }

  void _resetTimer() {
    final selected = _selectedSwitch;
    if (selected != null && selected['canControl'] == false) {
      _showMessage('View-only access: You cannot reset timers');
      return;
    }

    if (_isRunning) {
      _showMessage('Stop the timer before resetting');
      return;
    }

    setState(() {
      _elapsedSeconds = 0;
    });
  }

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
            _buildHeader(),
            const SizedBox(height: 18),
            _buildTimerCard(selectedSwitch),
            const SizedBox(height: 24),
            const Text(
              'Active Timers',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildActiveTimers(),
            const SizedBox(height: 24),
            const Text(
              'Timer History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildTimerHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const SizedBox(
      height: 42,
      child: Center(
        child: Text(
          'Timer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTimerCard(Map<String, dynamic>? selectedSwitch) {
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
                      'View-Only permission: Timer controls are disabled for this switch.',
                      style: TextStyle(color: Color(0xFFE5B558), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          _buildSwitchSelector(selectedSwitch),
          const SizedBox(height: 24),
          const Text(
            'Elapsed Time',
            style: TextStyle(
              color: Color(0xFF91A1AF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _formatDuration(_elapsedSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w300,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: !canControl
                        ? null
                        : (_isRunning ? null : _startTimer),
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      size: 24,
                    ),
                    label: Text(
                      _isRunning
                          ? 'Running'
                          : (canControl ? 'Start Timer' : 'View Only'),
                      style: const TextStyle(
                        fontSize: 17,
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
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 54,
                width: 54,
                child: OutlinedButton(
                  onPressed: !canControl
                      ? null
                      : (_isRunning
                      ? _stopSelectedTimer
                      : (_elapsedSeconds > 0 ? _resetTimer : null)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _isRunning
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFF5AA9FF),
                    ),
                    foregroundColor: _isRunning
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF5AA9FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: Icon(
                    _isRunning
                        ? Icons.stop_rounded
                        : Icons.refresh_rounded,
                    size: 23,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _stopSelectedTimer() async {
    if (_selectedDeviceId == null) return;

    try {
      final doc = await _firestore
          .collection('switches')
          .doc(_selectedDeviceId)
          .get();

      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;

      if (mounted) {
        _showStopTimerDialog(doc.id, data);
      }
    } catch (_) {}
  }

  Widget _buildSwitchSelector(Map<String, dynamic>? selectedSwitch) {
    final name = selectedSwitch?['name']?.toString() ?? 'Switch';
    final room = selectedSwitch?['room']?.toString() ?? '';

    return InkWell(
      onTap: _showSwitchPicker,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF2E8B47),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.power_settings_new,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  room.isEmpty ? 'No room' : room,
                  style: const TextStyle(
                    color: Color(0xFF91A1AF),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF91A1AF),
            size: 26,
          ),
        ],
      ),
    );
  }

  void _showSwitchPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
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
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ...widget.switches.map(
                      (device) {
                    final id = _getDeviceId(device);
                    final name = device['name']?.toString() ?? 'Switch';
                    final room = device['room']?.toString() ?? '';

                    return ListTile(
                      leading: const Icon(
                        Icons.power_settings_new,
                        color: Color(0xFF65D881),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        room,
                        style: const TextStyle(
                          color: Color(0xFF91A1AF),
                          fontSize: 13,
                        ),
                      ),
                      trailing: id == _selectedDeviceId
                          ? const Icon(
                        Icons.check_circle,
                        color: Color(0xFF5AA9FF),
                      )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedDeviceId = id;
                          _elapsedSeconds = 0;
                          _isRunning = false;
                        });
                        _loadSelectedTimer();
                      },
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
  // ACTIVE TIMERS (From Authorized Switches)
  // =========================================================
  Widget _buildActiveTimers() {
    final activeSwitches = widget.switches.where((s) => s['timerActive'] == true).toList();

    if (activeSwitches.isEmpty) {
      return _emptyCard(
        icon: Icons.timer_off_outlined,
        text: 'No active timers',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2234),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF1C3447),
        ),
      ),
      child: Column(
        children: List.generate(
          activeSwitches.length,
              (index) {
            final device = activeSwitches[index];
            final deviceId = _getDeviceId(device);

            return Column(
              children: [
                _activeTimerTile(deviceId, device),
                if (index != activeSwitches.length - 1)
                  const Divider(
                    height: 1,
                    color: Color(0xFF1C3447),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _activeTimerTile(
      String deviceId,
      Map<String, dynamic> data,
      ) {
    final name = data['name']?.toString() ?? 'Switch';
    final room = data['room']?.toString() ?? '';
    final startedAt = data['timerStartedAt'];

    int elapsedSeconds = 0;
    if (startedAt is Timestamp) {
      elapsedSeconds = DateTime.now().difference(startedAt.toDate()).inSeconds;
      if (elapsedSeconds < 0) elapsedSeconds = 0;
    } else if (startedAt is DateTime) {
      elapsedSeconds = DateTime.now().difference(startedAt).inSeconds;
      if (elapsedSeconds < 0) elapsedSeconds = 0;
    }

    final dev = widget.switches.firstWhere(
      (s) => _getDeviceId(s) == deviceId,
      orElse: () => data,
    );
    final bool canControl = dev['canControl'] != false;

    return InkWell(
      onTap: canControl
          ? () {
              _showStopTimerDialog(deviceId, data);
            }
          : () {
              _showMessage('View-only permission: You cannot stop this timer.');
            },
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF2E8B47),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.timer_outlined,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (room.isNotEmpty)
                    Text(
                      room,
                      style: const TextStyle(
                        color: Color(0xFF91A1AF),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              _formatDuration(elapsedSeconds),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.stop_circle_outlined,
              color: Color(0xFFFF6B6B),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // TIMER HISTORY
  // =========================================================
  Widget _buildTimerHistory() {
    if (_selectedDeviceId == null || _selectedDeviceId!.isEmpty) {
      return _emptyCard(
        icon: Icons.history,
        text: 'No timer history',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('switches')
          .doc(_selectedDeviceId)
          .collection('timerHistory')
          .orderBy('startedAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyCard(
            icon: Icons.error_outline,
            text: 'Unable to load timer history',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                color: Color(0xFF5AA9FF),
              ),
            ),
          );
        }

        final allHistory = snapshot.data?.docs ?? [];
        final history = allHistory.where((doc) {
          final status = doc.data()['status']?.toString();
          return status != 'active';
        }).toList();

        if (history.isEmpty) {
          return _emptyCard(
            icon: Icons.history,
            text: 'No timer history',
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D2234),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFF1C3447),
            ),
          ),
          child: Column(
            children: List.generate(
              history.length,
                  (index) {
                return Column(
                  children: [
                    _buildHistoryTile(history[index].data()),
                    if (index != history.length - 1)
                      const Divider(
                        height: 1,
                        color: Color(0xFF1C3447),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> data) {
    final startedAt = data['startedAt'];
    final stoppedAt = data['stoppedAt'];

    final dynamic durationValue = data['durationSeconds'] ?? 0;
    int durationSeconds = 0;

    if (durationValue is int) {
      durationSeconds = durationValue;
    } else if (durationValue is num) {
      durationSeconds = durationValue.toInt();
    }

    DateTime? startTime;
    DateTime? stopTime;

    if (startedAt is Timestamp) startTime = startedAt.toDate();
    if (stoppedAt is Timestamp) stopTime = stoppedAt.toDate();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF20384A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.history,
              color: Color(0xFF5AA9FF),
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDuration(durationSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                if (startTime != null)
                  Text(
                    'Started: ${_formatTime(startTime)}',
                    style: const TextStyle(
                      color: Color(0xFF91A1AF),
                      fontSize: 13,
                    ),
                  ),
                if (stopTime != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Stopped: ${_formatTime(stopTime)}',
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
            Icons.check_circle,
            color: Color(0xFF5DD879),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF91A1AF),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showStopTimerDialog(
      String deviceId,
      Map<String, dynamic> data,
      ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10293B),
          title: const Text(
            'Stop Timer?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          content: const Text(
            'The timer will stop and be saved to Timer History.',
            style: TextStyle(
              color: Color(0xFF91A1AF),
              fontSize: 14,
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
              onPressed: () async {
                Navigator.pop(context);
                await _stopTimer(deviceId, data);
              },
              child: const Text(
                'Stop',
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