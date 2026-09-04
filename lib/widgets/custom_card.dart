import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final BorderSide? borderSide;
  final VoidCallback? onTap;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.borderSide,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardContent = Padding(
      padding: padding ?? const EdgeInsets.all(18),
      child: child,
    );

    if (onTap != null) {
      return Card(
        color: backgroundColor ?? theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: borderSide ??
              (theme.brightness == Brightness.dark
                  ? const BorderSide(color: Color(0xFF334155))
                  : const BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: cardContent,
        ),
      );
    }

    return Card(
      color: backgroundColor ?? theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: borderSide ??
            (theme.brightness == Brightness.dark
                ? const BorderSide(color: Color(0xFF334155))
                : const BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: cardContent,
    );
  }
}
