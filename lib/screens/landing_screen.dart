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
          _LandingDestination.states => CivicColorReveal(
            key: const Key('destination-color-reveal'),
            amount: progress,
            child: _LandingMapArtwork(provider: provider, expansion: progress),
          ),
          _LandingDestination.branches => FederalBranchArtwork(
            colorAmount: progress,
          ),
          _LandingDestination.reps => CivicColorReveal(
            key: const Key('destination-color-reveal'),
            amount: progress,
            child: PortraitPageArtwork(
              portraits: hasPortraits ? portraits : null,
              pool: portraitPool ?? const [],
              expansion: progress,
            ),
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final textScale = MediaQuery.textScalerOf(context).scale(20) / 20;
    return Scaffold(
      backgroundColor: _landingNavy,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: _landingNavy,
                border: Border(
                  bottom: BorderSide(color: _landingRed, width: 4),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Image.asset('assets/img/logo.png', width: 42, height: 42),
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
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) {
                  // Fill the usable screen; allow scrolling for short screens
                  // and large accessibility text without shrinking touch targets.
                  final minimum =
                      520.0 * textScale.clamp(1.0, 1.8) + bottomInset;
                  final height = bounds.maxHeight < minimum
                      ? minimum
                      : bounds.maxHeight;
                  return SingleChildScrollView(
                    child: SizedBox(
                      height: height,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            child: SizedBox(
                              height: (height - 24) * .45,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _LandingTile(
                                      key: _statesKey,
                                      label: 'US States',
                                      icon: CivicIcons.district,
                                      onTap: () =>
                                          _open(_LandingDestination.states),
                                      image: _LandingMapArtwork(
                                        provider: provider,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _LandingTile(
                                      key: _branchesKey,
                                      label: 'Federal Branches',
                                      icon: CivicIcons.president,
                                      onTap: () =>
                                          _open(_LandingDestination.branches),
                                      image: const FederalBranchArtwork(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _LandingTile(
                              key: _repsKey,
                              label: 'Find My Reps',
                              icon: CivicIcons.representative,
                              wide: true,
                              bottomInset: bottomInset,
                              onTap: () => _open(_LandingDestination.reps),
                              image: RotatingLawmakerPortraits(
                                key: _portraitsKey,
                              ),
                              contactAction: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const ContactCongressStartScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
    required this.image,
    required this.onTap,
    this.wide = false,
    this.bottomInset = 0,
    this.contactAction,
  });
  final String label;
  final IconData icon;
  final Widget image;
  final VoidCallback onTap;
  final bool wide;
  final double bottomInset;
  final VoidCallback? contactAction;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFDBE5F2),
    borderRadius: wide
        ? const BorderRadius.vertical(top: Radius.circular(28))
        : BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: CivicColorReveal(
            key: ValueKey('home-color-$label'),
            amount: 0,
            child: image,
          ),
        ),
        Positioned.fill(
          child: Semantics(
            button: true,
            label: label,
            onTap: onTap,
            child: InkWell(excludeFromSemantics: true, onTap: onTap),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 12 + bottomInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IgnorePointer(
                child: ExcludeSemantics(
                  child: _LandingTileLabel(
                    label: label,
                    icon: icon,
                    wide: wide,
                  ),
                ),
              ),
              if (contactAction != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  button: true,
                  label: 'Contact My Reps',
                  onTap: contactAction,
                  child: InkWell(
                    key: const Key('home-contact-my-reps'),
                    excludeFromSemantics: true,
                    borderRadius: BorderRadius.circular(24),
                    onTap: contactAction,
                    child: const ExcludeSemantics(
                      child: _LandingTileLabel(
                        label: 'Contact My Reps',
                        icon: Icons.mail_outline,
                        wide: true,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
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

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('home-label-$label'),
    constraints: BoxConstraints.tightFor(
      height: 80 * (MediaQuery.textScalerOf(context).scale(18) / 18),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _landingRed, width: 1.5),
    ),
    child: Row(
      children: [
        Icon(icon, size: 22, color: _landingRed),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: _landingNavy,
            ),
          ),
        ),
      ],
    ),
  );
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
