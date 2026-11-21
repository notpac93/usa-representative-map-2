import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

const civicNavy = Color(0xFF102D54);
const civicCanvas = Color(0xFFF4F6FA);

/// App-owned frosted material, with an opaque-enough fill for readable text.
class CivicGlassPanel extends StatelessWidget {
  const CivicGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x19102D54),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: .85)),
          ),
          child: child,
        ),
      ),
    ),
  );
}

AppBar civicGlassAppBar(String title, {List<Widget>? actions}) => AppBar(
  title: Text(title),
  foregroundColor: civicNavy,
  backgroundColor: Colors.transparent,
  elevation: 0,
  scrolledUnderElevation: 0,
  actions: actions,
  flexibleSpace: ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: SizedBox.expand(
        child: ColoredBox(color: Colors.white.withValues(alpha: .9)),
      ),
    ),
  ),
);

class FederalBranchArtwork extends StatelessWidget {
  const FederalBranchArtwork({super.key, this.colorAmount = 1});
  final double colorAmount;

  @override
  Widget build(BuildContext context) {
    return CivicColorReveal(
      amount: colorAmount,
      child: Image.asset(
        'assets/img/federal-branches.png',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Shared saturation treatment for home artwork and its opening transition.
class CivicColorReveal extends StatelessWidget {
  const CivicColorReveal({
    super.key,
    required this.amount,
    required this.child,
  });
  final double amount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = amount.clamp(0.0, 1.0);
    final r = .2126 * (1 - s), g = .7152 * (1 - s), b = .0722 * (1 - s);
    return ColorFiltered(
      colorFilter: ColorFilter.matrix([
        r + s,
        g,
        b,
        0,
        0,
        r,
        g + s,
        b,
        0,
        0,
        r,
        g,
        b + s,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: child,
    );
  }
}
