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
        reducedMotion: MediaQuery.disableAnimationsOf(context),
        departureLabel: _LandingTileLabel(label: label, icon: icon),
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
      backgroundColor: civicCanvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: LayoutBuilder(
              builder: (context, bounds) {
                // Fill a phone's available height; scroll on short displays or
                // with enlarged text rather than clipping the four actions.
                final textScale =
                    MediaQuery.textScalerOf(context).scale(25) / 25;
                final minimum = 680.0 * textScale.clamp(1.0, 2.0);
                final height = bounds.maxHeight < minimum
                    ? minimum
                    : bounds.maxHeight;
                return SingleChildScrollView(
                  child: SizedBox(
                    height: height,
                    child: Column(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: _landingNavy,
                            border: Border(
                              bottom: BorderSide(color: _landingRed, width: 3),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/img/logo.png',
                                width: 34,
                                height: 40,
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                              ),
                              const SizedBox(width: 13),
                              const Expanded(
                                child: Text(
                                  'Your Representatives',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    height: 1.15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                const SizedBox(height: 12),
                                Expanded(
                                  child: _LandingTile(
                                    key: _branchesKey,
                                    label: 'Federal Branches',
                                    icon: CivicIcons.president,
                                    onTap: () =>
                                        _open(_LandingDestination.branches),
                                    image: const FederalBranchArtwork(
                                      colorAmount: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: _LandingTile(
                                    key: _repsKey,
                                    label: 'Find My Reps',
                                    icon: CivicIcons.representative,
                                    onTap: () =>
                                        _open(_LandingDestination.reps),
                                    image: RotatingLawmakerPortraits(
                                      key: _portraitsKey,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  key: const Key('home-contact-my-reps'),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: _landingNavy,
                                    minimumSize: const Size.fromHeight(60),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    side: const BorderSide(
                                      color: _landingRed,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.mail_outline,
                                    color: _landingRed,
                                    size: 22,
                                  ),
                                  label: const Text(
                                    'Contact My Reps',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 21,
                                      height: 1.15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ContactCongressStartScreen(),
                                    ),
                                  ),
                                ),
                              ],
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
  });
  final String label;
  final IconData icon;
  final Widget image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    child: ExcludeSemantics(
      child: Material(
        color: const Color(0xFFDBE5F2),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              _LandingTileLabel(label: label, icon: icon),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The same full-image overlay accompanies the artwork as its page opens.
class _LandingTileLabel extends StatelessWidget {
  const _LandingTileLabel({required this.label, required this.icon});
  final String label;
  final IconData icon;
  static const _textStyle = TextStyle(
    fontSize: 25,
    height: 1.05,
    letterSpacing: -.4,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xEE102D54), Color(0x00102D54)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    ),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final line = switch (label) {
          'Find My Reps' => 'My Reps',
          'Federal Branches' => 'Branches',
          _ => label,
        };
        final measure = TextPainter(
          text: TextSpan(
            text: line,
            style: DefaultTextStyle.of(context).style.merge(_textStyle),
          ),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
        )..layout();
        final labelWidth = (measure.width + 2).clamp(0.0, bounds.maxWidth - 36);
        measure.dispose();
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: labelWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: const Color(0xFFE9B4C0)),
                  const SizedBox(height: 8),
                  Text(label, style: _textStyle),
                ],
              ),
            ),
          ),
        );
      },
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
    child: FractionallySizedBox(
      widthFactor: .65 + .35 * expansion,
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.all(8 * (1 - expansion)),
        child: Center(
          child: provider.atlas != null && provider.pathCache != null
              ? NationalMap(
                  atlas: provider.atlas!,
                  pathCache: provider.pathCache!,
                  selectedStateId: 'CA',
                )
              : const Icon(
                  CivicIcons.district,
                  size: 72,
                  color: Color(0xFF456A99),
                ),
        ),
      ),
    ),
  );
}
