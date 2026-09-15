import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/supreme_court_screen.dart';
import '../screens/lawmaker_detail_screen.dart';
import '../data/data_provider.dart';
import '../data/models.dart';

class JusticeItem {
  final String shortName;
  final String fullName;
  final String title;
  final String assetPath;
  final bool isChief;

  const JusticeItem({
    required this.shortName,
    required this.fullName,
    required this.title,
    required this.assetPath,
    this.isChief = false,
  });
}

class JudicialSectionCard extends StatefulWidget {
  final bool isDocked;
  final double? width;
  final double? height;

  const JudicialSectionCard({
    super.key,
    this.isDocked = true,
    this.width,
    this.height,
  });

  @override
  State<JudicialSectionCard> createState() => _JudicialSectionCardState();
}

class _JudicialSectionCardState extends State<JudicialSectionCard> {
  int _hoveredIndex = -1;

  static const List<JusticeItem> _justices = [
    JusticeItem(
      shortName: 'Roberts',
      fullName: 'John G. Roberts Jr.',
      title: 'Chief Justice',
      assetPath: 'assets/img/supremecourt/john_g__roberts_jr_.jpg',
      isChief: true,
    ),
    JusticeItem(
      shortName: 'Thomas',
      fullName: 'Clarence Thomas',
      title: 'Associate Justice',
      assetPath: 'assets/img/supremecourt/clarence_thomas.jpg',
    ),
    JusticeItem(
      shortName: 'Alito',
      fullName: 'Samuel A. Alito Jr.',
      title: 'Associate Justice',
      assetPath: 'assets/img/supremecourt/samuel_a__alito_jr_.jpg',
    ),
    JusticeItem(
      shortName: 'Sotomayor',
      fullName: 'Sonia Sotomayor',
      title: 'Associate Justice',
      assetPath: 'assets/img/supremecourt/sonia_sotomayor.jpg',
    ),
    JusticeItem(
      shortName: 'Kagan',
      fullName: 'Elena Kagan',
      title: 'Associate Justice',
      assetPath: 'assets/img/supremecourt/elena_kagan.jpg',
    ),
    JusticeItem(
      shortName: 'Gorsuch',
      fullName: 'Neil M. Gorsuch',
      title: 'Associate Justice',
      assetPath: 'assets/img/supremecourt/neil_m__gorsuch.jpg',
    ),
    JusticeItem(
      shortName: 'Kavanaugh',
      fullName: 'Brett M. Kavanaugh',
      title: 'Associate Justice',
      assetPath: 'assets/img/supremecourt/brett_m__kavanaugh.jpg',
    ),
    JusticeItem(
      shortName: 'Barrett',
      fullName: 'Amy Coney Barrett',
      title: 'Associate Justice',
      assetPath: 'assets/img/supremecourt/amy_coney_barrett.jpg',
    ),
    JusticeItem(
      shortName: 'Jackson',
      fullName: 'Ketanji Brown Jackson',
      title: 'Associate Justice',
      assetPath: 'assets/img/supremecourt/ketanji_brown_jackson.jpg',
    ),
  ];

  void _openSupremeCourtScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const SupremeCourtScreen()),
    );
  }

  void _openJusticeScreen(JusticeItem item) {
    final provider = Provider.of<MapDataProvider>(context, listen: false);
    Judge? matchedJudge;

    if (provider.supremeCourt != null) {
      for (var judge in provider.supremeCourt!) {
        final jName = judge.name.toLowerCase();
        final iName = item.fullName.toLowerCase();
        final sName = item.shortName.toLowerCase();
        if (jName == iName || jName.contains(sName) || iName.contains(jName)) {
          matchedJudge = judge;
          break;
        }
      }
    }

    final judgeToOpen = matchedJudge ??
        Judge(
          name: item.fullName,
          title: item.isChief ? 'Chief Justice of the United States' : 'Associate Justice',
          court: 'Supreme Court of the United States',
          photoLocalPath: item.assetPath.replaceFirst('assets/img/', ''),
        );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => LawmakerDetailScreen(
          lawmaker: judgeToOpen,
          role: judgeToOpen.title,
          stateId: 'national',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDocked = widget.isDocked;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      padding: EdgeInsets.fromLTRB(18, 20, isDocked ? 20 : 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clean Header (Title link + Supreme Court link)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _openSupremeCourtScreen,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.balance,
                            size: 19,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'Judicial Branch',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E3A8A),
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openSupremeCourtScreen,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Supreme Court',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 15,
                        color: Color(0xFF1E3A8A),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3x3 Grid of 9 Justices dynamically calculated to fit 100% visible without scrolling
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double availableHeight = constraints.maxHeight;
                final double availableWidth = constraints.maxWidth;

                final double itemHeight = (availableHeight - 16) / 3;
                final double itemWidth = (availableWidth - 16) / 3;

                final double avatarSize = (itemHeight - 34).clamp(42.0, 76.0);
                final double childAspect = (itemWidth / itemHeight).clamp(0.65, 1.25);

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: childAspect,
                  ),
                  itemCount: _justices.length,
                  itemBuilder: (context, index) {
                    final justice = _justices[index];
                    final isHovered = _hoveredIndex == index;

                    return Tooltip(
                      message: '${justice.fullName}\n${justice.title}',
                      waitDuration: const Duration(milliseconds: 250),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _hoveredIndex = index),
                        onExit: (_) => setState(() {
                          if (_hoveredIndex == index) _hoveredIndex = -1;
                        }),
                        child: GestureDetector(
                          onTap: () => _openJusticeScreen(justice),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            decoration: BoxDecoration(
                              color: isHovered
                                  ? const Color(0xFFF1F5F9).withOpacity(0.9)
                                  : (justice.isChief
                                      ? const Color(0xFFFFFBEB).withOpacity(0.5)
                                      : Colors.transparent),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Prominent Justice avatar
                                  Container(
                                    width: avatarSize,
                                    height: avatarSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: justice.isChief
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF94A3B8).withOpacity(0.75),
                                        width: justice.isChief ? 3.0 : 2.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: justice.isChief
                                              ? const Color(0xFFD97706).withOpacity(0.25)
                                              : Colors.black.withOpacity(0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        justice.assetPath,
                                        width: avatarSize,
                                        height: avatarSize,
                                        fit: BoxFit.cover,
                                        cacheWidth: 260,
                                        cacheHeight: 260,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                          color: const Color(0xFFE2E8F0),
                                          child: Icon(
                                            Icons.person,
                                            size: avatarSize * 0.5,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    justice.shortName,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: justice.isChief
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    justice.isChief ? 'Chief Justice' : 'Associate',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: justice.isChief
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
