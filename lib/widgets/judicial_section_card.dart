import 'package:flutter/material.dart';
import '../screens/supreme_court_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDocked = widget.isDocked;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isDocked
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(20),
              )
            : BorderRadius.circular(18),
        border: isDocked
            ? const Border(
                left: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              )
            : Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: isDocked ? const Offset(-2, 3) : const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(18, 20, isDocked ? 20 : 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clean Header (Title + Supreme Court link)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
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
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Scrollable/Flexible Quadrant Content: 3x3 Grid of 9 Justices
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.82,
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
                        onTap: _openSupremeCourtScreen,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isHovered
                                ? const Color(0xFFF1F5F9)
                                : (justice.isChief
                                    ? const Color(0xFFFFFBEB)
                                    : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isHovered
                                  ? const Color(0xFF1E3A8A)
                                  : (justice.isChief
                                      ? const Color(0xFFFDE68A)
                                      : const Color(0xFFE2E8F0)),
                              width: justice.isChief ? 1.8 : 1.2,
                            ),
                            boxShadow: isHovered
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF1E3A8A).withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Prominent Justice avatar (64x64)
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: justice.isChief
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF94A3B8),
                                      width: justice.isChief ? 2.6 : 1.8,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      justice.assetPath,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      cacheWidth: 150,
                                      cacheHeight: 150,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                        color: const Color(0xFFE2E8F0),
                                        child: const Icon(
                                          Icons.person,
                                          size: 32,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  justice.shortName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: justice.isChief
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  justice.isChief ? 'Chief Justice' : 'Associate',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
