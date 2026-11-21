import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../design/civic_icons.dart';
import '../services/landing_portrait_service.dart';

class RotatingLawmakerPortraits extends StatefulWidget {
  const RotatingLawmakerPortraits({super.key, this.service});
  final LandingPortraitService? service;

  @override
  State<RotatingLawmakerPortraits> createState() =>
      RotatingLawmakerPortraitsState();
}

class RotatingLawmakerPortraitsState extends State<RotatingLawmakerPortraits>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final LandingPortraitService _service;
  late final AnimationController _fade;
  late final Animation<double> _opacity;
  final _random = Random();
  List<LandingPortrait> _pool = [], _shown = [];
  LandingPortrait? _incoming;
  Timer? _timer;
  int _slot = 0;
  bool _busy = false,
      _foreground = true,
      _reducedMotion = false,
      _paused = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LandingPortraitService();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeInOutCubic);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
  }

  Future<bool> _decode(LandingPortrait portrait) async {
    bool loaded = true;
    await precacheImage(
      AssetImage(portrait.asset),
      context,
      onError: (_, _) => loaded = false,
    );
    return loaded;
  }

  Future<void> _load() async {
    try {
      final pool = await _service.loadPool();
      final previous = await _service.readPrevious();
      if (!mounted) return;
      final choices = LandingPortraitService.choose(
        pool,
        previous,
        random: _random,
        count: pool.length,
      );
      final ready = <LandingPortrait>[];
      for (final portrait in choices) {
        if (!mounted) return;
        if (await _decode(portrait)) ready.add(portrait);
        if (ready.length == 3) break;
      }
      if (!mounted) return;
      setState(() {
        _pool = pool;
        _shown = ready;
      });
      await _service.remember(ready);
      if (!mounted) return;
      _timer = Timer.periodic(const Duration(seconds: 8), (_) => _rotate());
    } catch (_) {
      // The navigation button stays usable even if an asset cannot be read.
    }
  }

  bool get _canRotate =>
      mounted &&
      _foreground &&
      !_paused &&
      !_reducedMotion &&
      TickerMode.of(context) &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  Future<void> _rotate() async {
    if (_busy || !_canRotate || _shown.isEmpty) return;
    final candidates = _pool
        .where((p) => !_shown.any((s) => s.id == p.id))
        .toList();
    if (candidates.isEmpty) return;
    _busy = true;
    final next = candidates[_random.nextInt(candidates.length)];
    try {
      if (!await _decode(next) || !_canRotate) return;
      _fade.reset();
      setState(() => _incoming = next);
      await _finishIncoming();
    } on TickerCanceled {
      // Disposing the screen cancels an in-flight crossfade.
    } finally {
      _busy = false;
    }
  }

  Future<void> _finishIncoming() async {
    await _fade.forward().orCancel;
    if (!mounted || _paused || _incoming == null) return;
    setState(() {
      _shown[_slot] = _incoming!;
      _incoming = null;
      _slot = (_slot + 1) % _shown.length;
    });
    await _service.remember(_shown);
  }

  List<LandingPortrait> get portraitPool => List.unmodifiable(_pool);
  bool get hasPortraits => _shown.isNotEmpty;

  /// The outgoing page and expanding artwork share this exact visible frame.
  Widget pauseAndCapture() {
    _paused = true;
    _fade.stop(canceled: false);
    return _PortraitFrame(
      shown: List.of(_shown),
      incoming: _incoming,
      slot: _slot,
      opacity: AlwaysStoppedAnimation(_opacity.value),
    );
  }

  Future<void> resume() async {
    _paused = false;
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _busy || _incoming == null) return;
    _busy = true;
    try {
      await _finishIncoming();
    } on TickerCanceled {
      // The page can be disposed while returning to the landing screen.
    } finally {
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PortraitFrame(
    shown: _shown,
    incoming: _incoming,
    slot: _slot,
    opacity: _reducedMotion ? const AlwaysStoppedAnimation(1) : _opacity,
  );
}

class _PortraitFrame extends StatelessWidget {
  const _PortraitFrame({
    required this.shown,
    required this.incoming,
    required this.slot,
    required this.opacity,
  });
  final List<LandingPortrait> shown;
  final LandingPortrait? incoming;
  final int slot;
  final Animation<double> opacity;

  Widget _photo(LandingPortrait p) => Image.asset(
    p.asset,
    key: ValueKey(p.id),
    fit: BoxFit.cover,
    alignment: const Alignment(0, -.75),
    width: double.infinity,
    height: double.infinity,
    errorBuilder: (_, _, _) =>
        const Center(child: Icon(CivicIcons.representative, size: 48)),
  );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (i < shown.length)
                    _photo(shown[i])
                  else
                    const Center(
                      child: Icon(
                        CivicIcons.representative,
                        size: 48,
                        color: Color(0xFF08756D),
                      ),
                    ),
                  if (incoming != null && i == slot)
                    FadeTransition(opacity: opacity, child: _photo(incoming!)),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
