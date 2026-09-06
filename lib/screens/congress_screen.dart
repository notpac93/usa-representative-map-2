import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/civic_data_provider.dart';
import '../data/data_provider.dart';
import '../data/models.dart';
import '../data/bill_models.dart';
import 'lawmaker_detail_screen.dart';
import 'bill_detail_screen.dart';

class CongressScreen extends StatefulWidget {
  final int initialTabIndex;

  const CongressScreen({super.key, this.initialTabIndex = 0});

  @override
  State<CongressScreen> createState() => _CongressScreenState();
}

class _CongressScreenState extends State<CongressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  Map<String, List<Senator>> _senatorsByState = {};
  Map<String, List<Representative>> _repsByState = {};
  List<BillRecord> _federalBills = [];

  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedState = 'ALL';
  String _selectedParty = 'ALL'; // 'ALL', 'R', 'D', 'I'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadCongressData();
  }

  Future<void> _loadCongressData() async {
    final mapProvider = context.read<MapDataProvider>();
    final civicProvider = CivicDataProvider();

    // Check if map provider already has senators & reps
    if (mapProvider.senators != null &&
        mapProvider.senators!.isNotEmpty &&
        mapProvider.houseMembers != null &&
        mapProvider.houseMembers!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _senatorsByState = mapProvider.senators!;
          _repsByState = mapProvider.houseMembers!;
          _isLoading = false;
        });
      }
    } else {
      // Otherwise load directly from asset JSONs
      try {
        final senStr = await rootBundle.loadString('assets/data/senators.json');
        final senList = json.decode(senStr) as List;
        final Map<String, List<Senator>> senMap = {};
        for (var item in senList) {
          final stateId = item['stateId'] as String?;
          final senJsonList = item['senators'] as List?;
          if (stateId != null && senJsonList != null) {
            senMap[stateId] =
                senJsonList.map((e) => Senator.fromJson(e)).toList();
          }
        }

        final repStr = await rootBundle.loadString('assets/data/houseMembers.json');
        final repList = json.decode(repStr) as List;
        final Map<String, List<Representative>> repMap = {};
        for (var item in repList) {
          final stateId = item['stateId'] as String?;
          final repJsonList = item['representatives'] as List?;
          if (stateId != null && repJsonList != null) {
            repMap[stateId] =
                repJsonList.map((e) => Representative.fromJson(e)).toList();
          }
        }

        if (mounted) {
          setState(() {
            _senatorsByState = senMap;
            _repsByState = repMap;
            _isLoading = false;
          });
        }
      } catch (e, stack) {
        debugPrint('Error loading Congress data: $e\n$stack');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }

    // Load federal bills asynchronously in background
    civicProvider.loadData().then((_) {
      if (mounted) {
        setState(() {
          _federalBills = civicProvider.getFederalBills();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  List<MapEntry<String, Senator>> get _allSenatorsWithState {
    final list = <MapEntry<String, Senator>>[];
    _senatorsByState.forEach((state, senators) {
      for (var s in senators) {
        list.add(MapEntry(state, s));
      }
    });
    list.sort((a, b) => a.value.name.compareTo(b.value.name));
    return list;
  }

  List<MapEntry<String, Representative>> get _allRepsWithState {
    final list = <MapEntry<String, Representative>>[];
    _repsByState.forEach((state, reps) {
      for (var r in reps) {
        list.add(MapEntry(state, r));
      }
    });
    list.sort((a, b) => a.value.name.compareTo(b.value.name));
    return list;
  }

  List<MapEntry<String, Senator>> get _filteredSenators {
    return _allSenatorsWithState.where((entry) {
      final state = entry.key;
      final s = entry.value;

      if (_selectedState != 'ALL' && state != _selectedState) return false;

      if (_selectedParty != 'ALL') {
        final p = (s.party ?? '').toUpperCase();
        if (_selectedParty == 'R' && !p.startsWith('R')) return false;
        if (_selectedParty == 'D' && !p.startsWith('D')) return false;
        if (_selectedParty == 'I' && !p.startsWith('I')) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = s.name.toLowerCase().contains(q) ||
            state.toLowerCase().contains(q) ||
            (s.party?.toLowerCase().contains(q) ?? false);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  List<MapEntry<String, Representative>> get _filteredReps {
    return _allRepsWithState.where((entry) {
      final state = entry.key;
      final r = entry.value;

      if (_selectedState != 'ALL' && state != _selectedState) return false;

      if (_selectedParty != 'ALL') {
        final p = (r.party ?? '').toUpperCase();
        if (_selectedParty == 'R' && !p.startsWith('R')) return false;
        if (_selectedParty == 'D' && !p.startsWith('D')) return false;
        if (_selectedParty == 'I' && !p.startsWith('I')) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = r.name.toLowerCase().contains(q) ||
            state.toLowerCase().contains(q) ||
            (r.district?.toLowerCase().contains(q) ?? false) ||
            (r.party?.toLowerCase().contains(q) ?? false);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  List<BillRecord> get _filteredBills {
    if (_searchQuery.isEmpty) return _federalBills;
    final q = _searchQuery.toLowerCase();
    return _federalBills.where((b) {
      return b.title.toLowerCase().contains(q) ||
          b.id.toLowerCase().contains(q) ||
          b.status.toLowerCase().contains(q) ||
          b.sponsorIds.any((s) => s.toLowerCase().contains(q));
    }).toList();
  }

  List<String> get _availableStates {
    final set = <String>{};
    set.addAll(_senatorsByState.keys);
    set.addAll(_repsByState.keys);
    final list = set.toList()..sort();
    return ['ALL', ...list];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'The United States Congress',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0F766E), // Elegant legislative teal/slate
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: 'Official Congress.gov',
            onPressed: () => _launchUrl('https://www.congress.gov'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFDE047),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          isScrollable: true,
          tabs: [
            Tab(
              icon: const Icon(Icons.account_balance, size: 18),
              text: 'Senate (${_allSenatorsWithState.length})',
            ),
            Tab(
              icon: const Icon(Icons.groups, size: 18),
              text: 'House (${_allRepsWithState.length})',
            ),
            Tab(
              icon: const Icon(Icons.description, size: 18),
              text: 'Federal Legislation (${_federalBills.length})',
            ),
            const Tab(
              icon: Icon(Icons.menu_book, size: 18),
              text: 'Article I Powers',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildCongressHero(),
          _buildSearchAndFilters(),
          if (_isLoading)
            const LinearProgressIndicator(
              backgroundColor: Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSenateTab(),
                      _buildHouseTab(),
                      _buildBillsTab(),
                      _buildPowersTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCongressHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F766E), // Deep Legislative Teal
            Color(0xFF134E4A), // Dark Slate Pine
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(
                  Icons.domain,
                  color: Color(0xFFFDE047),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '119th United States Congress • Bicameral Legislature',
                      style: TextStyle(
                        color: Color(0xFFFDE047),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'U.S. Senate & House of Representatives',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Article I of the Constitution vests all federal legislative powers in the Congress.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
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

  Widget _buildSearchAndFilters() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1100),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search members by name, state, or party...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0F766E)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.blueGrey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.blueGrey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedState,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0F766E)),
                      items: _availableStates.map((st) {
                        return DropdownMenuItem(
                          value: st,
                          child: Text(
                            st == 'ALL' ? 'All States' : st,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedState = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPartyFilterChip('All Parties', 'ALL'),
                  const SizedBox(width: 6),
                  _buildPartyFilterChip('Republicans (R)', 'R', color: const Color(0xFFDC2626)),
                  const SizedBox(width: 6),
                  _buildPartyFilterChip('Democrats (D)', 'D', color: const Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  _buildPartyFilterChip('Independents (I)', 'I', color: const Color(0xFF059669)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyFilterChip(String label, String value, {Color? color}) {
    final isSelected = _selectedParty == value;
    final activeColor = color ?? const Color(0xFF0F766E);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedParty = value);
      },
      selectedColor: activeColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF334155),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? activeColor : Colors.blueGrey.shade200,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildSenateTab() {
    final senators = _filteredSenators;
    if (senators.isEmpty) {
      return Center(
        child: Text(
          "No senators match the selected filters.",
          style: TextStyle(color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 600
                ? 2
                : 1;

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1100),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: GridView.builder(
              itemCount: senators.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.5,
              ),
              itemBuilder: (context, index) {
                final entry = senators[index];
                return _buildSenatorCard(entry.key, entry.value);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSenatorCard(String stateId, Senator senator) {
    final isRep = (senator.party ?? '').toUpperCase().startsWith('R');
    final isDem = (senator.party ?? '').toUpperCase().startsWith('D');
    final partyColor = isRep
        ? const Color(0xFFDC2626)
        : isDem
            ? const Color(0xFF2563EB)
            : const Color(0xFF059669);

    final partyBgColor = isRep
        ? const Color(0xFFFEF2F2)
        : isDem
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFECFDF5);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LawmakerDetailScreen(
              lawmaker: senator,
              role: "Senator",
              stateId: stateId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueGrey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE2E8F0),
              backgroundImage: senator.photoLocalPath != null
                  ? AssetImage('assets/img/${senator.photoLocalPath}')
                  : null,
              child: senator.photoLocalPath == null
                  ? const Icon(Icons.person, color: Color(0xFF0F766E), size: 28)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          stateId,
                          style: const TextStyle(
                            color: Color(0xFF0F766E),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: partyBgColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: partyColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          senator.party ?? 'Ind',
                          style: TextStyle(
                            color: partyColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    senator.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'U.S. Senator',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.blueGrey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseTab() {
    final reps = _filteredReps;
    if (reps.isEmpty) {
      return Center(
        child: Text(
          "No representatives match the selected filters.",
          style: TextStyle(color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 600
                ? 2
                : 1;

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1100),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: GridView.builder(
              itemCount: reps.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.5,
              ),
              itemBuilder: (context, index) {
                final entry = reps[index];
                return _buildRepCard(entry.key, entry.value);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildRepCard(String stateId, Representative rep) {
    final isRep = (rep.party ?? '').toUpperCase().startsWith('R');
    final isDem = (rep.party ?? '').toUpperCase().startsWith('D');
    final partyColor = isRep
        ? const Color(0xFFDC2626)
        : isDem
            ? const Color(0xFF2563EB)
            : const Color(0xFF059669);

    final partyBgColor = isRep
        ? const Color(0xFFFEF2F2)
        : isDem
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFECFDF5);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LawmakerDetailScreen(
              lawmaker: rep,
              role: "Representative",
              stateId: stateId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueGrey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE2E8F0),
              backgroundImage: rep.photoLocalPath != null
                  ? AssetImage('assets/img/${rep.photoLocalPath}')
                  : null,
              child: rep.photoLocalPath == null
                  ? const Icon(Icons.person, color: Color(0xFF0F766E), size: 28)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$stateId ${rep.district ?? ""}',
                          style: const TextStyle(
                            color: Color(0xFF0F766E),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: partyBgColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: partyColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          rep.party ?? 'Ind',
                          style: TextStyle(
                            color: partyColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rep.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'U.S. Representative (${rep.district ?? "At-Large"})',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.blueGrey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBillsTab() {
    final bills = _filteredBills;
    if (bills.isEmpty) {
      return Center(
        child: Text(
          "No federal bills match '$_searchQuery'.",
          style: TextStyle(color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bills.length,
          itemBuilder: (context, index) {
            final bill = bills[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blueGrey.shade100),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  bill.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      bill.status,
                      style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13),
                    ),
                    if (bill.sponsorIds.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Sponsors: ${bill.sponsorIds.join(", ")}',
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF0F766E)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BillDetailScreen(bill: bill),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPowersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance, color: Color(0xFF0F766E), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Article I Powers & Legislative Framework',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Constitutional Powers of the United States Congress',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
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
              _buildPowerPoint(
                'Lawmaking & Commerce Clause',
                'Congress enacts federal legislation, regulates interstate and international commerce, collects taxes, coins money, and finances public infrastructure.',
              ),
              const SizedBox(height: 12),
              _buildPowerPoint(
                'Bicameral Structure & Equal State Representation',
                'The Senate grants equal suffrage with 2 senators per state (100 total) serving 6-year terms. The House distributes 435 voting seats proportionally based on national decennial census counts, with 2-year terms.',
              ),
              const SizedBox(height: 12),
              _buildPowerPoint(
                'Advice and Consent & Treaties (Senate)',
                'The Senate confirms presidential nominations for the Cabinet, federal judiciary (including the Supreme Court), ambassadors, and ratifies international treaties by two-thirds vote.',
              ),
              const SizedBox(height: 12),
              _buildPowerPoint(
                'Power of the Purse & Impeachment',
                'All revenue bills must originate in the House of Representatives. The House holds the sole power of impeachment, while the Senate conducts the trial to determine conviction and removal.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPowerPoint(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.check_circle_outline, color: Color(0xFF0F766E), size: 18),
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
