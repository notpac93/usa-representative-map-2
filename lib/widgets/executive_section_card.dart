import 'package:flutter/material.dart';
import '../screens/president_detail_screen.dart';

class ExecutiveSectionCard extends StatefulWidget {
  final bool isDocked;
  final double? width;

  const ExecutiveSectionCard({
    super.key,
    this.isDocked = true,
    this.width,
  });

  @override
  State<ExecutiveSectionCard> createState() => _ExecutiveSectionCardState();
}

class _ExecutiveSectionCardState extends State<ExecutiveSectionCard> {
  bool _isHoveredCard1 = false;
  bool _isHoveredCard2 = false;

  void _openExecutiveScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const PresidentDetailScreen()),
    );
  }

  Widget _buildLeaderPortrait({
    required String name,
    required String title,
    required String assetPath,
    required String fallbackNetworkUrl,
    required String party,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isHovered ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovered
                  ? const Color(0xFF1E3A8A).withOpacity(0.3)
                  : const Color(0xFFF1F5F9),
              width: 1.2,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: party == 'Republican'
                        ? const Color(0xFFDC2626).withOpacity(0.4)
                        : const Color(0xFF2563EB).withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    assetPath,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    cacheWidth: 140,
                    cacheHeight: 140,
                    errorBuilder: (context, error, stackTrace) => Image.network(
                      fallbackNetworkUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error2, stackTrace2) => Container(
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(
                          Icons.person,
                          size: 28,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isDocked
            ? const BorderRadius.only(
                bottomRight: Radius.circular(16),
              )
            : BorderRadius.circular(16),
        border: isDocked
            ? const Border(
                right: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              )
            : Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: isDocked ? const Offset(2, 3) : const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(isDocked ? 18 : 14, 14, 14, 14),
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
                        Icons.account_balance,
                        size: 16,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Executive Branch',
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
                onTap: _openExecutiveScreen,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'View Details',
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
          const SizedBox(height: 12),
          // President & Vice President
          _buildLeaderPortrait(
            name: 'Donald J. Trump',
            title: '47th President of the United States',
            assetPath: 'assets/img/presidents/donald_trump.jpg',
            fallbackNetworkUrl:
                'https://upload.wikimedia.org/wikipedia/commons/5/56/Donald_Trump_official_portrait.jpg',
            party: 'Republican',
            isHovered: _isHoveredCard1,
            onHoverChanged: (val) => setState(() => _isHoveredCard1 = val),
          ),
          const SizedBox(height: 8),
          _buildLeaderPortrait(
            name: 'JD Vance',
            title: 'Vice President of the United States',
            assetPath: 'assets/img/presidents/jd_vance.jpg',
            fallbackNetworkUrl:
                'https://bioguide.congress.gov/bioguide/photo/V/V000137.jpg',
            party: 'Republican',
            isHovered: _isHoveredCard2,
            onHoverChanged: (val) => setState(() => _isHoveredCard2 = val),
          ),
        ],
      ),
    );
  }
}
