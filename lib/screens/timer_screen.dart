import 'dart:async';
import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../models/switch_model.dart';
import '../services/switch_service.dart';
import '../services/timer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/status_badge.dart';

class TimerScreen extends StatefulWidget {
  final TimerService? timerService;
  final SwitchService? switchService;
  final bool enableCountdownTicker;

  const TimerScreen({
    super.key,
    this.timerService,
    this.switchService,
    this.enableCountdownTicker = true,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  late final TimerService _timerService;
  late final SwitchService _switchService;
  Timer? _countdownTicker;

  @override
  void initState() {
    super.initState();
    _timerService = widget.timerService ?? TimerService.instance;
    _switchService = widget.switchService ?? SwitchService.instance;

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

  String _formatRemaining(Duration duration) {
    if (duration <= Duration.zero) return '00:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = seconds.toString().padLeft(2, '0');
    return '$minStr:$secStr';
  }

  Future<void> _handleCancelTimer(String timerId) async {
    try {
      await _timerService.cancelTimer(timerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timer cancelled.'),
            backgroundColor: Color(0xFF0284C7),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel timer: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Timers'),
      ),
      body: StreamBuilder<List<SwitchModel>>(
        stream: _switchService.streamSwitches(),
        builder: (context, switchSnapshot) {
          final switches = switchSnapshot.data ?? [];
          final Map<String, SwitchModel> switchMap = {
            for (var s in switches) s.id: s
          };

          return StreamBuilder<List<ScheduleModel>>(
            stream: _timerService.streamActiveTimers(),
            builder: (context, timerSnapshot) {
              if (timerSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (timerSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Failed to load timers: ${timerSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.errorColor),
                    ),
                  ),
                );
              }

              final activeTimers = (timerSnapshot.data ?? [])
                  .where((t) => t.isPending)
                  .toList();

              if (activeTimers.isEmpty) {
                return _buildEmptyState(switches);
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: activeTimers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final timer = activeTimers[idx];
                  final switchModel = switchMap[timer.switchId];
                  return _buildTimerCard(timer, switchModel);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTimerCard(ScheduleModel timer, SwitchModel? switchModel) {
    final title = switchModel?.name ?? timer.switchId;
    final room = switchModel?.room ?? 'Unknown Room';
    final isActionOn = timer.action.toLowerCase() == 'on';
    final remainingFormatted = _formatRemaining(timer.timeRemaining);

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActionOn
                      ? const Color(0xFF10B981).withAlpha(30)
                      : const Color(0xFFEF4444).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: isActionOn
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      room,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: isActionOn ? 'WILL TURN ON' : 'WILL TURN OFF',
                type: isActionOn ? StatusType.success : StatusType.error,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.hourglass_bottom_rounded,
                      size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Text(
                    remainingFormatted,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.cancel_outlined, size: 16, color: AppTheme.errorColor),
                label: const Text('Cancel', style: TextStyle(color: AppTheme.errorColor)),
                onPressed: () => _handleCancelTimer(timer.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(List<SwitchModel> switches) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_off_outlined,
                  size: 48, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Active Timers',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'There are no active one-shot countdown timers running. You can start a timer from any switch card on the Home Screen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
