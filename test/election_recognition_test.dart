import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/data/federal_officials.dart';
import 'package:usa_map_app/screens/federal_officials_screen.dart';
void main() {
 late Map<String,dynamic> data;late List<FederalSource> sources;
 FederalSnapshot snapshot()=>FederalSnapshot.decode(jsonEncode(data),sources);
 setUp((){
  data=jsonDecode(File('scripts/tests/fixtures/federal_transition.json').readAsStringSync());
  sources=(jsonDecode(File('assets/data/federal_sources.json').readAsStringSync())['sources'] as List).map((s)=>FederalSource.fromJson(s)).toList();
  sources.add(FederalSource.fromJson({'id':'fixture-recognition','name':'Fixture government recognition','url':'https://recognition.example.gov/incoming','hosts':['recognition.example.gov'],'officeKinds':['house'],'claims':['incomingRecognition']}));
  data['terms'][1].remove('certifiedAt');data['terms'][1]['recognizedAt']='2026-11-18T17:00:00Z';data['terms'][1]['status']='incomingRecognized';
  data['terms'][1]['certificationStatus']='notVerified';
  data['evidence'][2]['claim']='incomingRecognition';data['evidence'][2]['sourceId']='fixture-recognition';data['evidence'][2]['url']='https://recognition.example.gov/incoming';
 });
 test('recognition requires government evidence but never becomes serving on the clock',(){
  final s=snapshot();
  expect(s.view('us:house:CA01',DateTime.parse('2027-01-03T18:00:00Z')).current,isNull);
  expect(s.view('us:house:CA01',DateTime.parse('2026-11-19T17:00:00Z')).incoming!.certificationVerified,isFalse);
 });
 test('recognition cannot claim certification or an unsupported start date',(){
  data['terms'][1]['certifiedAt']='2026-11-18T17:00:00Z';
  expect(snapshot,throwsFormatException);data['terms'][1].remove('certifiedAt');
  data['terms'][1]['evidenceIds']=['cert-proof'];
  expect(snapshot,throwsFormatException);
 });
 test('civil date remains day-only and invalid days are rejected',(){
  data['terms'][1].remove('scheduledStart');data['terms'][1]['scheduledStartDate']='2027-01-04';
  final t=snapshot().terms['incoming']!;expect(t.scheduledStart,isNull);expect(t.scheduledStartDate,'2027-01-04');
  data['terms'][1]['scheduledStartDate']='2027-02-31';expect(snapshot,throwsFormatException);
 });
 test('unknown special-election start is never guessed',(){
  data['terms'][1].remove('scheduledStart');data['terms'][1]['evidenceIds']=['cert-proof'];
  expect(snapshot().terms['incoming']!.displayStart,isNull);
 });
 test('two recognized occupants of one seat are rejected',(){
  data['terms'].add({...data['terms'][1],'id':'conflicting'});expect(snapshot,throwsFormatException);
 });
 testWidgets('recognition card clearly distinguishes uncertified results with no second portrait',(tester)async{
  await tester.pumpWidget(MaterialApp(home:FederalOfficialProfileScreen(officeId:'us:house:CA01',initialSnapshot:snapshot(),clock:()=>DateTime.parse('2026-11-19T17:00:00Z'))));
  await tester.pumpAndSettle();
  expect(find.text('Incoming · government recognized'),findsOneWidget);
  expect(find.text('Election certification not yet verified.'),findsOneWidget);
  expect(find.text('Incoming · certified'),findsNothing);
  final card=find.byKey(const Key('federal_transition_notice'));
  expect(find.descendant(of:card,matching:find.byType(Image)),findsNothing);
  await tester.pumpWidget(const SizedBox.shrink());
 });
}
