import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/data_provider.dart';
import '../utils/search_handler.dart';
import '../data/models.dart';
import '../data/bill_models.dart';
import '../data/civic_data_provider.dart';
import '../services/congressional_delivery_service.dart';
import 'bill_detail_screen.dart';
import 'contact_congress_screen.dart';
import 'contact_congress_start_screen.dart';
import 'lawmaker_detail_screen.dart';
import 'voter_rules_screen.dart';

class LocalDetailScreen extends StatefulWidget {
  final SearchResult searchResult;

  const LocalDetailScreen({super.key, required this.searchResult});

  @override
  State<LocalDetailScreen> createState() => _LocalDetailScreenState();
}

class _LocalDetailScreenState extends State<LocalDetailScreen> {
  // 0: On Your Ballot (Candidates & Propositions) - DEFAULT & PRIORITIZED
  // 1: Bills & Laws (Pending votes & legislation)
  // 2: Current Representatives (Elected officials with re-election terms)
  // 3: Voter Guide & Deadlines
  int _selectedTab = 0;
  String _candidateFilter = 'All'; // 'All', 'Federal', 'State', 'Local'

  @override
  void initState() {
    super.initState();
    CivicDataProvider().loadData();
  }

  Future<void> _launchExternalUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Could not launch $urlString: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapDataProvider>();
    final searchResult = widget.searchResult;
    final stateId = searchResult.stateId ?? 'US';

    // Extract state
    StateRecord? stateRecord;
    if (searchResult.stateId != null && provider.atlas != null) {
      try {
        stateRecord = provider.atlas!.states.firstWhere(
          (s) => s.id == searchResult.stateId,
        );
      } catch (e) {
        // Not found
      }
    }

    // Extract Governor
    Governor? governor;
    if (searchResult.stateId != null && provider.governors != null) {
      governor = provider.governors![searchResult.stateId!];
    }

    // Extract Senators
    List<Senator> senators = [];
    if (searchResult.stateId != null && provider.senators != null) {
      senators = provider.senators![searchResult.stateId!] ?? [];
    }

    // Extract Mayor(s)
    List<Mayor> localMayors = [];
    if (searchResult.cityName != null &&
        searchResult.stateId != null &&
        provider.mayors != null) {
      final stateMayors = provider.mayors![searchResult.stateId!] ?? [];
      localMayors = stateMayors
          .where(
            (m) => m.city.toLowerCase() == searchResult.cityName!.toLowerCase(),
          )
          .toList();
    }

    // Extract County Demographics
    CountyDemographics? demographics;
    if (searchResult.featureId != null && provider.countyDemo != null) {
      demographics = provider.countyDemo![searchResult.featureId];
    } else if (searchResult.countyName != null && provider.counties != null) {
      try {
        final countyFeature = provider.counties!.firstWhere(
          (f) => f.name.toLowerCase() == searchResult.countyName!.toLowerCase(),
        );
        demographics = provider.countyDemo?[countyFeature.id];
      } catch (e) {
        // Not found
      }
    }

    // Extract Representatives (House Members)
    List<Representative> houseMembers = [];
    if (searchResult.stateId != null && provider.houseMembers != null) {
      houseMembers = provider.houseMembers![searchResult.stateId!] ?? [];
    }

    final isAddress =
        searchResult.type == SearchResultType.address ||
        searchResult.streetAddress != null;
    final isZip = searchResult.type == SearchResultType.zipCode;

    // Load Election, Candidate, and Proposition records
    final civicProvider = CivicDataProvider();
    final electionInfo = civicProvider.getElectionForState(stateId);
    final allCandidates = civicProvider.getCandidatesForJurisdiction(
      stateId,
      cityName: searchResult.cityName,
    );
    final propositions = civicProvider.getPropositionsForJurisdiction(
      stateId,
      cityName: searchResult.cityName,
    );
    final bills = civicProvider.getBillsForState(stateId);

    // Filter candidates based on selected sub-filter
    final filteredCandidates = allCandidates.where((c) {
      if (_candidateFilter == 'Federal') {
        return c.level.toLowerCase() == 'federal';
      }
      if (_candidateFilter == 'State') return c.level.toLowerCase() == 'state';
      if (_candidateFilter == 'Local') return c.level.toLowerCase() == 'local';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          searchResult.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. JURISDICTION / ADDRESS BANNER
          _buildJurisdictionBanner(isAddress, isZip, searchResult),

          const SizedBox(height: 10),

          // Prominent assisted contact flow. A House member is included only
          // when the state has a single, unambiguous at-large district.
          if (senators.isNotEmpty)
            _buildContactCongressCard(
              senators: senators,
              houseMember: houseMembers.length == 1 ? houseMembers.first : null,
              houseCandidates: houseMembers.length > 1
                  ? houseMembers
                  : const [],
              stateName: stateRecord?.name ?? stateId,
              initialAddress: isAddress ? searchResult.title : null,
            ),

          if (senators.isNotEmpty) const SizedBox(height: 16),

          // 2. UPCOMING ELECTION & VOTER COUNTDOWN BANNER (HIGH PRIORITY)
          _buildElectionHubBanner(electionInfo, stateRecord?.name ?? stateId),

          const SizedBox(height: 16),

          // 3. PRIORITIZED SECTION TABS
          _buildSectionNavigationTabs(
            filteredCandidates.length,
            propositions.length,
            bills.length,
          ),

          const SizedBox(height: 16),

          // 4. TAB CONTENT
          if (_selectedTab == 0) ...[
            _buildBallotAndCandidatesSection(filteredCandidates, propositions),
          ] else if (_selectedTab == 1) ...[
            _buildBillsAndLegislationSection(bills),
          ] else if (_selectedTab == 2) ...[
            _buildCurrentRepresentativesSection(
              localMayors: localMayors,
              governor: governor,
              senators: senators,
              houseMembers: houseMembers,
              demographics: demographics,
              stateRecord: stateRecord,
              civicProvider: civicProvider,
            ),
          ] else ...[
            _buildVoterGuideSection(electionInfo, stateRecord?.name ?? stateId),
          ],
        ],
      ),
    );
  }

  Widget _buildJurisdictionBanner(
    bool isAddress,
    bool isZip,
    SearchResult searchResult,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            isAddress
                ? Icons.home
                : isZip
                ? Icons.mark_as_unread
                : Icons.location_on,
            color: const Color(0xFF1E293B),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              searchResult.title,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCongressCard({
    required List<Senator> senators,
    required Representative? houseMember,
    required List<Representative> houseCandidates,
    required String stateName,
    required String? initialAddress,
  }) {
    final recipients = <ContactCongressRecipient>[
      for (final senator in senators)
        if ((senator.contactUrl ?? senator.website)?.isNotEmpty ?? false)
          ContactCongressRecipient(
            name: senator.name,
            role: 'U.S. Senator',
            officialUrl: senator.contactUrl ?? senator.website!,
            bioguideId: senator.bioguideId,
            photoAsset: senator.photoLocalPath == null
                ? null
                : 'assets/img/${senator.photoLocalPath}',
            chamber: CongressionalChamber.senate,
          ),
      if (houseMember != null &&
          (houseMember.contactUrl ?? houseMember.website)?.isNotEmpty == true)
        ContactCongressRecipient(
          name: houseMember.name,
          role: 'U.S. Representative',
          officialUrl: houseMember.contactUrl ?? houseMember.website!,
          bioguideId: houseMember.bioguideId,
          photoAsset: houseMember.photoLocalPath == null
              ? null
              : 'assets/img/${houseMember.photoLocalPath}',
          chamber: CongressionalChamber.house,
        ),
    ];

    if (recipients.isEmpty) return const SizedBox.shrink();

    return Card(
      key: const Key('contact-congress-entry-card'),
      elevation: 0,
      color: const Color(0xFF1E3A8A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.forum_outlined, color: Colors.white, size: 22),
                SizedBox(width: 9),
                Text(
                  'Contact Congress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Confirm your full home address to find your two senators and your district-specific House representative.',
              style: const TextStyle(color: Color(0xFFDBEAFE), height: 1.4),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('contact-congress-start-button'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContactCongressStartScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Find my members'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E3A8A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You’ll review everything once before submitting the same message to your selected offices.',
              style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElectionHubBanner(ElectionRecord election, String stateName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event, size: 14, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 6),
                Text(
                  '${election.nextElectionDate} • ${election.electionType}',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTimelineChip(
                Icons.event_available,
                'Reg. Deadline: ${election.voterRegistrationDeadline.split('(').first.trim()}',
                const Color(0xFF0F172A),
              ),
              _buildTimelineChip(
                Icons.markunread_mailbox,
                'Early Voting: ${election.earlyVotingStart.split('(').first.trim()}',
                const Color(0xFF0F172A),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () =>
                      _launchExternalUrl(election.officialPortalUrl),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text(
                    'Register',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1E3A8A),
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VoterRulesScreen(
                          stateName: stateName,
                          stateId: election.stateId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.badge, size: 14),
                  label: const Text(
                    'ID Guide',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1E3A8A),
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionNavigationTabs(
    int candidatesCount,
    int propositionsCount,
    int billsCount,
  ) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabButton(0, 'On Your Ballot', Icons.ballot),
            _buildTabButton(1, 'Bills & Laws', Icons.gavel),
            _buildTabButton(2, 'Current Reps', Icons.account_balance),
            _buildTabButton(3, 'Voter Guide', Icons.how_to_reg),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : Colors.blueGrey.shade400,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : Colors.blueGrey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: WHAT'S ON YOUR BALLOT (PRIORITIZED) ---
  Widget _buildBallotAndCandidatesSection(
    List<CandidateRecord> candidates,
    List<PropositionRecord> propositions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Candidate Filter Pills
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Electoral Candidates',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Who you are voting for in this jurisdiction',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Federal', 'State', 'Local'].map((filter) {
              final isChosen = _candidateFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: FilterChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isChosen
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: isChosen,
                  selectedColor: const Color(0xFF1E3A8A).withOpacity(0.15),
                  checkmarkColor: const Color(0xFF1E3A8A),
                  onSelected: (val) {
                    setState(() {
                      _candidateFilter = filter;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Candidates List
        if (candidates.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text(
                'No candidate filings currently listed under this filter.',
                style: TextStyle(fontSize: 13, color: Colors.blueGrey),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: candidates
                      .map(
                        (cand) => SizedBox(
                          width: (constraints.maxWidth - 16) / 2,
                          child: CandidateCardWidget(candidate: cand),
                        ),
                      )
                      .toList(),
                );
              }
              return Column(
                children: candidates
                    .map(
                      (cand) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: CandidateCardWidget(candidate: cand),
                      ),
                    )
                    .toList(),
              );
            },
          ),

        const SizedBox(height: 24),

        // Propositions & Ballot Measures Header
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rule, size: 18, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 6),
                Text(
                  'Propositions & Ballot Measures',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Text(
              'Direct citizen votes on state and local initiatives',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (propositions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text(
                'No ballot measures registered for this jurisdiction.',
                style: TextStyle(fontSize: 13, color: Colors.blueGrey),
              ),
            ),
          )
        else
          ...propositions.map((prop) => _buildPropositionCard(prop)),
      ],
    );
  }

  Widget _buildPropositionCard(PropositionRecord prop) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    prop.code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Text(
                    prop.category,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    prop.status,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              prop.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),

            // YES VOTE BREAKDOWN
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.thumb_up,
                    size: 15,
                    color: Color(0xFF047857),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WHAT A YES VOTE MEANS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          prop.yesVoteMeaning,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF064E3B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // NO VOTE BREAKDOWN
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.thumb_down,
                    size: 15,
                    color: Color(0xFFBE123C),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WHAT A NO VOTE MEANS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFBE123C),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          prop.noVoteMeaning,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF881337),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Fiscal Impact
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  size: 15,
                  color: Color(0xFF475569),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Fiscal Impact: ${prop.fiscalSummary}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey.shade800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            if (prop.proponents != null || prop.opponents != null) ...[
              const SizedBox(height: 6),
              if (prop.proponents != null)
                Text(
                  'Supporters: ${prop.proponents}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey.shade700,
                  ),
                ),
              if (prop.opponents != null)
                Text(
                  'Opponents: ${prop.opponents}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey.shade700,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // --- TAB 2: BILLS & LEGISLATION UP FOR VOTE ---
  Widget _buildBillsAndLegislationSection(List<BillRecord> bills) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.gavel, size: 18, color: Color(0xFF1E3A8A)),
            const SizedBox(width: 6),
            Text(
              'Upcoming Bills & Legislation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        Text(
          'Legislation up for consideration by your lawmakers',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
        ),
        const SizedBox(height: 12),
        if (bills.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text(
                'No relevant pending bills found for this jurisdiction.',
                style: TextStyle(fontSize: 13, color: Colors.blueGrey),
              ),
            ),
          )
        else
          Column(
            children: bills
                .map(
                  (b) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      title: Text(
                        b.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Text(
                              'Status: ${b.status}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1E40AF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (b.sponsorIds.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Sponsor: ${b.sponsorIds.join(", ")}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 15,
                        color: Colors.blueGrey,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BillDetailScreen(bill: b),
                          ),
                        );
                      },
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  // --- TAB 3: CURRENT REPRESENTATIVES (WITH RE-ELECTION TIMELINES) ---
  Widget _buildCurrentRepresentativesSection({
    required List<Mayor> localMayors,
    required Governor? governor,
    required List<Senator> senators,
    required List<Representative> houseMembers,
    required CountyDemographics? demographics,
    required StateRecord? stateRecord,
    required CivicDataProvider civicProvider,
  }) {
    final stateId = widget.searchResult.stateId ?? 'US';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.account_balance,
              size: 18,
              color: Color(0xFF1E3A8A),
            ),
            const SizedBox(width: 6),
            Text(
              'Your Current Elected Officials',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        Text(
          'Current incumbents and their scheduled election cycles',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
        ),
        const SizedBox(height: 12),

        // Local Mayor
        if (localMayors.isNotEmpty) ...[
          const Text(
            'Local Executive',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          for (var mayor in localMayors)
            _buildOfficialCard(
              title: mayor.name,
              subtitle: 'Mayor of ${mayor.city}',
              reelectionTag: civicProvider.getIncumbentReelectionTimeline(
                'Mayor',
                stateId,
                name: mayor.name,
              ),
              icon: Icons.person,
              photoPath: null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LawmakerDetailScreen(
                      lawmaker: mayor,
                      role: "Mayor",
                      stateId: stateId,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
        ],

        // State Governor
        if (governor != null) ...[
          const Text(
            'State Executive',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          _buildOfficialCard(
            title: governor.name,
            subtitle:
                'Governor of $stateId (${governor.party ?? "State Executive"})',
            reelectionTag: civicProvider.getIncumbentReelectionTimeline(
              'Governor',
              stateId,
              name: governor.name,
            ),
            icon: Icons.person,
            photoPath: governor.photoLocalPath,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LawmakerDetailScreen(
                    lawmaker: governor,
                    role: "Governor",
                    stateId: stateId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],

        // U.S. Senators
        if (senators.isNotEmpty) ...[
          const Text(
            'U.S. Senators (Federal)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          for (var senator in senators)
            _buildOfficialCard(
              title: senator.name,
              subtitle:
                  'U.S. Senator (${senator.party ?? "Senator"}) • $stateId',
              reelectionTag: civicProvider.getIncumbentReelectionTimeline(
                'Senator',
                stateId,
                name: senator.name,
              ),
              icon: Icons.person,
              photoPath: senator.photoLocalPath,
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
            ),
          const SizedBox(height: 12),
        ],

        // State Representatives (House)
        if (houseMembers.isNotEmpty) ...[
          const Text(
            'U.S. House of Representatives',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFE2E8F0),
                        child: Icon(Icons.groups, color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$stateId Congressional Delegation (${houseMembers.length} Districts)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              civicProvider.getIncumbentReelectionTimeline(
                                'Representative',
                                stateId,
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cities and counties may span multiple congressional districts. Select your specific district on the map or explore candidates on the "On Your Ballot" tab.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // County Demographics
        if (demographics != null) ...[
          const Text(
            'County Voter Profile',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (demographics.population != null)
                    Text(
                      'Total Population: ${demographics.population}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  const SizedBox(height: 4),
                  if (demographics.republican != null &&
                      demographics.democrat != null)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D4ED8).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Democratic',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${(demographics.democrat! * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Republican',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${(demographics.republican! * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (demographics.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      demographics.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOfficialCard({
    required String title,
    required String subtitle,
    required String reelectionTag,
    required IconData icon,
    required String? photoPath,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE2E8F0),
          backgroundImage: photoPath != null
              ? AssetImage('assets/img/$photoPath')
              : null,
          child: photoPath == null
              ? Icon(icon, color: const Color(0xFF1E3A8A))
              : null,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Text(
                reelectionTag,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F766E),
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.blueGrey),
        onTap: onTap,
      ),
    );
  }

  // --- TAB 4: VOTER GUIDE & DEADLINES ---
  Widget _buildVoterGuideSection(ElectionRecord election, String stateName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.how_to_reg, size: 18, color: Color(0xFF1E3A8A)),
            const SizedBox(width: 6),
            Text(
              'Voter Guide & Key Deadlines: $stateName',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        Text(
          'Everything you need to be prepared to cast your vote',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
        ),
        const SizedBox(height: 12),

        _buildGuideCard(
          icon: Icons.badge,
          title: 'Voter ID Requirements',
          body:
              'Check valid forms of photo identification (State Driver License, Passport, Military ID) or non-photo documents accepted at your polling place in $stateName.',
          actionText: 'View State Voter ID Rules',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VoterRulesScreen(
                  stateName: stateName,
                  stateId: election.stateId,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),

        _buildGuideCard(
          icon: Icons.calendar_month,
          title: 'Voter Registration Deadline',
          body:
              '${election.voterRegistrationDeadline}. Ensure your address and party registration are up to date with your county registrar before the deadline.',
          actionText: 'Check Registration on Vote.gov',
          onAction: () => _launchExternalUrl(election.officialPortalUrl),
        ),
        const SizedBox(height: 10),

        _buildGuideCard(
          icon: Icons.forward_to_inbox,
          title: 'Vote By Mail & Absentee Voting',
          body:
              'Early voting begins ${election.earlyVotingStart}. You can track the status of your mail-in ballot from dispatch to tabulation.',
          actionText: 'Track Your Mail Ballot',
          onAction: () => _launchExternalUrl(election.ballotTrackerUrl),
        ),
        const SizedBox(height: 10),

        _buildGuideCard(
          icon: Icons.location_pin,
          title: 'Find Your Polling Location',
          body:
              'Polls are open from ${election.pollsOpenHours} on Election Day (${election.nextElectionDate}). Find your assigned precinct voting place.',
          actionText: 'Official State Election Site',
          onAction: () => _launchExternalUrl(election.officialPortalUrl),
        ),
      ],
    );
  }

  Widget _buildGuideCard({
    required IconData icon,
    required String title,
    required String body,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blueGrey.shade800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: Text(
                  actionText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
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

class CandidateCardWidget extends StatefulWidget {
  final CandidateRecord candidate;

  const CandidateCardWidget({Key? key, required this.candidate})
    : super(key: key);

  @override
  State<CandidateCardWidget> createState() => _CandidateCardWidgetState();
}

class _CandidateCardWidgetState extends State<CandidateCardWidget> {
  bool _isBioExpanded = false;

  void _launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    final isDem = candidate.party.toLowerCase().contains('dem');
    final isRep = candidate.party.toLowerCase().contains('rep');
    final partyColor = isDem
        ? const Color(0xFF1D4ED8)
        : isRep
        ? const Color(0xFFDC2626)
        : const Color(0xFF475569);

    final statusColor = candidate.isIncumbent
        ? const Color(0xFF047857)
        : const Color(0xFF7C3AED);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: partyColor.withOpacity(0.08),
                child: Text(
                  candidate.name
                      .split(' ')
                      .map((e) => e.isNotEmpty ? e[0] : '')
                      .take(2)
                      .join(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: partyColor,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            candidate.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (candidate.isIncumbent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Incumbent',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${candidate.office} • ${candidate.level}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: partyColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            candidate.party,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: partyColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (candidate.bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnimatedCrossFade(
              firstChild: Text(
                candidate.bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF334155),
                  height: 1.5,
                ),
              ),
              secondChild: Text(
                candidate.bio,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF334155),
                  height: 1.5,
                ),
              ),
              crossFadeState: _isBioExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isBioExpanded = !_isBioExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _isBioExpanded ? 'Show less' : 'Read more',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ),
          ],
          if (candidate.platform.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: candidate.platform.map((point) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check,
                        size: 12,
                        color: Color(0xFF475569),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          point.length > 35
                              ? '${point.substring(0, 32)}...'
                              : point,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          if (candidate.website != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _launchExternalUrl(candidate.website!),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Website ↗',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
