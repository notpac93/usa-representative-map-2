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

  bool get isInEffect => status == 'In Effect';
  bool get isRevoked => status == 'Revoked';
  bool get isSuperseded => status == 'Superseded';
  bool get isAmended => status == 'Amended';
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
