import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../models/switch_model.dart';
import '../services/schedule_service.dart';
import '../services/switch_service.dart';
import '../widgets/create_edit_schedule_modal.dart';
import '../widgets/custom_card.dart';
import '../widgets/status_badge.dart';

class SchedulesScreen extends StatefulWidget {
  final ScheduleService? scheduleService;
  final SwitchService? switchService;
  final Stream<List<ScheduleModel>>? schedulesStream;
  final String? userId;

  const SchedulesScreen({
    super.key,
    this.scheduleService,
    this.switchService,
    this.schedulesStream,
    this.userId,
  });

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  late final ScheduleService _scheduleService;
  late final SwitchService _switchService;

  String _filterStatus = 'all'; // "all", "pending", "completed", "cancelled"
  Map<String, SwitchModel> _switchesMap = {};

  @override
  void initState() {
    super.initState();
    _scheduleService = widget.scheduleService ?? ScheduleService.instance;
    _switchService = widget.switchService ?? SwitchService.instance;
    _loadSwitches();
  }

  Future<void> _loadSwitches() async {
    try {
      final switches = await _switchService.getSwitches();
      if (mounted) {
        setState(() {
          _switchesMap = {for (var s in switches) s.id: s};
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _switchesMap = {
            for (var s in SwitchService.sampleSwitches) s.id: s
          };
        });
      }
    }
  }

  Future<void> _handleCancelSchedule(String scheduleId) async {
    try {
      await _scheduleService.cancelSchedule(scheduleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule cancelled successfully.'),
            backgroundColor: Color(0xFF0284C7),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel schedule: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteSchedule(String scheduleId) async {
    try {
      await _scheduleService.deleteSchedule(scheduleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule deleted.'),
            backgroundColor: Color(0xFF6B7280),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete schedule: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final monthStr = monthNames[local.month];
    return '$monthStr ${local.day}, ${local.year} at $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedules & Automation'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Schedule'),
        onPressed: () => CreateEditScheduleModal.show(
          context,
          scheduleService: _scheduleService,
          switchService: _switchService,
        ),
      ),
      body: StreamBuilder<List<ScheduleModel>>(
        stream: widget.schedulesStream ??
            _scheduleService.streamSchedules(userId: widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error loading schedules: ${snapshot.error}'),
              ),
            );
          }

          final allSchedules = snapshot.data ?? [];
          final filteredSchedules = _filterStatus == 'all'
              ? allSchedules
              : allSchedules
                  .where((s) => s.status.toLowerCase() == _filterStatus)
                  .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status Filter Segment
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(
                            value: 'pending', label: Text('Pending')),
                        ButtonSegment(
                            value: 'completed', label: Text('Completed')),
                        ButtonSegment(
                            value: 'cancelled', label: Text('Cancelled')),
                      ],
                      selected: {_filterStatus},
                      onSelectionChanged: (newSelection) {
                        setState(() => _filterStatus = newSelection.first);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Empty State
                    if (filteredSchedules.isEmpty) ...[
                      _buildEmptyState(),
                    ] else ...[
                      // Schedule List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredSchedules.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final schedule = filteredSchedules[idx];
                          final boundSwitch = _switchesMap[schedule.switchId];
                          return _buildScheduleCard(schedule, boundSwitch);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleCard(
      ScheduleModel schedule, SwitchModel? boundSwitch) {
    final theme = Theme.of(context);
    final isPending = schedule.isPending;
    final isTurnOn = schedule.action.toLowerCase() == 'on';

    StatusType statusType;
    if (schedule.isPending) {
      statusType = StatusType.warning;
    } else if (schedule.isCompleted) {
      statusType = StatusType.success;
    } else {
      statusType = StatusType.neutral;
    }

    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Action Badge (Turn ON vs Turn OFF)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isTurnOn
                      ? const Color(0xFF10B981).withAlpha(30)
                      : const Color(0xFFEF4444).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTurnOn ? Icons.power_rounded : Icons.power_off_rounded,
                      size: 14,
                      color: isTurnOn
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Turn ${schedule.action.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isTurnOn
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              StatusBadge(
                label: schedule.status.toUpperCase(),
                type: statusType,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Switch Name and Target time
          Text(
            boundSwitch?.name ?? 'Switch (${schedule.switchId})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 13, color: Colors.grey.shade600),
              const SizedBox(width: 5),
              Text(
                _formatDateTime(schedule.time),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isPending
                      ? theme.colorScheme.primary
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),

          if (schedule.executedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Executed: ${_formatDateTime(schedule.executedAt!)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // Actions Row (Edit, Cancel, Delete)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isPending) ...[
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  onPressed: () => CreateEditScheduleModal.show(
                    context,
                    initialSwitch: boundSwitch,
                    existingSchedule: schedule,
                    scheduleService: _scheduleService,
                    switchService: _switchService,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 15),
                  label: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  onPressed: () => _handleCancelSchedule(schedule.id),
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.grey),
                  tooltip: 'Delete',
                  onPressed: () => _handleDeleteSchedule(schedule.id),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return CustomCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule_send_rounded,
              size: 44,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Schedules Found',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create automated ON/OFF schedules to control your appliances at specific times.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Schedule'),
            onPressed: () => CreateEditScheduleModal.show(
              context,
              scheduleService: _scheduleService,
              switchService: _switchService,
            ),
          ),
        ],
      ),
    );
  }
}
