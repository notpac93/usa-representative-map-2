import '../screens/federal_officials_screen.dart';
import '../services/federal_officials_service.dart';
import '../data/federal_officials.dart';
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

  void _openVicePresidentScreen() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FederalOfficialProfileScreen(officeId: 'us:vicePresident')));
  }

  FederalPerson? _person(String officeId) {
    final snapshot = FederalOfficialsService.instance.snapshot;
    if (snapshot == null || !snapshot.offices.containsKey(officeId)) return null;
    final t = snapshot.view(officeId,DateTime.now()).current;
    return t == null ? null : snapshot.people[t.personId];
  }

  @override
  void initState() { super.initState(); FederalOfficialsService.instance.addListener(_refresh); }
  void _refresh() { if (mounted) setState(() {}); }
  @override
  void dispose() { FederalOfficialsService.instance.removeListener(_refresh); super.dispose(); }

  Widget _buildLeaderPortrait({
    required String name,
    required String title,
    required String assetPath,
    required String party,
    required bool isVance,
    required bool isHovered,
    required ValueChanged<bool> onHoverChanged,
    required double avatarSize,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isHovered
                ? const Color(0xFFF1F5F9).withOpacity(0.85)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Extra Large Avatar
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: party == 'Republican'
                        ? const Color(0xFFDC2626).withOpacity(0.75)
                        : const Color(0xFF2563EB).withOpacity(0.75),
                    width: 3.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: isVance
                      ? Image.memory(
                          jdVanceBytes,
                          width: avatarSize,
                          height: avatarSize,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Image.asset(
                            assetPath,
                            width: avatarSize,
                            height: avatarSize,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx2, err2, stack2) => Container(
                              color: const Color(0xFFE2E8F0),
                              child: Icon(
                                Icons.person,
                                size: avatarSize * 0.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        )
                      : Image.asset(
                          assetPath,
                          width: avatarSize,
                          height: avatarSize,
                          fit: BoxFit.cover,
                          cacheWidth: 320,
                          cacheHeight: 320,
                          errorBuilder: (context, error, stackTrace) => Container(
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
              const SizedBox(width: 18),
              // Name & Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 19.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                        height: 1.35,
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
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      padding: EdgeInsets.fromLTRB(isDocked ? 20 : 16, 20, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clean Header (Title link + View Details)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _openExecutiveScreen,
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
          const SizedBox(height: 12),

          // Always visible non-scrolling content dynamically sized for available height
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double availableHeight = constraints.maxHeight;
                final double avatarSize = ((availableHeight - 48) / 2 - 16)
                    .clamp(60.0, 110.0);
                final double spacing = (availableHeight < 320 ? 8.0 : 14.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // President
                    _buildLeaderPortrait(
                      name: _person('us:president')?.name ?? 'Service awaiting verification',
                      title: 'President of the United States',
                      assetPath: _person('us:president')?.photoLocalPath == null ? '' : 'assets/img/${_person('us:president')!.photoLocalPath}',
                      party: '',
                      isVance: false,
                      isHovered: _isHoveredCard1,
                      onHoverChanged: (val) => setState(() => _isHoveredCard1 = val),
                      avatarSize: avatarSize,
                      onTap: _openExecutiveScreen,
                    ),
                    SizedBox(height: spacing),

                    // Vice President
                    _buildLeaderPortrait(
                      name: _person('us:vicePresident')?.name ?? 'Service awaiting verification',
                      title: 'Vice President of the United States',
                      assetPath: _person('us:vicePresident')?.photoLocalPath == null ? '' : 'assets/img/${_person('us:vicePresident')!.photoLocalPath}',
                      party: '',
                      isVance: false,
                      isHovered: _isHoveredCard2,
                      onHoverChanged: (val) => setState(() => _isHoveredCard2 = val),
                      avatarSize: avatarSize,
                      onTap: _openVicePresidentScreen,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
