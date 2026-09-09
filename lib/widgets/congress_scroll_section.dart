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
    this.height = 110,
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
      final target = (_scrollController.offset - 220).clamp(
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
      final target = (_scrollController.offset + 220).clamp(
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
        height: widget.height ?? 110,
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
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.groups,
                          size: 15,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Congress',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A8A),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Leadership',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _openCongressScreen(0),
                    child: const Row(
                      children: [
                        Text(
                          'All 535 Members',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward,
                          size: 11,
                          color: Color(0xFF1E3A8A),
                        ),
                      ],
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
                      size: 24,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ),
            ),

            // Horizontal auto-scrolling list of leader cards
            Expanded(
              child: MouseRegion(
                onEnter: (_) {
                  setState(() => _isHovering = true);
                },
                child: ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  itemCount: _leaders.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
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
                          width: 235,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isCardHovered
                                ? const Color(0xFFF8FAFC)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCardHovered
                                  ? const Color(0xFF1E3A8A).withOpacity(0.3)
                                  : const Color(0xFFF1F5F9),
                              width: 1.2,
                            ),
                            boxShadow: isCardHovered
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF1E3A8A).withOpacity(0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            children: [
                              // Portrait avatar with party colored rim
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: leader.party == 'R'
                                        ? const Color(0xFFDC2626).withOpacity(0.5)
                                        : const Color(0xFF2563EB).withOpacity(0.5),
                                    width: 1.8,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    leader.assetPath,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    cacheWidth: 120,
                                    cacheHeight: 120,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      color: const Color(0xFFE2E8F0),
                                      child: const Icon(
                                        Icons.person,
                                        size: 24,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Leader Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      leader.name,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      leader.title,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF475569),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: leader.party == 'R'
                                                ? const Color(0xFFFEF2F2)
                                                : const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(4),
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
                                              fontSize: 9.0,
                                              fontWeight: FontWeight.w600,
                                              color: leader.party == 'R'
                                                  ? const Color(0xFFB91C1C)
                                                  : const Color(0xFF1D4ED8),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            leader.state,
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              color: Color(0xFF94A3B8),
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
                      size: 24,
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
