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

  const JudicialSectionCard({
    super.key,
    this.isDocked = true,
    this.width,
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isDocked
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(16),
              )
            : BorderRadius.circular(16),
        border: isDocked
            ? const Border(
                left: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              )
            : Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: isDocked ? const Offset(-2, 3) : const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(12, 12, isDocked ? 18 : 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.balance,
                        size: 16,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Judicial Branch',
                        style: TextStyle(
                          fontSize: 13.5,
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
              const SizedBox(width: 4),
              InkWell(
                onTap: _openSupremeCourtScreen,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'Supreme Court',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: Color(0xFF1E3A8A),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3x3 Grid of 9 Justices
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.05,
            ),
            itemCount: _justices.length,
            itemBuilder: (context, index) {
              final justice = _justices[index];
              final isHovered = _hoveredIndex == index;

              return Tooltip(
                message: '${justice.fullName}\n${justice.title}',
                waitDuration: const Duration(milliseconds: 300),
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
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      decoration: BoxDecoration(
                        color: isHovered
                            ? const Color(0xFFF1F5F9)
                            : (justice.isChief
                                ? const Color(0xFFFFFBEB)
                                : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isHovered
                              ? const Color(0xFF1E3A8A)
                              : (justice.isChief
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFFE2E8F0)),
                          width: justice.isChief ? 1.4 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Justice circle avatar
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: justice.isChief
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF94A3B8),
                                width: 1.5,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                justice.assetPath,
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                                cacheWidth: 100,
                                cacheHeight: 100,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: const Color(0xFFE2E8F0),
                                  child: const Icon(
                                    Icons.person,
                                    size: 20,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            justice.shortName,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: justice.isChief
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            justice.isChief ? 'Chief Justice' : 'Associate',
                            style: TextStyle(
                              fontSize: 8.5,
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
              );
            },
          ),
        ],
      ),
    );
  }
}
