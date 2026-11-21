import '../widgets/election_status_banner.dart';
import 'entity_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/data_provider.dart';
import '../utils/search_handler.dart';
import '../data/bill_models.dart';
import '../data/civic_data_provider.dart';
import '../widgets/official_list_tile.dart';
import 'bill_detail_screen.dart';
import 'house_district_screen.dart';
import 'lawmaker_detail_screen.dart';
import 'voter_rules_screen.dart';

enum LocationPage {
  representatives,
  explore,
  elections,
  ballot,
  bills,
  voting,
  officials,
}

class LocalDetailScreen extends StatefulWidget {
  final SearchResult searchResult;
  final LocationPage page;
  const LocalDetailScreen({
    super.key,
    required this.searchResult,
    this.page = LocationPage.representatives,
  });
  @override
  State<LocalDetailScreen> createState() => _LocalDetailScreenState();
}

class _LocalDetailScreenState extends State<LocalDetailScreen> {
  String _candidateFilter = 'All';
  bool _loadingCivic = true;

  @override
  void initState() {
    super.initState();
    CivicDataProvider().loadData().then((_) {
      if (mounted) setState(() => _loadingCivic = false);
    });
  }

  Future<void> _launchExternalUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _open(LocationPage page) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          LocalDetailScreen(searchResult: widget.searchResult, page: page),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapDataProvider>();
    final r = widget.searchResult;
    final state = r.stateId;
    final stateName = SearchHandler.stateCodeToName[state] ?? state ?? '';
    final civic = CivicDataProvider();
    final page = widget.page;
    final title = switch (page) {
      LocationPage.representatives => 'Your representatives',
      LocationPage.explore => 'Explore this area',
      LocationPage.elections => 'Elections',
      LocationPage.ballot => 'Ballot records',
      LocationPage.bills => 'Bills & laws',
      LocationPage.voting => 'Voting guide',
      LocationPage.officials => 'State & local officials',
    };
    final children = <Widget>[];
    if (page == LocationPage.representatives) {
      final senators = provider.senators?[state] ?? [];
      final members = provider.houseMembers?[state] ?? [];
      final atLarge = members.where((m) => m.districtNumber == 0).toList();
      if (state == null) {
        children.add(
          const Text(
            'Choose a location with a state to see its representatives.',
          ),
        );
      } else if (provider.senators == null &&
          provider.houseMembers == null &&
          provider.isLoading) {
        children.add(const Center(child: CircularProgressIndicator()));
      } else {
        children.add(_heading('U.S. Senate'));
        if (senators.isEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                const ['DC', 'PR', 'GU', 'AS', 'MP', 'VI'].contains(state)
                    ? 'This jurisdiction has no U.S. senators.'
                    : 'No senators are available in the current roster.',
              ),
            ),
          );
        }
        for (final senator in senators) {
          children.add(
            OfficialListTile(
              name: senator.name,
              subtitle: 'U.S. Senator · $state',
              photoPath: senator.photoLocalPath,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LawmakerDetailScreen(
                    lawmaker: senator,
                    role: 'Senator',
                    stateId: state,
                  ),
                ),
              ),
            ),
          );
        }
        children.add(_heading('U.S. House'));
        if (members.length == 1 && atLarge.length == 1) {
          final member = atLarge.single;
          children.add(
            OfficialListTile(
              name: member.name,
              subtitle: 'At-large · $state',
              photoPath: member.photoLocalPath,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LawmakerDetailScreen(
                    lawmaker: member,
                    role: 'Representative',
                    stateId: state,
                  ),
                ),
              ),
            ),
          );
        } else {
          children.add(
            _route(
              'Your House district',
              Icons.location_on_outlined,
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HouseDistrictScreen(searchResult: r),
                ),
              ),
              subtitle: 'Street address needed',
            ),
          );
        }
      }
      children.add(const SizedBox(height: 16));
      children.add(
        TextButton(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF102D54)),
          onPressed: () => _open(LocationPage.explore),
          child: const Text('Explore this area'),
        ),
      );
    } else if (page == LocationPage.explore) {
      children.addAll([
        _route(
          'Representatives',
          Icons.people_outline,
          () => _open(LocationPage.representatives),
        ),
        _route(
          'Elections',
          Icons.how_to_vote_outlined,
          () => _open(LocationPage.elections),
        ),
        _route(
          'Bills & laws',
          Icons.description_outlined,
          () => _open(LocationPage.bills),
        ),
        _route(
          'State & local officials',
          Icons.account_balance_outlined,
          () => _open(LocationPage.officials),
        ),
      ]);
    } else if (page == LocationPage.officials) {
      final governor = provider.governors?[state];
      final mayors = (provider.mayors?[state] ?? []).where(
        (m) => m.city.toLowerCase() == r.cityName?.toLowerCase(),
      );
      if (governor != null) {
        children.add(
          OfficialListTile(
            name: governor.name,
            subtitle: 'Governor · $state',
            photoPath: governor.photoLocalPath,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LawmakerDetailScreen(
                  lawmaker: governor,
                  role: 'Governor',
                  stateId: state!,
                ),
              ),
            ),
          ),
        );
      }
      for (final mayor in mayors) {
        children.add(
          OfficialListTile(
            name: mayor.name,
            subtitle: 'Mayor · ${mayor.city}',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LawmakerDetailScreen(
                  lawmaker: mayor,
                  role: 'Mayor',
                  stateId: state!,
                ),
              ),
            ),
          ),
        );
      }
      if (children.isEmpty) {
        children.add(
          const Text(
            'No state or local officials are available for this location.',
          ),
        );
      }
    } else if (_loadingCivic) {
      children.add(const Center(child: CircularProgressIndicator()));
    } else {
      final election = civic.getElectionForState(state ?? 'US');
      switch (page) {
        case LocationPage.elections:
          children.addAll([
            _buildElectionHubBanner(election, stateName),
            const SizedBox(height: 20),
            _route(
              election.phaseOn(DateTime.now()) == ElectionPhase.upcoming
                  ? 'On your ballot'
                  : 'Ballot records',
              Icons.ballot_outlined,
              () => _open(LocationPage.ballot),
            ),
            _route(
              'Voting guide',
              Icons.how_to_reg_outlined,
              () => _open(LocationPage.voting),
            ),
          ]);
        case LocationPage.ballot:
          final candidates = civic
              .getCandidatesForJurisdiction(state ?? 'US', cityName: r.cityName)
              .where(
                (c) =>
                    _candidateFilter == 'All' ||
                    c.level.toLowerCase() == _candidateFilter.toLowerCase(),
              )
              .toList();
          children.add(
            _buildBallotAndCandidatesSection(
              candidates,
              civic.getPropositionsForJurisdiction(
                state ?? 'US',
                cityName: r.cityName,
              ),
            ),
          );
        case LocationPage.bills:
          children.add(
            _buildBillsAndLegislationSection(
              civic.getBillsForState(state ?? 'US'),
            ),
          );
        case LocationPage.voting:
          children.add(_buildVoterGuideSection(election, stateName));
        default:
          break;
      }
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(title),
        actions: [
          EntityDetailsButton(
            name: r.title,
            category: r.type == SearchResultType.city
                ? 'City'
                : r.type == SearchResultType.county
                ? 'County'
                : 'Local jurisdiction',
            stateId: state,
            facts: {
              if (r.cityName != null) 'City': r.cityName!,
              if (r.countyName != null) 'County': r.countyName!,
            },
          ),
        ],
        backgroundColor: const Color(0xFF102D54),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    r.title,
                    style: const TextStyle(color: Color(0xFF51647B)),
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF51647B),
      ),
    ),
  );

  Widget _route(
    String title,
    IconData icon,
    VoidCallback onTap, {
    String? subtitle,
  }) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFD9E1EC)),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      leading: Icon(icon, color: const Color(0xFF102D54)),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF102D54),
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF102D54)),
      onTap: onTap,
    ),
  );
  Widget _buildElectionHubBanner(ElectionRecord election, String stateName) {
    return ElectionStatusBanner(
      election: election,
      now: DateTime.now(),
      onOfficialInformation: () =>
          _launchExternalUrl(election.officialPortalUrl),
    );
  }

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
                  'Recorded candidates · not certified results',
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
                  selectedColor: const Color(
                    0xFF1E3A8A,
                  ).withValues(alpha: 0.15),
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
                'No verified ballot measure records are available for this jurisdiction.',
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

  // Dedicated voting guide page.
  Widget _buildVoterGuideSection(ElectionRecord election, String stateName) {
    if (election.phaseOn(DateTime.now()) != ElectionPhase.upcoming) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Election information: $stateName',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ElectionStatusBanner(
            election: election,
            now: DateTime.now(),
            onOfficialInformation: () =>
                _launchExternalUrl(election.officialPortalUrl),
          ),
          const SizedBox(height: 12),
          const Text(
            'Use the official election office for current registration requirements and polling information. Past deadlines are not valid instructions for a future election.',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  const CandidateCardWidget({super.key, required this.candidate});

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
            color: Colors.black.withValues(alpha: 0.03),
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
                backgroundColor: partyColor.withValues(alpha: 0.08),
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
                              color: statusColor.withValues(alpha: 0.08),
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
                            color: partyColor.withValues(alpha: 0.08),
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
