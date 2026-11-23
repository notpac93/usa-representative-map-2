import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:usa_map_app/screens/congress_votes_screen.dart';

void main() {
  testWidgets('opens the bill and filters only recorded non-voters', (
    tester,
  ) async {
    final bill = {
      'id': '119-hr-42',
      'label': 'H.R. 42',
      'title': 'Test measure',
      'latestVote': '2025-05-01',
      'rollIds': ['Senate:1:50'],
      'chambers': ['Senate'],
      'congressUrl':
          'https://www.congress.gov/bill/119th-congress/house-bill/42',
      'path': '119/bills/119-hr-42-fixture.json',
    };
    final client = MockClient((request) async {
      final Object payload = request.url.path.endsWith('/index.json')
          ? {
              'schema': 1,
              'checkedAt': '2025-05-01T13:00:00Z',
              'congresses': [
                {
                  'congress': 119,
                  'bills': [bill],
                },
              ],
            }
          : {
              ...bill,
              'metadata': {
                'introduced': '2025-01-03',
                'latestAction': 'Referred to committee.',
                'latestActionDate': '2025-01-03',
                'policyArea': 'Taxation',
                'sponsors': ['A. Sponsor'],
                'cosponsors': [],
                'committees': ['Example Committee'],
                'subjects': [],
                'laws': [],
                'actions': [],
                'summaries': [
                  {
                    'stage': 'Introduced in House',
                    'date': '2025-01-03',
                    'text': 'Official explanation of the test measure.',
                  },
                ],
              },
              'metadataUrl': 'https://www.govinfo.gov/bulkdata/BILLSTATUS/',
              'votes': [
                {
                  'chamber': 'Senate',
                  'date': '2025-05-01',
                  'roll': 50,
                  'question': 'On the Cloture Motion',
                  'description': 'Motion to invoke cloture',
                  'result': 'Agreed to',
                  'amendment': '',
                  'amendmentDetail': '',
                  'url': 'https://www.senate.gov/',
                  'counts': {'yes': 0, 'no': 0, 'present': 1, 'notVoting': 1},
                  'members': [
                    {
                      'name': 'Member Present',
                      'state': 'NY',
                      'party': 'D',
                      'district': '',
                      'position': 'present',
                      'vote': 'Present',
                    },
                    {
                      'name': 'Member Recorded Not Voting',
                      'state': 'CA',
                      'party': 'D',
                      'district': '',
                      'position': 'notVoting',
                      'vote': 'Not Voting',
                    },
                  ],
                },
              ],
            };
      return http.Response(jsonEncode(payload), 200);
    });
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: CongressVotesScreen(client: client)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('H.R. 42 · Test measure'));
    await tester.pumpAndSettle();

    expect(find.text('Member Present'), findsOneWidget);
    expect(find.text('Member Recorded Not Voting'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Not Voting 1'));
    await tester.pumpAndSettle();
    expect(find.text('Member Present'), findsNothing);
    expect(find.text('Member Recorded Not Voting'), findsOneWidget);
  });
}
