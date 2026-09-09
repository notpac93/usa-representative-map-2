import 'dart:async';
import 'package:flutter/material.dart';
import '../data/congress_leadership.dart';
import '../screens/congress_screen.dart';

class CongressScrollSection extends StatefulWidget {
  final double? height;
  final double? width;
  final bool isDocked;

  const CongressScrollSection({
    super.key,
    this.height = 205,
    this.width,
    this.isDocked = true,
  });

  @override
  State<CongressScrollSection> createState() => _CongressScrollSectionState();
}

class _CongressScrollSectionState extends State<CongressScrollSection> {
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _isHovering = false;
  int _hoveredIndex = -1;

  // Repeat leaders list to allow extended seamless scrolling
  late final List<CongressLeader> _leaders;

  @override
  void initState() {
    super.initState();
    // 3 repetitions for continuous looping feel
    _leaders = [
      ...CongressLeadershipData.leaders,
      ...CongressLeadershipData.leaders,
      ...CongressLeadershipData.leaders,
    ];
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!_isHovering && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final current = _scrollController.offset;
        final next = current + 0.8;

        if (next >= maxScroll) {
          // Reset smoothly to start of loop
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(next);
        }
      }
    });
  }

  void _maneuverBackward() {
    if (_scrollController.hasClients) {
      final target = (_scrollController.offset - 295).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _maneuverForward() {
    if (_scrollController.hasClients) {
      final target = (_scrollController.offset + 295).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openCongressScreen([int tabIndex = 0]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CongressScreen(initialTabIndex: tabIndex),
      ),
    );
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDocked = widget.isDocked;

    return MouseRegion(
      onExit: (_) {
        setState(() {
          _isHovering = false;
          _hoveredIndex = -1;
        });
      },
      child: Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? 205,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: isDocked
              ? BorderRadius.zero
              : BorderRadius.circular(16),
          border: isDocked
              ? const Border(
                  top: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                )
              : Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: isDocked
                  ? const Offset(0, -3)
                  : const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Title Block: Congress & Leadership
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.groups,
                          size: 20,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Congress',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A8A),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '119th Congress • Leadership',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '100 Senators • 435 Reps',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _openCongressScreen(0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'All 535 Members',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward,
                            size: 13,
                            color: Color(0xFF1E3A8A),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),

            // Backward maneuver button (<)
            Tooltip(
              message: 'Scroll left',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _maneuverBackward,
                  child: Container(
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: const Icon(
                      Icons.chevron_left,
                      size: 30,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ),
            ),

            // Horizontal auto-scrolling list of large leader cards
            Expanded(
              child: MouseRegion(
                onEnter: (_) {
                  setState(() => _isHovering = true);
                },
                child: ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  itemCount: _leaders.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final leader = _leaders[index];
                    final isCardHovered = _hoveredIndex == index;

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) {
                        setState(() {
                          _isHovering = true;
                          _hoveredIndex = index;
                        });
                      },
                      onExit: (_) {
                        setState(() {
                          if (_hoveredIndex == index) _hoveredIndex = -1;
                        });
                      },
                      child: GestureDetector(
                        onTap: () {
                          _openCongressScreen(
                            leader.chamber == 'Senate' ? 0 : 1,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 295,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isCardHovered
                                ? const Color(0xFFF8FAFC)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCardHovered
                                  ? const Color(0xFF1E3A8A).withOpacity(0.4)
                                  : const Color(0xFFE2E8F0),
                              width: 1.4,
                            ),
                            boxShadow: isCardHovered
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF1E3A8A).withOpacity(0.09),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
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
                            children: [
                              // Large Portrait avatar (68x68)
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: leader.party == 'R'
                                        ? const Color(0xFFDC2626).withOpacity(0.65)
                                        : const Color(0xFF2563EB).withOpacity(0.65),
                                    width: 2.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    leader.assetPath,
                                    width: 68,
                                    height: 68,
                                    fit: BoxFit.cover,
                                    cacheWidth: 160,
                                    cacheHeight: 160,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      color: const Color(0xFFE2E8F0),
                                      child: const Icon(
                                        Icons.person,
                                        size: 34,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Leader Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      leader.name,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      leader.title,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF334155),
                                      ),
                                      maxLines: 1,
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
                                            color: leader.party == 'R'
                                                ? const Color(0xFFFEF2F2)
                                                : const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: leader.party == 'R'
                                                  ? const Color(0xFFFCA5A5)
                                                  : const Color(0xFF93C5FD),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            '${leader.party} • ${leader.chamber}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: leader.party == 'R'
                                                  ? const Color(0xFFB91C1C)
                                                  : const Color(0xFF1D4ED8),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            leader.state,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Forward maneuver button (>)
            Tooltip(
              message: 'Scroll right',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _maneuverForward,
                  child: Container(
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: const Icon(
                      Icons.chevron_right,
                      size: 30,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
