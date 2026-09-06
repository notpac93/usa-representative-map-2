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
}
