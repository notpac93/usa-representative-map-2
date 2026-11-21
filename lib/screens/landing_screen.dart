import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/data_provider.dart';
import '../design/civic_icons.dart';
import '../main.dart';
import '../map/national_map_painter.dart';
import '../widgets/rotating_lawmaker_portraits.dart';
import '../widgets/civic_glass.dart';
import '../widgets/portrait_page_artwork.dart';
import '../navigation/expanding_image_route.dart';
import 'federal_branches_screen.dart';
import 'find_reps_screen.dart';
import 'contact_congress_start_screen.dart';

const _landingNavy = Color(0xFF102D54);
const _landingRed = Color(0xFF9E4352);

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

enum _LandingDestination { states, branches, reps }

class _LandingScreenState extends State<LandingScreen> {
  final _statesKey = GlobalKey(),
      _branchesKey = GlobalKey(),
      _repsKey = GlobalKey();
  final _portraitsKey = GlobalKey<RotatingLawmakerPortraitsState>();
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MapDataProvider>().loadAllData();
    });
  }

  Future<void> _open(_LandingDestination destination) async {
    if (_opening) return;
    final key = switch (destination) {
      _LandingDestination.states => _statesKey,
      _LandingDestination.branches => _branchesKey,
      _LandingDestination.reps => _repsKey,
    };
    final box = key.currentContext?.findRenderObject();
    final navigator = Navigator.of(context);
    final navigatorBox = navigator.context.findRenderObject();
    if (box is! RenderBox || navigatorBox is! RenderBox || !box.hasSize) return;
    final origin =
        box.localToGlobal(Offset.zero, ancestor: navigatorBox) & box.size;
    final provider = context.read<MapDataProvider>();
    final isReps = destination == _LandingDestination.reps;
    final portraits = isReps
        ? _portraitsKey.currentState?.pauseAndCapture()
        : null;
    final portraitPool = _portraitsKey.currentState?.portraitPool;
    final hasPortraits = _portraitsKey.currentState?.hasPortraits ?? false;
    final (label, icon, screen) = switch (destination) {
      _LandingDestination.states => (
        'US States',
        CivicIcons.district,
        const MapScreen(),
      ),
      _LandingDestination.branches => (
        'Federal Branches',
        CivicIcons.president,
        const FederalBranchesScreen(managedBackdrop: true),
      ),
      _LandingDestination.reps => (
        'Find My Reps',
        CivicIcons.representative,
        const FindRepsScreen(imageBackground: true),
      ),
    };
    _opening = true;
    try {
      final route = ExpandingImageRoute<void>(
        origin: origin,
        wide: isReps,
        reducedMotion: MediaQuery.disableAnimationsOf(context),
        departureLabel: _LandingTileLabel(
          label: label,
          icon: icon,
          wide: isReps,
        ),
        imageBuilder: (progress) => switch (destination) {
          _LandingDestination.states => _LandingMapArtwork(
            provider: provider,
            expansion: progress,
          ),
          _LandingDestination.branches => FederalBranchArtwork(
            colorAmount: progress,
          ),
          _LandingDestination.reps => PortraitPageArtwork(
            portraits: hasPortraits ? portraits : null,
            pool: portraitPool ?? const [],
            expansion: progress,
          ),
        },
        screen: screen,
      );
      await navigator.push(route);
      await route.completed;
    } finally {
      _opening = false;
      if (isReps) _portraitsKey.currentState?.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapDataProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: _landingNavy,
                    border: Border(
                      bottom: BorderSide(color: _landingRed, width: 4),
                    ),
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/img/logo.png',
                          width: 46,
                          height: 46,
                        ),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Text(
                          'Your Representatives',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _LandingTile(
                              key: _statesKey,
                              label: 'US States',
                              icon: CivicIcons.district,
                              color: Colors.white,
                              onTap: () => _open(_LandingDestination.states),
                              image: _LandingMapArtwork(provider: provider),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LandingTile(
                              key: _branchesKey,
                              label: 'Federal Branches',
                              icon: CivicIcons.president,
                              color: Colors.white,
                              onTap: () => _open(_LandingDestination.branches),
                              image: const FederalBranchArtwork(colorAmount: 0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _LandingTile(
                        key: _repsKey,
                        label: 'Find My Reps',
                        icon: CivicIcons.representative,
                        color: Colors.white,
                        wide: true,
                        onTap: () => _open(_LandingDestination.reps),
                        image: RotatingLawmakerPortraits(key: _portraitsKey),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('home-contact-my-reps'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _landingNavy,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 54),
                          side: const BorderSide(
                            color: _landingRed,
                            width: 1.5,
                          ),
                        ),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Contact My Reps'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ContactCongressStartScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingTile extends StatelessWidget {
  const _LandingTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.image,
    required this.onTap,
    this.wide = false,
  });
  final String label;
  final IconData icon;
  final Color color;
  final Widget image;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(20) > 26;
    final labelPanel = _LandingTileLabel(label: label, icon: icon, wide: wide);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22102D54),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: largeText
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 176, child: image),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: labelPanel,
                        ),
                      ],
                    )
                  : SizedBox(
                      height: wide ? 270 : 252,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          image,
                          Positioned(
                            left: wide ? 12 : 8,
                            right: wide ? 12 : 8,
                            bottom: 12,
                            child: wide
                                ? labelPanel
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 18,
                                        sigmaY: 18,
                                      ),
                                      child: labelPanel,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingTileLabel extends StatelessWidget {
  const _LandingTileLabel({
    required this.label,
    required this.icon,
    required this.wide,
  });
  final String label;
  final IconData icon;
  final bool wide;
  static const foreground = _landingNavy;
  @override
  Widget build(BuildContext context) {
    return Container(
      key: wide ? const Key('find-reps-white-outline') : null,
      constraints: BoxConstraints(minHeight: wide ? 66 : 80),
      padding: EdgeInsets.symmetric(horizontal: wide ? 14 : 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: wide ? 1 : .94),
        borderRadius: BorderRadius.circular(wide ? 40 : 20),
        border: Border.all(
          color: wide ? _landingRed : Colors.white.withValues(alpha: .8),
          width: wide ? 2 : 1,
        ),
        boxShadow: [
          if (wide)
            BoxShadow(
              color: Colors.white.withValues(alpha: .35),
              spreadRadius: 5,
            ),
          const BoxShadow(
            color: Color(0x22102D54),
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: wide ? 30 : 24,
            color: wide ? _landingRed : foreground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: wide ? 24 : 19,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
          if (wide)
            const Icon(CivicIcons.forward, size: 20, color: _landingRed),
        ],
      ),
    );
  }
}

class _LandingMapArtwork extends StatelessWidget {
  const _LandingMapArtwork({required this.provider, this.expansion = 0});
  final MapDataProvider provider;
  final double expansion;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFDBE5F2),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        8 * (1 - expansion),
        8 * (1 - expansion),
        8 * (1 - expansion),
        82 * (1 - expansion),
      ),
      child: provider.atlas != null && provider.pathCache != null
          ? NationalMap(
              atlas: provider.atlas!,
              pathCache: provider.pathCache!,
              selectedStateId: 'CA',
            )
          : const Center(
              child: Icon(
                CivicIcons.district,
                size: 72,
                color: Color(0xFF456A99),
              ),
            ),
    ),
  );
}
