import 'package:flutter/material.dart';
import '../screens/president_detail_screen.dart';
import '../data/jd_vance_image.dart';

class ExecutiveSectionCard extends StatefulWidget {
  final bool isDocked;
  final double? width;
  final double? height;

  const ExecutiveSectionCard({
    super.key,
    this.isDocked = true,
    this.width,
    this.height,
  });

  @override
  State<ExecutiveSectionCard> createState() => _ExecutiveSectionCardState();
}

class _ExecutiveSectionCardState extends State<ExecutiveSectionCard> {
  bool _isHoveredCard1 = false;
  bool _isHoveredCard2 = false;
  bool _isHoveredOverview = false;

  void _openExecutiveScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const PresidentDetailScreen()),
    );
  }

  Widget _buildLeaderPortrait({
    required String name,
    required String title,
    required String assetPath,
    required String party,
    required bool isVance,
    required String term,
    required String duties,
    required bool isHovered,
    required ValueChanged<bool> onHoverChanged,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        onTap: _openExecutiveScreen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isHovered ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered
                  ? const Color(0xFF1E3A8A).withOpacity(0.4)
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Large Avatar (80x80)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: party == 'Republican'
                        ? const Color(0xFFDC2626).withOpacity(0.7)
                        : const Color(0xFF2563EB).withOpacity(0.7),
                    width: 2.8,
                  ),
                ),
                child: ClipOval(
                  child: isVance
                      ? Image.memory(
                          jdVanceBytes,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Image.asset(
                            assetPath,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx2, err2, stack2) => Container(
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(
                                Icons.person,
                                size: 40,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        )
                      : Image.asset(
                          assetPath,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          cacheWidth: 180,
                          cacheHeight: 180,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(
                              Icons.person,
                              size: 40,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: const Color(0xFFFCA5A5),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            party,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            term,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      duties,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isDocked
            ? const BorderRadius.only(
                bottomRight: Radius.circular(20),
              )
            : BorderRadius.circular(18),
        border: isDocked
            ? const Border(
                right: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              )
            : Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: isDocked ? const Offset(2, 3) : const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(isDocked ? 20 : 16, 20, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        size: 20,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Executive Branch',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E3A8A),
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Article II • The Presidency & Administration',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _openExecutiveScreen,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
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

          // Scrollable/Flexible Quadrant Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // President
                  _buildLeaderPortrait(
                    name: 'Donald J. Trump',
                    title: '47th President of the United States',
                    assetPath: 'assets/img/presidents/donald_trump.jpg',
                    party: 'Republican',
                    isVance: false,
                    term: '2025–Present',
                    duties: 'Head of State & Gov • Commander-in-Chief',
                    isHovered: _isHoveredCard1,
                    onHoverChanged: (val) => setState(() => _isHoveredCard1 = val),
                  ),
                  const SizedBox(height: 14),

                  // Vice President
                  _buildLeaderPortrait(
                    name: 'JD Vance',
                    title: 'Vice President of the United States',
                    assetPath: 'assets/img/presidents/jd_vance.jpg',
                    party: 'Republican',
                    isVance: true,
                    term: '2025–Present',
                    duties: 'President of Senate • Succession Order #1',
                    isHovered: _isHoveredCard2,
                    onHoverChanged: (val) => setState(() => _isHoveredCard2 = val),
                  ),
                  const SizedBox(height: 14),

                  // Administration & Cabinet Overview Card
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _isHoveredOverview = true),
                    onExit: (_) => setState(() => _isHoveredOverview = false),
                    child: GestureDetector(
                      onTap: _openExecutiveScreen,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isHoveredOverview
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isHoveredOverview
                                ? const Color(0xFF93C5FD)
                                : const Color(0xFFE2E8F0),
                            width: 1.3,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E3A8A).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.business,
                                    size: 16,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Cabinet & Federal Departments',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '15 Executive Departments • 2.9M Civilian & Military Personnel enforcing federal law and national policy.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF475569),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Explore Cabinet & Orders',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _isHoveredOverview
                                          ? const Color(0xFF1D4ED8)
                                          : const Color(0xFF1E3A8A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward,
                                  size: 13,
                                  color: _isHoveredOverview
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFF1E3A8A),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
