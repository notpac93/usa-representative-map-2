import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/data_provider.dart';
import '../data/models.dart';
import 'lawmaker_detail_screen.dart';

class SupremeCourtScreen extends StatefulWidget {
  const SupremeCourtScreen({super.key});

  @override
  State<SupremeCourtScreen> createState() => _SupremeCourtScreenState();
}

class _SupremeCourtScreenState extends State<SupremeCourtScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Judge> _justices = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'chief', 'associate', 'republican', 'democrat'

  @override
  void initState() {
    super.initState();
    _loadJustices();
  }

  Future<void> _loadJustices() async {
    final provider = context.read<MapDataProvider>();
    if (provider.supremeCourt != null && provider.supremeCourt!.isNotEmpty) {
      setState(() {
        _justices = provider.supremeCourt!;
        _isLoading = false;
      });
      return;
    }

    try {
      final jsonStr = await rootBundle.loadString('assets/data/supreme_court.json');
      final list = json.decode(jsonStr) as List;
      final parsed = list.map((e) => Judge.fromJson(e)).toList();
      if (mounted) {
        setState(() {
          _justices = parsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading Supreme Court data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint("Could not launch $urlString");
      }
    } catch (e) {
      debugPrint("Error launching url: $e");
    }
  }

  List<Judge> get _filteredJustices {
    return _justices.where((justice) {
      // Search text query
      final q = _searchQuery.toLowerCase();
      final matchesQuery = q.isEmpty ||
          justice.name.toLowerCase().contains(q) ||
          justice.title.toLowerCase().contains(q) ||
          (justice.appointedBy?.toLowerCase().contains(q) ?? false) ||
          (justice.party?.toLowerCase().contains(q) ?? false);

      if (!matchesQuery) return false;

      // Filter type
      if (_filterType == 'chief') {
        return justice.title.toLowerCase().contains('chief');
      } else if (_filterType == 'associate') {
        return !justice.title.toLowerCase().contains('chief');
      } else if (_filterType == 'republican') {
        return justice.party?.toLowerCase() == 'republican';
      } else if (_filterType == 'democrat') {
        return justice.party?.toLowerCase() == 'democratic' ||
            justice.party?.toLowerCase() == 'democrat';
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chiefJustice = _justices.firstWhere(
      (j) => j.title.toLowerCase().contains('chief'),
      orElse: () => _justices.isNotEmpty ? _justices.first : Judge(
        name: 'John G. Roberts Jr.',
        title: 'Chief Justice of the United States',
        court: 'Supreme Court of the United States',
      ),
    );

    final associateJustices = _filteredJustices
        .where((j) => !j.title.toLowerCase().contains('chief'))
        .toList();

    final isChiefShown = _filteredJustices.any((j) => j.title.toLowerCase().contains('chief'));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Supreme Court of the United States',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF3B0764), // Rich judicial purple
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: 'Official Supreme Court Website',
            onPressed: () => _launchUrl('https://www.supremecourt.gov'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeroHeader(context),
                ),
                SliverToBoxAdapter(
                  child: _buildFilterSection(context),
                ),
                if (_filteredJustices.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Center(
                        child: Text(
                          "No justices match '$_searchQuery'.",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blueGrey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  if (isChiefShown && _filterType != 'associate') ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          'Chief Justice of the United States',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildJusticeCard(context, chiefJustice, isChief: true),
                      ),
                    ),
                  ],
                  if (associateJustices.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Text(
                          'Associate Justices (${associateJustices.length})',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.crossAxisExtent > 900
                              ? 3
                              : constraints.crossAxisExtent > 600
                                  ? 2
                                  : 1;
                          return SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: crossAxisCount == 1 ? 2.4 : 1.35,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return _buildJusticeCard(
                                  context,
                                  associateJustices[index],
                                  isChief: false,
                                );
                              },
                              childCount: associateJustices.length,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
                SliverToBoxAdapter(
                  child: _buildConstitutionalSection(context),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 40),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B0764), // Deep Purple
            Color(0xFF1E1B4B), // Midnight Indigo
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.balance,
                      color: Color(0xFFFDE047), // Gold scales
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE047).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFFDE047).withOpacity(0.4),
                            ),
                          ),
                          child: const Text(
                            'ARTICLE III • THE JUDICIAL BRANCH',
                            style: TextStyle(
                              color: Color(0xFFFDE047),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The Supreme Court of the United States',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'The highest tribunal in the Nation for all cases and controversies arising under the Constitution or laws of the United States.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _buildFactBadge(Icons.people, '9 Sitting Justices'),
                  _buildFactBadge(Icons.schedule, 'Lifetime Tenure'),
                  _buildFactBadge(Icons.location_on, 'Washington, D.C.'),
                  _buildFactBadge(Icons.gavel, 'Final Judicial Arbiter'),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => _launchUrl('https://www.supremecourt.gov'),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Official Supreme Court Website (supremecourt.gov)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.4)),
                  backgroundColor: Colors.white.withOpacity(0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFactBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFDE047), size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1100),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search justices by name, title, or appointing president...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF3B0764)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blueGrey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blueGrey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3B0764), width: 2),
                ),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Justices (9)', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Chief Justice', 'chief'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Associate Justices (8)', 'associate'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Republican Appointees (6)', 'republican'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Democratic Appointees (3)', 'democrat'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterType = value);
        }
      },
      selectedColor: const Color(0xFF3B0764),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF334155),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF3B0764) : Colors.blueGrey.shade200,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildJusticeCard(BuildContext context, Judge justice, {required bool isChief}) {
    final isRep = justice.party?.toLowerCase() == 'republican';
    final isDem = justice.party?.toLowerCase() == 'democratic' ||
        justice.party?.toLowerCase() == 'democrat';

    final partyColor = isRep
        ? const Color(0xFFDC2626)
        : isDem
            ? const Color(0xFF2563EB)
            : const Color(0xFF475569);

    final partyBgColor = isRep
        ? const Color(0xFFFEF2F2)
        : isDem
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFF1F5F9);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LawmakerDetailScreen(
              lawmaker: justice,
              role: justice.title,
              stateId: "national",
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isChief ? const Color(0xFFF59E0B) : Colors.blueGrey.shade100,
            width: isChief ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isChief ? 0.08 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Portrait Avatar
            Hero(
              tag: 'justice-photo-${justice.name}',
              child: Container(
                width: isChief ? 90 : 76,
                height: isChief ? 90 : 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isChief ? const Color(0xFFF59E0B) : const Color(0xFF3B0764).withOpacity(0.3),
                    width: 2.5,
                  ),
                  image: justice.photoLocalPath != null
                      ? DecorationImage(
                          image: AssetImage('assets/img/${justice.photoLocalPath}'),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: justice.photoLocalPath == null
                    ? const Icon(Icons.person, color: Color(0xFF3B0764), size: 40)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      if (isChief)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: const Text(
                            'CHIEF JUSTICE',
                            style: TextStyle(
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: partyBgColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: partyColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          justice.party ?? 'Independent',
                          style: TextStyle(
                            color: partyColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    justice.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isChief ? 18 : 16,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    justice.title,
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (justice.appointedBy != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.how_to_reg, size: 14, color: Colors.blueGrey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Appointed by ${justice.appointedBy}',
                            style: TextStyle(
                              color: Colors.blueGrey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.blueGrey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstitutionalSection(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1100),
        margin: const EdgeInsets.fromLTRB(20, 32, 20, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B0764).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.gavel, color: Color(0xFF3B0764), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Constitutional Authority (Article III)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'The Judicial Power of the United States',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 14),
            _buildConstitutionalPoint(
              'Judicial Review',
              'Established in Marbury v. Madison (1803), the Court holds the ultimate power to review federal and state statutes and executive orders to declare them unconstitutional.',
            ),
            const SizedBox(height: 12),
            _buildConstitutionalPoint(
              'Jurisdiction & Rule of Four',
              'The Court exercises original jurisdiction over disputes between states and ambassadors, and appellate jurisdiction over federal questions. At least four of the nine Justices must agree to grant a writ of certiorari.',
            ),
            const SizedBox(height: 12),
            _buildConstitutionalPoint(
              'Lifetime Appointment & Independence',
              'Under Article III, Section 1, Justices hold their offices "during good behaviour" to preserve an independent judiciary insulated from political pressure and partisan elections.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstitutionalPoint(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.check_circle_outline, color: Color(0xFF3B0764), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blueGrey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
