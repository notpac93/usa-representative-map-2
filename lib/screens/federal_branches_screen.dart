import 'federal_officials_screen.dart';
import 'package:flutter/material.dart';
import '../design/civic_icons.dart';
import '../widgets/civic_glass.dart';
import 'congress_screen.dart';
import 'president_detail_screen.dart';
import 'supreme_court_screen.dart';

class FederalBranchesScreen extends StatelessWidget {
  const FederalBranchesScreen({super.key, this.managedBackdrop = false});
  final bool managedBackdrop;

  @override
  Widget build(BuildContext context) {
    final foreground = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: civicGlassAppBar('Federal Branches'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    (constraints.maxHeight * .3).clamp(24, 230),
                    20,
                    24,
                  ),
                  children: [
                    TextButton.icon(
                      key: const Key('federal_officials_directory'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FederalOfficialsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.verified_outlined, size: 16),
                      label: const Text('Federal officials · official records'),
                    ),
                    for (final branch in [
                      (
                        title: 'Legislative Branch',
                        icon: CivicIcons.congress,
                        screen: const CongressScreen(),
                      ),
                      (
                        title: 'Executive Branch',
                        icon: CivicIcons.president,
                        screen: const PresidentDetailScreen(),
                      ),
                      (
                        title: 'Judicial Branch',
                        icon: CivicIcons.court,
                        screen: const SupremeCourtScreen(),
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: CivicGlassPanel(
                          padding: EdgeInsets.zero,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => branch.screen,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 26,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      branch.icon,
                                      size: 30,
                                      color: civicNavy,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        branch.title,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: civicNavy,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      CivicIcons.next,
                                      color: civicNavy,
                                    ),
                                  ],
                                ),
                              ),
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
    );
    return managedBackdrop
        ? foreground
        : Stack(
            fit: StackFit.expand,
            children: [const FederalBranchArtwork(), foreground],
          );
  }
}
