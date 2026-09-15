import 'package:flutter/material.dart';

/// A consistent icon treatment for feature actions and explanatory callouts.
///
/// The badge is visual only; the surrounding button or row owns the tap target
/// and accessibility label.
class CivicIconBadge extends StatelessWidget {
  const CivicIconBadge({
    super.key,
    required this.icon,
    this.foregroundColor,
    this.backgroundColor,
    this.size = 42,
    this.iconSize = 22,
    this.filled = false,
  });

  final IconData icon;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = foregroundColor ?? Theme.of(context).colorScheme.primary;
    final background = backgroundColor ?? foreground.withValues(alpha: 0.12);

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.34),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: foreground,
          fill: filled ? 1 : 0,
          weight: 500,
          opticalSize: iconSize,
        ),
      ),
    );
  }
}
