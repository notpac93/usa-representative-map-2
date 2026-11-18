import '../services/federal_officials_service.dart';

class CongressLeader {
  final String name;
  final String title;
  final String chamber;
  final String party;
  final String state;
  final String assetPath;
  final String? bioguideId;

  const CongressLeader({
    required this.name,
    required this.title,
    required this.chamber,
    required this.party,
    required this.state,
    required this.assetPath,
    this.bioguideId,
  });
}

class CongressLeadershipData {
  static List<CongressLeader> get leaders {
    final snapshot = FederalOfficialsService.instance.snapshot;
    if (snapshot == null) return const [];
    final result = <CongressLeader>[];
    for (final office in snapshot.offices.values) {
      if (!['houseLeadership', 'senateLeadership'].contains(office.kind))
        continue;
      final term = snapshot.view(office.id, DateTime.now()).current;
      if (term == null) continue;
      final person = snapshot.people[term.personId]!;
      final seat = snapshot.terms.values
          .where(
            (t) =>
                t.personId == person.id &&
                [
                  'house',
                  'senate',
                ].contains(snapshot.offices[t.officeId]!.kind),
          )
          .firstOrNull;
      final jurisdiction = seat == null
          ? null
          : snapshot.offices[seat.officeId];
      result.add(
        CongressLeader(
          name: person.name,
          title: office.title,
          chamber: office.kind == 'houseLeadership' ? 'House' : 'Senate',
          party: person.party ?? '',
          state: jurisdiction?.state ?? 'US',
          assetPath: person.photoLocalPath == null
              ? ''
              : 'assets/img/${person.photoLocalPath}',
          bioguideId: person.bioguideId,
        ),
      );
    }
    return result;
  }

  // Retained historical seed; live leadership always uses the verified snapshot.
  static const List<CongressLeader> historicalSeed = [
    CongressLeader(
      name: 'Mike Johnson',
      title: 'Speaker of the House',
      chamber: 'House',
      party: 'R',
      state: 'LA-04',
      assetPath: 'assets/img/representatives/LA-mike-johnson.jpg',
      bioguideId: 'J000299',
    ),
    CongressLeader(
      name: 'John Thune',
      title: 'Senate Majority Leader',
      chamber: 'Senate',
      party: 'R',
      state: 'SD',
      assetPath: 'assets/img/senators/sd-john-thune.jpg',
      bioguideId: 'T000250',
    ),
    CongressLeader(
      name: 'Hakeem Jeffries',
      title: 'House Democratic Leader',
      chamber: 'House',
      party: 'D',
      state: 'NY-08',
      assetPath: 'assets/img/representatives/NY-hakeem-jeffries.jpg',
      bioguideId: 'J000294',
    ),
    CongressLeader(
      name: 'Chuck Schumer',
      title: 'Senate Democratic Leader',
      chamber: 'Senate',
      party: 'D',
      state: 'NY',
      assetPath: 'assets/img/senators/ny-charles-e-schumer.jpg',
      bioguideId: 'S000148',
    ),
    CongressLeader(
      name: 'Steve Scalise',
      title: 'House Majority Leader',
      chamber: 'House',
      party: 'R',
      state: 'LA-01',
      assetPath: 'assets/img/representatives/LA-steve-scalise.jpg',
      bioguideId: 'S001176',
    ),
    CongressLeader(
      name: 'Katherine Clark',
      title: 'House Democratic Whip',
      chamber: 'House',
      party: 'D',
      state: 'MA-05',
      assetPath: 'assets/img/representatives/MA-katherine-clark.jpg',
      bioguideId: 'C001101',
    ),
    CongressLeader(
      name: 'Tom Emmer',
      title: 'House Majority Whip',
      chamber: 'House',
      party: 'R',
      state: 'MN-06',
      assetPath: 'assets/img/representatives/MN-tom-emmer.jpg',
      bioguideId: 'E000294',
    ),
    CongressLeader(
      name: 'John Barrasso',
      title: 'Senate Majority Whip',
      chamber: 'Senate',
      party: 'R',
      state: 'WY',
      assetPath: 'assets/img/senators/wy-john-barrasso.jpg',
      bioguideId: 'B001261',
    ),
    CongressLeader(
      name: 'Dick Durbin',
      title: 'Senate Democratic Whip',
      chamber: 'Senate',
      party: 'D',
      state: 'IL',
      assetPath: 'assets/img/senators/il-richard-j-durbin.jpg',
      bioguideId: 'D000563',
    ),
    CongressLeader(
      name: 'Pete Aguilar',
      title: 'Democratic Caucus Chair',
      chamber: 'House',
      party: 'D',
      state: 'CA-33',
      assetPath: 'assets/img/representatives/CA-pete-aguilar.jpg',
      bioguideId: 'A000371',
    ),
    CongressLeader(
      name: 'Mitch McConnell',
      title: 'Senior Senator',
      chamber: 'Senate',
      party: 'R',
      state: 'KY',
      assetPath: 'assets/img/senators/ky-mitch-mcconnell.jpg',
      bioguideId: 'M000355',
    ),
  ];
}
