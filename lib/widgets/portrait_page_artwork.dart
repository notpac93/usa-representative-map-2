import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/civic_icons.dart';
import '../services/landing_portrait_service.dart';
import 'civic_glass.dart';

/// The landing trio expands into a gently drifting mosaic. One row at a time
/// crossfades to fresh locally bundled portraits, including while typing.
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
  final _replacements = <int, List<LandingPortrait>>{};
  final _versions = <int, int>{};
  final _random = math.Random();
  Timer? _rotationTimer;
  int _columns = 3, _visibleRows = 1, _nextRow = 0;
  bool _rotating = false;
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
    _rotationTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _rotateRow(),
    );
  }

  Future<void> _load() async {
    try {
      final pool = await LandingPortraitService().loadPool();
      if (mounted) setState(() => _portraits = pool..shuffle());
    } catch (_) {
      // Search stays available if decorative assets cannot load.
    }
  }

  bool get _motionEnabled =>
      mounted &&
      _foreground &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.of(context) &&
      widget.expansion == 1;

  void _updateMotion() {
    final enabled = _motionEnabled;
    if (enabled && !_float.isAnimating) _float.repeat();
    if (!enabled && _float.isAnimating) _float.stop();
  }

  List<LandingPortrait> _rowPortraits(int row, int columns) =>
      _replacements[row] ??
      (_portraits.isEmpty
          ? const []
          : List.generate(
              columns,
              (column) =>
                  _portraits[(row * columns + column) % _portraits.length],
            ));

  Future<void> _rotateRow() async {
    if (_rotating || !_motionEnabled || _portraits.isEmpty) return;
    _rotating = true;
    try {
      final row = _nextRow % _visibleRows;
      final columns = _columns;
      final visible = {
        for (var i = 0; i < _visibleRows + 1; i++)
          for (final portrait in _rowPortraits(i, columns)) portrait.id,
      };
      final candidates =
          _portraits
              .where((portrait) => !visible.contains(portrait.id))
              .toList()
            ..shuffle(_random);
      // Keep small pools stable when there are no unused portraits available.
      if (candidates.length < columns) return;
      final next = candidates.take(columns).toList();
      for (final portrait in next) {
        if (!mounted) return;
        var loaded = true;
        await precacheImage(
          ResizeImage.resizeIfNeeded(360, null, AssetImage(portrait.asset)),
          context,
          onError: (_, _) => loaded = false,
        );
        if (!loaded) return;
      }
      if (!_motionEnabled || columns != _columns) return;
      setState(() {
        _replacements[row] = next;
        _versions[row] = (_versions[row] ?? 0) + 1;
        _nextRow = (row + 1) % _visibleRows;
      });
    } finally {
      _rotating = false;
    }
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
    setState(() => _foreground = state == AppLifecycleState.resumed);
    _updateMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rotationTimer?.cancel();
    _float.dispose();
    super.dispose();
  }

  Widget _row(int index, int columns) {
    final portraits = _rowPortraits(index, columns);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var column = 0; column < columns; column++) ...[
          if (column > 0) const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: portraits.isEmpty
                  ? const ColoredBox(
                      color: civicNavy,
                      child: Icon(
                        CivicIcons.representative,
                        color: Colors.white,
                      ),
                    )
                  : Image.asset(
                      portraits[column % portraits.length].asset,
                      key: ValueKey(portraits[column % portraits.length].id),
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -.75),
                      cacheWidth: 360,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: civicNavy,
                        child: Icon(
                          CivicIcons.representative,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }

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
              final rowHeight = (constraints.maxWidth / columns * 1.35).clamp(
                170.0,
                230.0,
              );
              final firstHeight =
                  constraints.maxHeight * (1 - progress) + rowHeight * progress;
              final rows = (constraints.maxHeight / rowHeight).ceil() + 1;
              _columns = columns;
              _visibleRows = math.max(1, rows - 1);
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
                          child: TickerMode(
                            enabled: _motionEnabled,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 1800),
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              layoutBuilder: (current, previous) => Stack(
                                fit: StackFit.expand,
                                children: [...previous, ?current],
                              ),
                              // Keep the old row opaque under the incoming fade.
                              transitionBuilder: (child, animation) =>
                                  AnimatedBuilder(
                                    animation: animation,
                                    child: child,
                                    builder: (_, child) => Opacity(
                                      opacity:
                                          animation.status ==
                                              AnimationStatus.reverse
                                          ? 1
                                          : animation.value,
                                      child: child,
                                    ),
                                  ),
                              child: SizedBox.expand(
                                key: ValueKey(
                                  'portrait-row-$row-${_versions[row] ?? 0}',
                                ),
                                child:
                                    row == 0 &&
                                        widget.portraits != null &&
                                        !_replacements.containsKey(row)
                                    ? widget.portraits!
                                    : _row(row, columns),
                              ),
                            ),
                          ),
                        ),
                        builder: (context, child) => Transform.translate(
                          offset: Offset(
                            math.sin(_float.value * math.pi * 2) *
                                (row.isEven ? 14 : -14) *
                                progress,
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
