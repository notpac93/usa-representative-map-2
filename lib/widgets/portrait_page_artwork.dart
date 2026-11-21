import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/civic_icons.dart';
import '../services/landing_portrait_service.dart';
import 'civic_glass.dart';

/// The captured landing trio becomes the first row. Additional locally bundled
/// portraits are shuffled once per visit, never during a rebuild or keyboard edit.
class PortraitPageArtwork extends StatefulWidget {
  const PortraitPageArtwork({
    super.key,
    this.portraits,
    required this.pool,
    this.expansion = 1,
  });

  final Widget? portraits;
  final List<LandingPortrait> pool;
  final double expansion;

  @override
  State<PortraitPageArtwork> createState() => _PortraitPageArtworkState();
}

class _PortraitPageArtworkState extends State<PortraitPageArtwork>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _float;
  List<LandingPortrait> _portraits = [];
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 44),
    );
    WidgetsBinding.instance.addObserver(this);
    _portraits = List.of(widget.pool)..shuffle();
    if (_portraits.isEmpty) _load();
  }

  Future<void> _load() async {
    try {
      final pool = await LandingPortraitService().loadPool();
      if (mounted) setState(() => _portraits = pool..shuffle());
    } catch (_) {
      // Search stays available if decorative assets cannot load.
    }
  }

  void _updateMotion() {
    final enabled = _foreground &&
        !MediaQuery.disableAnimationsOf(context) &&
        MediaQuery.viewInsetsOf(context).bottom == 0 &&
        TickerMode.of(context) &&
        widget.expansion == 1;
    if (enabled && !_float.isAnimating) _float.repeat();
    if (!enabled && _float.isAnimating) _float.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
  }

  @override
  void didUpdateWidget(covariant PortraitPageArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _float.dispose();
    super.dispose();
  }

  Widget _row(int index, int columns) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var column = 0; column < columns; column++) ...[
        if (column > 0) const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _portraits.isEmpty
                ? const ColoredBox(
                    color: civicNavy,
                    child: Icon(CivicIcons.representative, color: Colors.white),
                  )
                : Image.asset(
                    _portraits[(index * columns + column) % _portraits.length]
                        .asset,
                    key: ValueKey(_portraits[
                        (index * columns + column) % _portraits.length].id),
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -.75),
                    cacheWidth: 360,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: civicNavy,
                      child: Icon(CivicIcons.representative, color: Colors.white),
                    ),
                  ),
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: ClipRect(
        child: ColoredBox(
          color: civicNavy,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final progress = widget.expansion;
              final columns = math.max(3, (constraints.maxWidth / 150).ceil());
              final rowHeight = (constraints.maxWidth / columns * 1.35)
                  .clamp(170.0, 230.0);
              final firstHeight = constraints.maxHeight * (1 - progress) +
                  rowHeight * progress;
              final rows = (constraints.maxHeight / rowHeight).ceil() + 1;
              return Stack(
                children: [
                  for (var row = 0; row < rows; row++)
                    Positioned(
                      top: row == 0
                          ? 0
                          : firstHeight + 4 + (row - 1) * (rowHeight + 4),
                      left: -20 * progress,
                      width: constraints.maxWidth + 40 * progress,
                      height: row == 0 ? firstHeight : rowHeight,
                      child: AnimatedBuilder(
                        animation: _float,
                        child: RepaintBoundary(
                          key: ValueKey('portrait-background-row-$row'),
                          child: row == 0 && widget.portraits != null
                              ? widget.portraits!
                              : _row(row, columns),
                        ),
                        builder: (context, child) => Transform.translate(
                          offset: Offset(
                            math.sin(_float.value * math.pi * 2) *
                                (row.isEven ? 14 : -14) * progress,
                            0,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: ColoredBox(
                      color: civicNavy.withValues(alpha: .12 * progress),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
