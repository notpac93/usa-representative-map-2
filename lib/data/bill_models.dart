class BillRecord {
  final String id;
  final String title;
  final String description;
  final String status;
  final String stateId; // 'US' for federal, or state abbreviation e.g. 'TX'
  final String? upcomingDate;
  final List<String> sponsorIds;

  BillRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.stateId,
    this.upcomingDate,
    required this.sponsorIds,
  });

  factory BillRecord.fromJson(Map<String, dynamic> json) {
    return BillRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      stateId: json['stateId'] as String,
      upcomingDate: json['upcomingDate'] as String?,
      sponsorIds: List<String>.from(json['sponsorIds'] ?? []),
    );
  }
}

class VoteRecord {
  final String billId;
  final String lawmakerId;
  final String vote; // 'Yea', 'Nay', 'Abstain'

  VoteRecord({
    required this.billId,
    required this.lawmakerId,
    required this.vote,
  });

  factory VoteRecord.fromJson(Map<String, dynamic> json) {
    return VoteRecord(
      billId: json['billId'] as String,
      lawmakerId: json['lawmakerId'] as String,
      vote: json['vote'] as String,
    );
  }
}

class DonorRecord {
  final String name;
  final double amount;

  DonorRecord({required this.name, required this.amount});

  factory DonorRecord.fromJson(Map<String, dynamic> json) {
    return DonorRecord(
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

class FinanceRecord {
  final String lawmakerId;
  final double totalRaised;
  final List<DonorRecord> topDonors;

  FinanceRecord({
    required this.lawmakerId,
    required this.totalRaised,
    required this.topDonors,
  });

  factory FinanceRecord.fromJson(Map<String, dynamic> json) {
    return FinanceRecord(
      lawmakerId: json['lawmakerId'] as String,
      totalRaised: (json['totalRaised'] as num).toDouble(),
      topDonors: (json['topDonors'] as List)
          .map((e) => DonorRecord.fromJson(e))
          .toList(),
    );
  }
}

class ExecutiveOrderRecord {
  final String id;
  final String orderNumber;
  final String title;
  final String signingDate;
  final String publicationDate;
  final String president;
  final String presidentId;
  final String citation;
  final String url;
  final String pdfUrl;
  final String? summary;
  final String status;
  final String? statusDetails;
  final String? dispositionNotes;

  ExecutiveOrderRecord({
    required this.id,
    required this.orderNumber,
    required this.title,
    required this.signingDate,
    required this.publicationDate,
    required this.president,
    required this.presidentId,
    required this.citation,
    required this.url,
    required this.pdfUrl,
    this.summary,
    this.status = 'In Effect',
    this.statusDetails,
    this.dispositionNotes,
  });

  bool get isInEffect => status.toLowerCase() == 'in effect' || status.toLowerCase() == 'active';
  bool get isRevoked => status.toLowerCase().contains('revoked');
  bool get isSuperseded => status.toLowerCase().contains('superseded');
  bool get isAmended => status.toLowerCase().contains('amended');
  bool get isEnjoined => status.toLowerCase().contains('enjoined');

  factory ExecutiveOrderRecord.fromJson(Map<String, dynamic> json) {
    return ExecutiveOrderRecord(
      id: json['id'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      title: json['title'] as String? ?? '',
      signingDate: json['signingDate'] as String? ?? '',
      publicationDate: json['publicationDate'] as String? ?? '',
      president: json['president'] as String? ?? '',
      presidentId: json['presidentId'] as String? ?? '',
      citation: json['citation'] as String? ?? '',
      url: json['url'] as String? ?? '',
      pdfUrl: json['pdfUrl'] as String? ?? '',
      summary: json['summary'] as String?,
      status: json['status'] as String? ?? 'In Effect',
      statusDetails: json['statusDetails'] as String?,
      dispositionNotes: json['dispositionNotes'] as String?,
    );
  }
}

class ElectionRecord {
  final String stateId;
  final String stateName;
  final String nextElectionDate;
  final String electionType;
  final String primaryDate;
  final String voterRegistrationDeadline;
  final String earlyVotingStart;
  final String earlyVotingEnd;
  final String pollsOpenHours;
  final String officialPortalUrl;
  final String ballotTrackerUrl;
  final String keyOfficesUp;

  ElectionRecord({
    required this.stateId,
    required this.stateName,
    required this.nextElectionDate,
    required this.electionType,
    required this.primaryDate,
    required this.voterRegistrationDeadline,
    required this.earlyVotingStart,
    required this.earlyVotingEnd,
    required this.pollsOpenHours,
    required this.officialPortalUrl,
    required this.ballotTrackerUrl,
    required this.keyOfficesUp,
  });

  factory ElectionRecord.fromJson(Map<String, dynamic> json) {
    return ElectionRecord(
      stateId: json['stateId'] as String? ?? 'US',
      stateName: json['stateName'] as String? ?? '',
      nextElectionDate: json['nextElectionDate'] as String? ?? 'November 3, 2026',
      electionType: json['electionType'] as String? ?? '2026 Midterm General Election',
      primaryDate: json['primaryDate'] as String? ?? 'Spring 2026',
      voterRegistrationDeadline: json['voterRegistrationDeadline'] as String? ?? 'October 19, 2026',
      earlyVotingStart: json['earlyVotingStart'] as String? ?? 'October 15, 2026',
      earlyVotingEnd: json['earlyVotingEnd'] as String? ?? 'November 2, 2026',
      pollsOpenHours: json['pollsOpenHours'] as String? ?? '7:00 AM – 8:00 PM',
      officialPortalUrl: json['officialPortalUrl'] as String? ?? 'https://vote.gov',
      ballotTrackerUrl: json['ballotTrackerUrl'] as String? ?? 'https://vote.gov',
      keyOfficesUp: json['keyOfficesUp'] as String? ?? 'Federal, State, and Local Offices',
    );
  }
}

class CandidateRecord {
  final String id;
  final String name;
  final String office;
  final String level; // 'Federal', 'State', 'Local'
  final String stateId;
  final String? district;
  final String? cityName;
  final String party;
  final bool isIncumbent;
  final String status; // 'Incumbent', 'Challenger', 'Candidate (Open Seat)'
  final String? photoUrl;
  final String? photoLocalPath;
  final List<String> platform;
  final String bio;
  final String? website;
  final String electionDate;

  CandidateRecord({
    required this.id,
    required this.name,
    required this.office,
    required this.level,
    required this.stateId,
    this.district,
    this.cityName,
    required this.party,
    this.isIncumbent = false,
    required this.status,
    this.photoUrl,
    this.photoLocalPath,
    this.platform = const [],
    required this.bio,
    this.website,
    this.electionDate = 'Nov 3, 2026',
  });

  factory CandidateRecord.fromJson(Map<String, dynamic> json) {
    return CandidateRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      office: json['office'] as String? ?? '',
      level: json['level'] as String? ?? 'Federal',
      stateId: json['stateId'] as String? ?? 'US',
      district: json['district'] as String?,
      cityName: json['cityName'] as String?,
      party: json['party'] as String? ?? 'Independent',
      isIncumbent: json['isIncumbent'] as bool? ?? false,
      status: json['status'] as String? ?? (json['isIncumbent'] == true ? 'Incumbent' : 'Challenger'),
      photoUrl: json['photoUrl'] as String?,
      photoLocalPath: json['photoLocalPath'] as String?,
      platform: (json['platform'] as List?)?.map((e) => e.toString()).toList() ?? [],
      bio: json['bio'] as String? ?? '',
      website: json['website'] as String?,
      electionDate: json['electionDate'] as String? ?? 'Nov 3, 2026',
    );
  }
}

class PropositionRecord {
  final String id;
  final String code; // e.g. "Proposition 1"
  final String title;
  final String stateId;
  final String? cityName;
  final String category;
  final String electionDate;
  final String yesVoteMeaning;
  final String noVoteMeaning;
  final String fiscalSummary;
  final String? proponents;
  final String? opponents;
  final String status;

  PropositionRecord({
    required this.id,
    required this.code,
    required this.title,
    required this.stateId,
    this.cityName,
    required this.category,
    required this.electionDate,
    required this.yesVoteMeaning,
    required this.noVoteMeaning,
    required this.fiscalSummary,
    this.proponents,
    this.opponents,
    this.status = 'Qualified for Ballot',
  });

  factory PropositionRecord.fromJson(Map<String, dynamic> json) {
    return PropositionRecord(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      stateId: json['stateId'] as String? ?? 'US',
      cityName: json['cityName'] as String?,
      category: json['category'] as String? ?? 'General Civic',
      electionDate: json['electionDate'] as String? ?? 'November 3, 2026 Ballot',
      yesVoteMeaning: json['yesVoteMeaning'] as String? ?? '',
      noVoteMeaning: json['noVoteMeaning'] as String? ?? '',
      fiscalSummary: json['fiscalSummary'] as String? ?? '',
      proponents: json['proponents'] as String?,
      opponents: json['opponents'] as String?,
      status: json['status'] as String? ?? 'Qualified for Ballot',
    );
  }
}
