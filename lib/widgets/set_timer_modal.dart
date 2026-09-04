import 'package:flutter/material.dart';
import '../models/switch_model.dart';
import '../services/timer_service.dart';

class SetTimerModal extends StatefulWidget {
  final SwitchModel switchModel;
  final TimerService? timerService;

  const SetTimerModal({
    super.key,
    required this.switchModel,
    this.timerService,
  });

  static Future<void> show(
    BuildContext context, {
    required SwitchModel switchModel,
    TimerService? timerService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SetTimerModal(
        switchModel: switchModel,
        timerService: timerService,
      ),
    );
  }

  @override
  State<SetTimerModal> createState() => _SetTimerModalState();
}

class _SetTimerModalState extends State<SetTimerModal> {
  late final TimerService _timerService;

  // Default duration: 15 minutes
  int _selectedMinutes = 15;
  String _selectedAction = 'off'; // "off" or "on"
  bool _isSubmitting = false;

  final List<int> _presetMinutes = [1, 5, 15, 30, 60, 120];

  @override
  void initState() {
    super.initState();
    _timerService = widget.timerService ?? TimerService.instance;
    // Default action to turn OFF if currently ON, and vice-versa
    _selectedAction = widget.switchModel.isOn ? 'off' : 'on';
  }

  Future<void> _handleSetTimer() async {
    setState(() => _isSubmitting = true);

    try {
      await _timerService.createTimer(
        switchId: widget.switchModel.id,
        action: _selectedAction,
        duration: Duration(minutes: _selectedMinutes),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Timer set: "${widget.switchModel.name}" will turn ${_selectedAction.toUpperCase()} in $_selectedMinutes min.',
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
            content: Text('Failed to set timer: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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

          // Title & Switch Name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.timer_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Set Switch Timer',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      widget.switchModel.name,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Selector (Turn OFF vs Turn ON)
          const Text(
            'Target Action',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'off',
                label: Text('Turn OFF'),
                icon: Icon(Icons.power_off_rounded),
              ),
              ButtonSegment<String>(
                value: 'on',
                label: Text('Turn ON'),
                icon: Icon(Icons.power_rounded),
              ),
            ],
            selected: {_selectedAction},
            onSelectionChanged: (newSelection) {
              setState(() {
                _selectedAction = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 20),

          // Duration Selector
          const Text(
            'Timer Duration',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetMinutes.map((minutes) {
              final isSelected = _selectedMinutes == minutes;
              final label = minutes >= 60
                  ? '${minutes ~/ 60} hr${minutes % 60 > 0 ? " ${minutes % 60}m" : ""}'
                  : '$minutes min';

              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedMinutes = minutes);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleSetTimer,
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
                      'Start $_selectedMinutes Min Timer',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
