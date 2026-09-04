import 'package:flutter/material.dart';
import '../models/switch_model.dart';
import '../widgets/custom_card.dart';
import '../widgets/status_badge.dart';

class SwitchTile extends StatelessWidget {
  final SwitchModel switchModel;
  final ValueChanged<bool>? onToggle;
  final bool isUpdating;

  const SwitchTile({
    super.key,
    required this.switchModel,
    this.onToggle,
    this.isUpdating = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOn = switchModel.isOn;

    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon Container with ON/OFF visual indication
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOn
                  ? theme.colorScheme.primary.withAlpha(40)
                  : Colors.grey.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
              color: isOn ? theme.colorScheme.primary : Colors.grey,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // Name, Room, Device ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        switchModel.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${switchModel.id})',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.meeting_room_outlined,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      switchModel.room,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusBadge(
                      label: switchModel.deviceId,
                      type: StatusType.neutral,
                      icon: Icons.memory_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Toggle Switch / Loading indicator
          if (isUpdating)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Switch(
              value: isOn,
              activeColor: theme.colorScheme.primary,
              onChanged: onToggle,
            ),
        ],
      ),
    );
  }
}
