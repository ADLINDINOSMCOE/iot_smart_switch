import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../models/schedule_model.dart';
import '../models/switch_model.dart';
import '../widgets/custom_card.dart';
import '../widgets/status_badge.dart';

class HomeSwitchCard extends StatelessWidget {
  final SwitchModel switchModel;
  final bool effectiveIsOn;
  final bool isPending;
  final ValueChanged<bool> onToggle;
  final ScheduleModel? activeTimer;
  final DeviceModel? deviceModel;
  final VoidCallback? onSetTimer;
  final ValueChanged<String>? onCancelTimer;
  final VoidCallback? onTap;

  const HomeSwitchCard({
    super.key,
    required this.switchModel,
    required this.effectiveIsOn,
    required this.isPending,
    required this.onToggle,
    this.activeTimer,
    this.deviceModel,
    this.onSetTimer,
    this.onCancelTimer,
    this.onTap,
  });

  String _formatTimeRemaining(Duration duration) {
    if (duration <= Duration.zero) return 'Now';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isDeviceOnline = deviceModel?.isOnline ?? false;
    final isSynced = deviceModel != null &&
        deviceModel!.isSwitchSynced(switchModel.id, effectiveIsOn);

    final cardBorder = effectiveIsOn
        ? BorderSide(
            color: theme.colorScheme.primary.withAlpha(120),
            width: 1.5,
          )
        : null;

    final cardBg = effectiveIsOn
        ? (isDark
            ? const Color(0xFF0F2338) // Deep blue tint in dark mode
            : const Color(0xFFF0F9FF)) // Light sky tint in light mode
        : null;

    return CustomCard(
      backgroundColor: cardBg,
      borderSide: cardBorder,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Device icon + status badge + pending spinner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: effectiveIsOn
                      ? theme.colorScheme.primary.withAlpha(40)
                      : Colors.grey.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  effectiveIsOn
                      ? Icons.power_rounded
                      : Icons.power_off_rounded,
                  color: effectiveIsOn
                      ? theme.colorScheme.primary
                      : Colors.grey,
                  size: 20,
                ),
              ),
              Row(
                children: [
                  if (isPending) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  StatusBadge(
                    label: effectiveIsOn ? 'ON' : 'OFF',
                    type: effectiveIsOn
                        ? StatusType.success
                        : StatusType.neutral,
                    icon: effectiveIsOn
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Switch Name
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    switchModel.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 2),

          // Room & Device ID + Online / Offline Signal
          Row(
            children: [
              Icon(
                Icons.meeting_room_outlined,
                size: 12,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                switchModel.room,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              // Hardware online signal indicator
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isDeviceOnline
                      ? const Color(0xFF10B981)
                      : const Color(0xFF9CA3AF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                switchModel.deviceId,
                style: TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  color: isDeviceOnline
                      ? (isDark ? Colors.white70 : Colors.black87)
                      : Colors.grey,
                ),
              ),
            ],
          ),

          // Hardware Synchronization Status Banner (Phase 8)
          if (deviceModel != null && !isSynced) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sync_problem_rounded,
                      size: 12, color: Color(0xFFEF4444)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      isDeviceOnline
                          ? 'Syncing with physical relay...'
                          : 'Hardware offline — unconfirmed',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Active Timer Countdown Banner
          if (activeTimer != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withAlpha(80),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Turns ${activeTimer!.action.toUpperCase()} in ${_formatTimeRemaining(activeTimer!.timeRemaining)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF59E0B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onCancelTimer != null)
                    InkWell(
                      onTap: () => onCancelTimer!(activeTimer!.id),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 4),

          // Bottom Controls: Toggle switch & Timer Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.timer_outlined, size: 14),
                label: Text(
                  activeTimer != null ? 'Edit Timer' : 'Timer',
                  style: const TextStyle(fontSize: 11.5),
                ),
                onPressed: onSetTimer,
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: effectiveIsOn,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) => onToggle(val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
