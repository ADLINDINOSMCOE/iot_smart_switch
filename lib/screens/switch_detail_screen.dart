import 'dart:async';
import 'package:flutter/material.dart';
import '../models/activity_log_model.dart';
import '../models/device_model.dart';
import '../models/schedule_model.dart';
import '../models/switch_model.dart';
import '../services/activity_log_service.dart';
import '../services/schedule_service.dart';
import '../services/switch_service.dart';
import '../services/timer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/create_edit_schedule_modal.dart';
import '../widgets/custom_card.dart';
import '../widgets/set_timer_modal.dart';
import '../widgets/status_badge.dart';

class SwitchDetailScreen extends StatefulWidget {
  final SwitchModel switchModel;
  final DeviceModel? deviceModel;
  final ScheduleModel? activeTimer;
  final SwitchService? switchService;
  final TimerService? timerService;
  final ScheduleService? scheduleService;
  final ActivityLogService? activityLogService;
  final bool enableCountdownTicker;

  const SwitchDetailScreen({
    super.key,
    required this.switchModel,
    this.deviceModel,
    this.activeTimer,
    this.switchService,
    this.timerService,
    this.scheduleService,
    this.activityLogService,
    this.enableCountdownTicker = true,
  });

  @override
  State<SwitchDetailScreen> createState() => _SwitchDetailScreenState();
}

class _SwitchDetailScreenState extends State<SwitchDetailScreen> {
  late SwitchModel _currentSwitch;
  late final SwitchService _switchService;
  late final TimerService _timerService;
  late final ScheduleService _scheduleService;
  late final ActivityLogService _activityLogService;

  bool _isToggling = false;
  Timer? _countdownTicker;

  @override
  void initState() {
    super.initState();
    _currentSwitch = widget.switchModel;
    _switchService = widget.switchService ?? SwitchService.instance;
    _timerService = widget.timerService ?? TimerService.instance;
    _scheduleService = widget.scheduleService ?? ScheduleService.instance;
    _activityLogService =
        widget.activityLogService ?? ActivityLogService.instance;

    if (widget.enableCountdownTicker) {
      _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }

  Future<void> _handleToggle(bool targetValue) async {
    final previousValue = _currentSwitch.isOn;
    setState(() {
      _currentSwitch = _currentSwitch.copyWith(isOn: targetValue);
      _isToggling = true;
    });

    try {
      await _switchService.setSwitchState(
        switchId: _currentSwitch.id,
        isOn: targetValue,
      );
      // Record activity
      await _activityLogService.logAction(
        switchId: _currentSwitch.id,
        switchName: _currentSwitch.name,
        deviceId: _currentSwitch.deviceId,
        action: targetValue ? 'ON' : 'OFF',
        source: 'mobile_app',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentSwitch = _currentSwitch.copyWith(isOn: previousValue);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update switch state: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SwitchModel?>(
      stream: _switchService.streamSwitch(widget.switchModel.id),
      initialData: _currentSwitch,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _currentSwitch = snapshot.data!;
        }

        final isOn = _currentSwitch.isOn;
        final isOnline = widget.deviceModel?.isOnline ?? true;
        final isSynced =
            widget.deviceModel?.isSwitchSynced(_currentSwitch.id, isOn) ?? true;

        String formatDuration(Duration d) {
          final hours = d.inHours.toString().padLeft(2, '0');
          final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
          final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
          return '$hours:$minutes:$seconds';
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_currentSwitch.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
                onPressed: () => setState(() {}),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      CustomCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentSwitch.room,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[400],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _currentSwitch.name,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  label: isOn ? 'ON' : 'OFF',
                                  type: isOn
                                      ? StatusType.success
                                      : StatusType.neutral,
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),

                            // Main Power Button
                            GestureDetector(
                              onTap: _isToggling
                                  ? null
                                  : () => _handleToggle(!isOn),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOn
                                      ? AppTheme.primaryColor.withAlpha(40)
                                      : Colors.grey.withAlpha(25),
                                  border: Border.all(
                                    color: isOn
                                        ? AppTheme.primaryColor
                                        : Colors.grey[700]!,
                                    width: 3.5,
                                  ),
                                  boxShadow: isOn
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.primaryColor
                                                .withAlpha(100),
                                            blurRadius: 28,
                                            spreadRadius: 4,
                                          )
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: _isToggling
                                      ? const CircularProgressIndicator(
                                          strokeWidth: 3,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            AppTheme.primaryColor,
                                          ),
                                        )
                                      : Icon(
                                          Icons.power_settings_new_rounded,
                                          size: 58,
                                          color: isOn
                                              ? AppTheme.primaryColor
                                              : Colors.grey[600],
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            Text(
                              isOn ? 'TAP TO TURN OFF' : 'TAP TO TURN ON',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: isOn
                                    ? AppTheme.primaryColor
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Active Timer Card
                      if (widget.activeTimer != null &&
                          widget.activeTimer!.isPending) ...[
                        CustomCard(
                          padding: const EdgeInsets.all(16),
                          borderSide: const BorderSide(color: Color(0xFF0284C7)),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withAlpha(40),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.timer_outlined,
                                  color: Color(0xFF0284C7),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Timer Active (Auto ${widget.activeTimer!.action.toUpperCase()})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatDuration(
                                          widget.activeTimer!.timeRemaining),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'monospace',
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _timerService
                                    .cancelTimer(widget.activeTimer!.id),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: AppTheme.errorColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Hardware Telemetry Card
                      CustomCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isOnline
                                      ? Icons.wifi_rounded
                                      : Icons.wifi_off_rounded,
                                  size: 20,
                                  color: isOnline
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isOnline
                                      ? 'Controller Online (${_currentSwitch.deviceId})'
                                      : 'Controller Offline (${_currentSwitch.deviceId})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isOnline
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isOnline
                                  ? (isSynced
                                      ? 'Physical relay confirms state is ${isOn ? "ON" : "OFF"}.'
                                      : 'Command sent. Awaiting ESP32 physical confirmation...')
                                  : 'ESP32 is unreachable. Commands will be queued in Firestore.',
                              style: const TextStyle(
                                  fontSize: 12.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.timer_outlined, size: 18),
                              label: const Text('Set Timer'),
                              onPressed: () => SetTimerModal.show(
                                context,
                                switchModel: _currentSwitch,
                                timerService: _timerService,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon:
                                  const Icon(Icons.schedule_outlined, size: 18),
                              label: const Text('Add Schedule'),
                              onPressed: () => CreateEditScheduleModal.show(
                                context,
                                initialSwitch: _currentSwitch,
                                scheduleService: _scheduleService,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Activity Audit History Card
                      CustomCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Recent Activity Log',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Icon(Icons.history_rounded,
                                    size: 18, color: Colors.grey[400]),
                              ],
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<List<ActivityLogModel>>(
                              stream: _activityLogService.streamLogs(
                                switchId: _currentSwitch.id,
                                limit: 5,
                              ),
                              builder: (context, logSnapshot) {
                                final logs = logSnapshot.data ?? [];
                                if (logs.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'No recent activity recorded for this switch.',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  );
                                }
                                return Column(
                                  children: [
                                    for (final log in logs) ...[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: (log.action == 'ON'
                                                        ? const Color(
                                                            0xFF10B981)
                                                        : const Color(
                                                            0xFFEF4444))
                                                    .withAlpha(30),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                log.action == 'ON'
                                                    ? Icons.power_rounded
                                                    : Icons.power_off_rounded,
                                                size: 14,
                                                color: log.action == 'ON'
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFEF4444),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'State turned ${log.action} (${log.source})',
                                                style: const TextStyle(
                                                    fontSize: 12.5),
                                              ),
                                            ),
                                            Text(
                                              '${log.timestamp.hour.toString().padLeft(2, "0")}:${log.timestamp.minute.toString().padLeft(2, "0")}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (log != logs.last)
                                        const Divider(height: 8),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Metadata Info
                      CustomCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Switch Metadata',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildMetaRow('Document ID', _currentSwitch.id),
                            const Divider(height: 16),
                            _buildMetaRow('Room Group', _currentSwitch.room),
                            const Divider(height: 16),
                            _buildMetaRow('Hardware Device ID',
                                _currentSwitch.deviceId),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
