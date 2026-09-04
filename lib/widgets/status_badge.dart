import 'package:flutter/material.dart';

enum StatusType { success, warning, error, info, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = StatusType.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData defaultIcon;

    switch (type) {
      case StatusType.success:
        bg = const Color(0xFF10B981).withAlpha(35);
        fg = const Color(0xFF10B981);
        defaultIcon = Icons.check_circle_outline_rounded;
        break;
      case StatusType.warning:
        bg = const Color(0xFFF59E0B).withAlpha(35);
        fg = const Color(0xFFF59E0B);
        defaultIcon = Icons.warning_amber_rounded;
        break;
      case StatusType.error:
        bg = const Color(0xFFEF4444).withAlpha(35);
        fg = const Color(0xFFEF4444);
        defaultIcon = Icons.error_outline_rounded;
        break;
      case StatusType.info:
        bg = const Color(0xFF0284C7).withAlpha(35);
        fg = const Color(0xFF0284C7);
        defaultIcon = Icons.info_outline_rounded;
        break;
      case StatusType.neutral:
        bg = Colors.grey.withAlpha(30);
        fg = Colors.grey.shade600;
        defaultIcon = Icons.circle_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? defaultIcon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
