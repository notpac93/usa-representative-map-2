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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: isHovered ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHovered
                  ? const Color(0xFF1E3A8A).withOpacity(0.4)
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withOpacity(0.09),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
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
              // Extra Large Avatar (92x92)
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: party == 'Republican'
                        ? const Color(0xFFDC2626).withOpacity(0.7)
                        : const Color(0xFF2563EB).withOpacity(0.7),
                    width: 3.0,
                  ),
                ),
                child: ClipOval(
                  child: isVance
                      ? Image.memory(
                          jdVanceBytes,
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Image.asset(
                            assetPath,
                            width: 92,
                            height: 92,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx2, err2, stack2) => Container(
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(
                                Icons.person,
                                size: 48,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        )
                      : Image.asset(
                          assetPath,
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                          cacheWidth: 200,
                          cacheHeight: 200,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(
                              Icons.person,
                              size: 48,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Name & Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 2,
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
          // Clean Header (Title + View Details)
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
                        Icons.account_balance,
                        size: 19,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
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
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openExecutiveScreen,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Details',
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
          const SizedBox(height: 18),

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
                    isHovered: _isHoveredCard1,
                    onHoverChanged: (val) => setState(() => _isHoveredCard1 = val),
                  ),
                  const SizedBox(height: 16),

                  // Vice President
                  _buildLeaderPortrait(
                    name: 'JD Vance',
                    title: 'Vice President of the United States',
                    assetPath: 'assets/img/presidents/jd_vance.jpg',
                    party: 'Republican',
                    isVance: true,
                    isHovered: _isHoveredCard2,
                    onHoverChanged: (val) => setState(() => _isHoveredCard2 = val),
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
