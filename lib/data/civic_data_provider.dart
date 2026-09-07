import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'bill_models.dart';
import 'models.dart';

class CivicDataProvider {
  static final CivicDataProvider _instance = CivicDataProvider._internal();
  factory CivicDataProvider() => _instance;
  CivicDataProvider._internal();

  static final List<President> defaultPresidents = [
    President(
      id: 'donald-trump',
      name: 'Donald J. Trump',
      ordinal: '47th President of the United States',
      party: 'Republican',
      current: true,
      terms: ['2025–Present', '2017–2021'],
      vicePresident: 'JD Vance',
      phone: '(202) 456-1111',
      address: 'The White House, 1600 Pennsylvania Avenue NW, Washington, DC 20500',
      website: 'https://www.whitehouse.gov',
      photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/5/56/Donald_Trump_official_portrait.jpg',
      photoLocalPath: 'assets/img/presidents/donald_trump.jpg',
      bio: 'Donald J. Trump is the 47th President of the United States, having previously served as the 45th President from 2017 to 2021. As head of the Executive Branch, he exercises executive power under Article II of the Constitution, issuing executive orders to direct federal agencies and set national policy priorities.',
    ),
    President(
      id: 'joe-biden',
      name: 'Joseph R. Biden Jr.',
      ordinal: '46th President of the United States',
      party: 'Democratic',
      current: false,
      terms: ['2021–2025'],
      vicePresident: 'Kamala Harris',
      phone: '(202) 456-1111',
      address: 'The White House (Former Administration)',
      website: 'https://www.whitehouse.gov',
      photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/6/68/Joe_Biden_presidential_portrait.jpg',
      photoLocalPath: 'assets/img/presidents/joe_biden.jpg',
      bio: 'Joseph R. Biden Jr. served as the 46th President of the United States from 2021 to 2025. During his administration, he issued executive orders addressing public health, economic recovery, climate resilience, and federal procurement standards.',
    ),
    President(
      id: 'barack-obama',
      name: 'Barack Obama',
      ordinal: '44th President of the United States',
      party: 'Democratic',
      current: false,
      terms: ['2009–2017'],
      vicePresident: 'Joseph R. Biden Jr.',
      phone: '(202) 456-1111',
      address: 'Barack Obama Presidential Library, National Archives (NARA)',
      website: 'https://www.obamalibrary.gov',
      photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/8/8d/President_Barack_Obama.jpg',
      photoLocalPath: 'assets/img/presidents/barack_obama.jpg',
      bio: 'Barack Obama served as the 44th President of the United States from 2009 to 2017. His administration utilized executive actions on healthcare access, regulatory oversight, national security classification, and financial stability.',
    ),
    President(
      id: 'george-w-bush',
      name: 'George W. Bush',
      ordinal: '43rd President of the United States',
      party: 'Republican',
      current: false,
      terms: ['2001–2009'],
      vicePresident: 'Dick Cheney',
      phone: '(202) 456-1111',
      address: 'George W. Bush Presidential Library, National Archives (NARA)',
      website: 'https://www.georgewbushlibrary.gov',
      photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/d/d4/George-W-Bush.jpeg',
      photoLocalPath: 'assets/img/presidents/george_w_bush.jpg',
      bio: 'George W. Bush served as the 43rd President of the United States from 2001 to 2009. His executive orders focused on homeland security, national defense organization following September 11, faith-based initiatives, and emergency preparedness.',
    ),
    President(
      id: 'william-j-clinton',
      name: 'William J. Clinton',
      ordinal: '42nd President of the United States',
      party: 'Democratic',
      current: false,
      terms: ['1993–2001'],
      vicePresident: 'Al Gore',
      phone: '(202) 456-1111',
      address: 'William J. Clinton Presidential Library, National Archives (NARA)',
      website: 'https://www.clintonlibrary.gov',
      photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/d/d3/Bill_Clinton.jpg',
      photoLocalPath: 'assets/img/presidents/bill_clinton.jpg',
      bio: 'William J. Clinton served as the 42nd President of the United States from 1993 to 2001. His executive orders advanced digital government modernization, civil service reform, environmental justice, and international trade coordination.',
    ),
  ];

  List<BillRecord> _bills = [];
  List<VoteRecord> _votes = [];
  Map<String, FinanceRecord> _finances = {};
  List<ExecutiveOrderRecord> _executiveOrders = [];
  List<President> _presidents = List.from(defaultPresidents);
  List<ElectionRecord> _elections = [];
  List<CandidateRecord> _candidates = [];
  List<PropositionRecord> _propositions = [];

  bool _isLoaded = false;

  Future<void> loadData() async {
    if (_isLoaded) return;

    try {
      await Future.wait([
        // 1. Load Presidents
        () async {
          try {
            final presidentsString = await rootBundle.loadString('assets/data/presidents.json');
            final List<dynamic> presidentsJson = json.decode(presidentsString);
            _presidents = presidentsJson.map((e) => President.fromJson(e)).toList();
          } catch (e) {
            print('Error loading presidents: $e');
          }
        }(),

        // 2. Load Executive Orders
        () async {
          try {
            final eoString = await rootBundle.loadString('assets/data/executive_orders.json');
            final List<dynamic> eoJson = json.decode(eoString);
            _executiveOrders = eoJson.map((e) => ExecutiveOrderRecord.fromJson(e)).toList();
          } catch (e) {
            print('Error loading executive orders: $e');
          }
        }(),

        // 3. Load Bills
        () async {
          try {
            final billsString = await rootBundle.loadString('assets/data/bills.json');
            final List<dynamic> billsJson = json.decode(billsString);
            _bills = billsJson.map((e) => BillRecord.fromJson(e)).toList();
          } catch (e) {
            print('Error loading bills: $e');
          }
        }(),

        // 4. Load Votes
        () async {
          try {
            final votesString = await rootBundle.loadString('assets/data/votes.json');
            final List<dynamic> votesJson = json.decode(votesString);
            _votes = votesJson.map((e) => VoteRecord.fromJson(e)).toList();
          } catch (e) {
            print('Error loading votes: $e');
          }
        }(),

        // 5. Load Finances
        () async {
          try {
            final financeString = await rootBundle.loadString('assets/data/finance.json');
            final List<dynamic> financeJson = json.decode(financeString);
            for (var f in financeJson) {
              final record = FinanceRecord.fromJson(f);
              _finances[record.lawmakerId] = record;
            }
          } catch (e) {
            print('Error loading finances: $e');
          }
        }(),

        // 6. Load Elections, Candidates, and Propositions
        () async {
          try {
            final electionsString = await rootBundle.loadString('assets/data/elections.json');
            final Map<String, dynamic> electionsJson = json.decode(electionsString);
            if (electionsJson['elections'] != null) {
              _elections = (electionsJson['elections'] as List)
                  .map((e) => ElectionRecord.fromJson(e))
                  .toList();
            }
            if (electionsJson['candidates'] != null) {
              _candidates = (electionsJson['candidates'] as List)
                  .map((e) => CandidateRecord.fromJson(e))
                  .toList();
            }
            if (electionsJson['propositions'] != null) {
              _propositions = (electionsJson['propositions'] as List)
                  .map((e) => PropositionRecord.fromJson(e))
                  .toList();
            }
          } catch (e) {
            print('Error loading elections: $e');
          }
        }(),
      ]);

      _isLoaded = true;
    } catch (e) {
      print('Error loading civic data: $e');
    }
  }

  List<BillRecord> getBillsForState(String stateId) {
    // Return bills for the specific state, and also Federal bills ('US')
    return _bills
        .where((b) => b.stateId == stateId || b.stateId == 'US')
        .toList();
  }

  List<BillRecord> getFederalBills() {
    return _bills.where((b) => b.stateId == 'US').toList();
  }

  List<VoteRecord> getVotesForLawmaker(String lawmakerId) {
    return _votes.where((v) => v.lawmakerId == lawmakerId).toList();
  }

  List<VoteRecord> getVotesForBill(String billId) {
    return _votes.where((v) => v.billId == billId).toList();
  }

  FinanceRecord? getFinanceForLawmaker(String lawmakerId) {
    return _finances[lawmakerId];
  }

  List<President> getPresidents() {
    return List.unmodifiable(_presidents);
  }

  President? getCurrentPresident() {
    for (final p in _presidents) {
      if (p.current) return p;
    }
    return _presidents.isNotEmpty ? _presidents.first : null;
  }

  President? getPresidentById(String id) {
    final lowerId = id.trim().toLowerCase();
    for (final p in _presidents) {
      if (p.id.toLowerCase() == lowerId || p.name.toLowerCase().contains(lowerId)) {
        return p;
      }
    }
    return getCurrentPresident();
  }

  List<ExecutiveOrderRecord> getAllExecutiveOrders() {
    return List.unmodifiable(_executiveOrders);
  }

  List<ExecutiveOrderRecord> getExecutiveOrdersForPresident(String presidentNameOrId) {
    final key = presidentNameOrId.trim().toLowerCase();
    if (key.isEmpty || key == 'all') {
      return getAllExecutiveOrders();
    }

    // Extract core surname for matching
    String surname = key;
    if (key.contains('trump')) {
      surname = 'trump';
    } else if (key.contains('biden')) {
      surname = 'biden';
    } else if (key.contains('obama')) {
      surname = 'obama';
    } else if (key.contains('bush')) {
      surname = 'bush';
    } else if (key.contains('clinton')) {
      surname = 'clinton';
    }

    return _executiveOrders.where((eo) {
      final eoPres = eo.president.toLowerCase();
      final eoId = eo.presidentId.toLowerCase();
      return eoId == key ||
          eoId.contains(surname) ||
          eoPres.contains(surname) ||
          key.contains(eoId);
    }).toList();
  }

  ElectionRecord getElectionForState(String stateId) {
    final upper = stateId.toUpperCase().trim();
    for (final e in _elections) {
      if (e.stateId.toUpperCase() == upper) return e;
    }
    // Fallback to national record or default
    for (final e in _elections) {
      if (e.stateId.toUpperCase() == 'US') {
        return ElectionRecord(
          stateId: upper,
          stateName: upper,
          nextElectionDate: e.nextElectionDate,
          electionType: '$upper Statewide & Midterm General Election',
          primaryDate: 'Spring / Summer 2026',
          voterRegistrationDeadline: e.voterRegistrationDeadline,
          earlyVotingStart: e.earlyVotingStart,
          earlyVotingEnd: e.earlyVotingEnd,
          pollsOpenHours: e.pollsOpenHours,
          officialPortalUrl: 'https://vote.gov/register/$upper',
          ballotTrackerUrl: e.ballotTrackerUrl,
          keyOfficesUp: 'U.S. Senate, U.S. House Representatives, State Executive & Legislative Seats',
        );
      }
    }
    return ElectionRecord(
      stateId: upper,
      stateName: upper,
      nextElectionDate: 'November 3, 2026',
      electionType: '2026 Midterm General Election',
      primaryDate: 'Spring 2026',
      voterRegistrationDeadline: 'October 19, 2026',
      earlyVotingStart: 'October 15, 2026',
      earlyVotingEnd: 'November 2, 2026',
      pollsOpenHours: '7:00 AM – 8:00 PM',
      officialPortalUrl: 'https://vote.gov',
      ballotTrackerUrl: 'https://vote.gov',
      keyOfficesUp: 'Federal, State, and Local Offices',
    );
  }

  List<CandidateRecord> getCandidatesForJurisdiction(
    String stateId, {
    String? cityName,
    String? district,
  }) {
    final upper = stateId.toUpperCase().trim();
    final lowerCity = cityName?.toLowerCase().trim();

    final matches = _candidates.where((c) {
      if (c.stateId.toUpperCase() != upper && c.stateId.toUpperCase() != 'US') {
        return false;
      }
      if (lowerCity != null && c.cityName != null) {
        if (c.cityName!.toLowerCase() == lowerCity) return true;
      }
      return true;
    }).toList();

    if (matches.isNotEmpty) {
      return matches;
    }

    // Default generator for any state without explicit custom candidates in JSON
    return [
      CandidateRecord(
        id: 'cand-$upper-sen-1',
        name: 'Incumbent U.S. Senator',
        office: 'U.S. Senator',
        level: 'Federal',
        stateId: upper,
        party: 'Democratic',
        isIncumbent: true,
        status: 'Incumbent',
        electionDate: 'Nov 3, 2026',
        platform: [
          'Federal infrastructure investment and local job growth',
          'Healthcare affordability and lower prescription drug costs',
          'Strengthening democratic institutions and voting access',
        ],
        bio: 'Serving in the United States Senate representing the people of $upper.',
        website: 'https://www.senate.gov',
      ),
      CandidateRecord(
        id: 'cand-$upper-sen-2',
        name: 'Challenger for U.S. Senate',
        office: 'U.S. Senator',
        level: 'Federal',
        stateId: upper,
        party: 'Republican',
        isIncumbent: false,
        status: 'Challenger',
        electionDate: 'Nov 3, 2026',
        platform: [
          'Fiscal discipline and reducing regulatory burdens on businesses',
          'Energy security and domestic supply chain revitalization',
          'Border security enforcement and community safety grants',
        ],
        bio: 'Civic leader and candidate campaigning for change in the U.S. Senate for $upper.',
        website: 'https://vote.gov',
      ),
      CandidateRecord(
        id: 'cand-$upper-house-1',
        name: 'District Congressional Candidate',
        office: 'U.S. Representative',
        level: 'Federal',
        stateId: upper,
        district: district ?? 'At-Large',
        cityName: cityName,
        party: 'Independent / Coalition',
        isIncumbent: false,
        status: 'Candidate',
        electionDate: 'Nov 3, 2026',
        platform: [
          'Bipartisan solutions to lower the cost of living and housing',
          'Modernizing local transportation and public broadband',
          'Transparency in federal budgeting and campaign finance',
        ],
        bio: 'Community advocate seeking to represent this district in the U.S. House of Representatives.',
        website: 'https://www.house.gov',
      ),
    ];
  }

  List<PropositionRecord> getPropositionsForJurisdiction(
    String stateId, {
    String? cityName,
  }) {
    final upper = stateId.toUpperCase().trim();
    final matches = _propositions
        .where((p) => p.stateId.toUpperCase() == upper || p.stateId.toUpperCase() == 'US')
        .toList();

    if (matches.isNotEmpty) {
      return matches;
    }

    return [
      PropositionRecord(
        id: 'prop-$upper-default-1',
        code: 'State Measure 1',
        title: '$upper Infrastructure & Public Water Modernization Act',
        stateId: upper,
        category: 'Infrastructure & Environment',
        electionDate: 'November 3, 2026 Ballot',
        yesVoteMeaning: 'Approves state capital financing to repair municipal water pipelines, replace lead distribution lines, and upgrade flood control.',
        noVoteMeaning: 'Maintains current municipal funding levels without authorized state bond financing.',
        fiscalSummary: 'Funded through existing state capital improvement allocations with no direct increase in state sales tax.',
        proponents: 'State Association of Counties, Clean Water Coalition',
        opponents: 'Taxpayers Advisory Board',
        status: 'Qualified for Ballot',
      ),
      PropositionRecord(
        id: 'prop-$upper-default-2',
        code: 'State Amendment 2',
        title: '$upper Public Education Funding Guarantee',
        stateId: upper,
        category: 'Education',
        electionDate: 'November 3, 2026 Ballot',
        yesVoteMeaning: 'Establishes a baseline annual percentage of state general fund revenues dedicated to K-12 public classroom instruction and teacher compensation.',
        noVoteMeaning: 'Education funding levels remain subject to regular legislative session appropriation cycles.',
        fiscalSummary: 'Directs existing revenue allocation formula toward classroom instruction.',
        proponents: 'State Teachers Union, Parent-Teacher Association',
        opponents: 'State Chamber of Commerce',
        status: 'Qualified for Ballot',
      ),
    ];
  }

  String getIncumbentReelectionTimeline(String role, String stateId, {String? name}) {
    final upperRole = role.toLowerCase();
    final upperState = stateId.toUpperCase();

    if (upperRole.contains('governor')) {
      if (upperState == 'VA' || upperState == 'NJ') {
        return '4-Year Term • Next Gubernatorial Election: Nov 2025 / Nov 2029';
      } else if (upperState == 'KY' || upperState == 'MS' || upperState == 'LA') {
        return '4-Year Term • Next Gubernatorial Election: Nov 2027';
      } else if (upperState == 'NH' || upperState == 'VT') {
        return '2-Year Term • Up for Re-Election: Nov 3, 2026';
      } else {
        return '4-Year Term • Up for Re-Election: Nov 3, 2026';
      }
    }

    if (upperRole.contains('senator')) {
      return '6-Year Term • Class II Seats Up Nov 3, 2026 (Midterms)';
    }

    if (upperRole.contains('representative') || upperRole.contains('house')) {
      return '2-Year Term • All 435 U.S. House Seats Up For Election: Nov 3, 2026';
    }

    if (upperRole.contains('mayor')) {
      return '4-Year Municipal Term • Next Mayoral Election: Nov 2026 / Spring 2027';
    }

    return 'Next Scheduled Election: November 3, 2026';
  }
}

