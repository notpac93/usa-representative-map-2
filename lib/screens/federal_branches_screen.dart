import 'package:flutter/material.dart';
import '../design/civic_icons.dart';
import '../widgets/civic_glass.dart';
import 'congress_screen.dart';
import 'president_detail_screen.dart';
import 'supreme_court_screen.dart';

const _branchCardHeight = 108.0;

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
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  children: [
                    for (final branch in [
                      (
                        title: 'Legislative Branch',
                        image: 'assets/img/branch-legislative.jpg',
                        icon: Icons.account_balance_outlined,
                        screen: const CongressScreen(),
                      ),
                      (
                        title: 'Executive Branch',
                        image: 'assets/img/branch-executive.jpg',
                        icon: Icons.home_outlined,
                        screen: const PresidentDetailScreen(),
                      ),
                      (
                        title: 'Judicial Branch',
                        image: 'assets/img/branch-judicial.jpg',
                        icon: Icons.balance_outlined,
                        screen: const SupremeCourtScreen(),
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _BranchImageCard(
                          title: branch.title,
                          icon: branch.icon,
                          image: branch.image,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => branch.screen),
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

class _BranchImageCard extends StatelessWidget {
  const _BranchImageCard({
    required this.title,
    required this.icon,
    required this.image,
    required this.onTap,
  });
  final String title, image;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: title,
    onTap: onTap,
    child: ExcludeSemantics(
      child: Material(
        color: civicNavy,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _branchCardHeight),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    image,
                    key: ValueKey(image),
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    excludeFromSemantics: true,
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xF5102D54), Color(0x10102D54)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 30, color: const Color(0xFFF0C7D0)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(CivicIcons.next, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
