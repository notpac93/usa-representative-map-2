import 'dart:convert';

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw const FormatException('Federal times require an explicit UTC offset');
  }
  return DateTime.parse(value).toUtc();
}

/// A calendar date has no time or UTC offset. DateTime is used only for
/// Gregorian calendar arithmetic, never as this date's service-start instant.
class _CivilDate implements Comparable<_CivilDate> {
  final int year, month, day;
  const _CivilDate(this.year, this.month, this.day);
  factory _CivilDate.fromCalendar(DateTime value) =>
      _CivilDate(value.year, value.month, value.day);

  _CivilDate addDays(int days) =>
      _CivilDate.fromCalendar(DateTime.utc(year, month, day + days));

  @override
  int compareTo(_CivilDate other) => (year * 10000 + month * 100 + day)
      .compareTo(other.year * 10000 + other.month * 100 + other.day);
}

_CivilDate? _civilDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
    return null;
  }
  return _CivilDate.fromCalendar(parsed);
}

class FederalSource {
  final String id, name, url;
  final List<String> hosts, claims, officeKinds, states, delegatedUrls;
  FederalSource.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      name = j['name'],
      url = j['url'],
      states = List<String>.from(j['states'] ?? []),
      delegatedUrls = List<String>.from(j['delegatedUrls'] ?? []),
      hosts = List<String>.from(j['hosts']),
      claims = List<String>.from(j['claims']),
      officeKinds = List<String>.from(j['officeKinds']);
  bool permits(String value) {
    final u = Uri.tryParse(value);
    if (u != null &&
        delegatedUrls.any((url) => Uri.parse(url).host == u.host) &&
        !delegatedUrls.contains(value))
      return false;
    return u != null &&
        u.scheme == 'https' &&
        hosts.contains(u.host) &&
        u.userInfo.isEmpty &&
        u.port == 443;
  }
}

class FederalOffice {
  final String id, kind, branch, title, state;
  final int? district;
  FederalOffice.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      kind = j['kind'],
      branch = j['branch'],
      title = j['title'],
      state = j['state'] ?? 'US',
      district = j['district'];
  String get jurisdiction => state == 'US'
      ? 'United States'
      : '$state${district == null
            ? ''
            : district == 0
            ? ' · At large'
            : ' · District $district'}';
}

class FederalPerson {
  final String id, name;
  final String? bioguideId, party, photoLocalPath;
  FederalPerson.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      name = j['name'],
      bioguideId = j['bioguideId'],
      party = j['party'],
      photoLocalPath = j['photoLocalPath'];
}

class FederalEvidence {
  final String id, sourceId, url, officeId, personId, claim, sha256;
  final DateTime retrievedAt;
  FederalEvidence.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      sourceId = j['sourceId'],
      url = j['url'],
      officeId = j['officeId'],
      personId = j['personId'],
      claim = j['claim'],
      sha256 = j['sha256'],
      retrievedAt = _date(j['retrievedAt'])!;
}

class FederalTerm {
  final String id, officeId, personId, status;
  final DateTime? scheduledStart,
      scheduledEnd,
      actualStart,
      actualEnd,
      certifiedAt,
      recognizedAt;
  final String? scheduledStartDate;
  final String certificationStatus;
  bool get certificationVerified =>
      status == 'incoming' || certificationStatus == 'certified';

  /// Only a verified instant can be used as a clock boundary. Day-only dates
  /// remain in scheduledStartDate and are rendered and compared as civil dates.
  DateTime? get displayStart => scheduledStart;
  final List<String> evidenceIds;
  final Map<String, String> contact;
  FederalTerm.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      officeId = j['officeId'],
      personId = j['personId'],
      status = j['status'],
      scheduledStart = _date(j['scheduledStart']),
      scheduledEnd = _date(j['scheduledEnd']),
      actualStart = _date(j['actualStart']),
      actualEnd = _date(j['actualEnd']),
      certifiedAt = _date(j['certifiedAt']),
      recognizedAt = _date(j['recognizedAt']),
      scheduledStartDate = j['scheduledStartDate'],
      certificationStatus =
          j['certificationStatus'] ??
          (j['status'] == 'incoming' ? 'certified' : 'notVerified'),
      evidenceIds = List<String>.from(j['evidenceIds']),
      contact = (j['contact'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, v as String),
      );
}

class FederalOfficeView {
  final FederalOffice office;
  final FederalTerm? current, incoming;
  final bool awaitingVerification, reelected;
  const FederalOfficeView(
    this.office,
    this.current,
    this.incoming,
    this.awaitingVerification,
    this.reelected,
  );
}

class FederalSnapshot {
  final DateTime publishedAt;
  final Map<String, FederalOffice> offices;
  final Map<String, FederalPerson> people;
  final Map<String, FederalTerm> terms;
  final Map<String, FederalEvidence> evidence;
  final Map<String, FederalSource> sources;
  FederalSnapshot._(
    this.publishedAt,
    this.offices,
    this.people,
    this.terms,
    this.evidence,
    this.sources,
  );

  factory FederalSnapshot.decode(String value, List<FederalSource> registry) {
    final j = jsonDecode(value) as Map<String, dynamic>;
    if (j['schemaVersion'] != 1) {
      throw const FormatException('Unknown federal schema');
    }
    Map<String, T> indexed<T>(
      String key,
      T Function(Map<String, dynamic>) parse,
      String Function(T) id,
    ) {
      final list = (j[key] as List)
          .map((x) => parse(Map<String, dynamic>.from(x)))
          .toList();
      final map = {for (final x in list) id(x): x};
      if (map.length != list.length) throw FormatException('Duplicate $key');
      return Map.unmodifiable(map);
    }

    final snapshot = FederalSnapshot._(
      _date(j['publishedAt'])!,
      indexed('offices', FederalOffice.fromJson, (x) => x.id),
      indexed('people', FederalPerson.fromJson, (x) => x.id),
      indexed('terms', FederalTerm.fromJson, (x) => x.id),
      indexed('evidence', FederalEvidence.fromJson, (x) => x.id),
      {for (final s in registry) s.id: s},
    );
    final occupied = <String>{};
    final incomingSlots = <String>{};
    for (final e in snapshot.evidence.values) {
      final source = snapshot.sources[e.sourceId];
      final office = snapshot.offices[e.officeId];
      if (source == null ||
          office == null ||
          !snapshot.people.containsKey(e.personId) ||
          !source.permits(e.url) ||
          (source.states.isNotEmpty && !source.states.contains(office.state)) ||
          !source.claims.contains(e.claim) ||
          !source.officeKinds.contains(office.kind) ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(e.sha256) ||
          e.retrievedAt.isAfter(snapshot.publishedAt)) {
        throw const FormatException('Untrusted federal evidence');
      }
    }
    for (final t in snapshot.terms.values) {
      if (!snapshot.offices.containsKey(t.officeId) ||
          !snapshot.people.containsKey(t.personId) ||
          ![
            'current',
            'incoming',
            'incomingRecognized',
            'ended',
            'disputed',
            'withdrawn',
          ].contains(t.status)) {
        throw const FormatException('Invalid federal term');
      }
      final claims = <String>{};
      for (final id in t.evidenceIds) {
        final e = snapshot.evidence[id];
        if (e == null || e.officeId != t.officeId || e.personId != t.personId) {
          throw const FormatException('Mismatched term evidence');
        }
        claims.add(e.claim);
      }
      if (t.status == 'current' &&
          (!occupied.add(t.officeId) ||
              !claims.any(['current', 'assumedOffice'].contains))) {
        throw const FormatException('Unverified or duplicate current occupant');
      }
      if (t.scheduledEnd != null && !claims.contains('scheduledEnd')) {
        throw const FormatException('Unverified term expiration');
      }
      if (t.scheduledStart != null &&
          t.scheduledEnd != null &&
          !t.scheduledEnd!.isAfter(t.scheduledStart!)) {
        throw const FormatException('Invalid term interval');
      }
      if (['incoming', 'incomingRecognized'].contains(t.status) &&
          !incomingSlots.add(t.officeId)) {
        throw const FormatException('Conflicting incoming occupants');
      }
      if (t.status == 'incoming' &&
          (t.certifiedAt == null ||
              (t.scheduledStart == null && t.scheduledStartDate == null) ||
              t.certifiedAt!.isAfter(snapshot.publishedAt) ||
              !claims.containsAll(['certification', 'scheduledStart']))) {
        throw const FormatException('Unverified incoming official');
      }
      if (t.scheduledStartDate != null &&
          (_civilDate(t.scheduledStartDate!) == null ||
              t.scheduledStart != null ||
              !claims.contains('scheduledStart'))) {
        throw const FormatException('Unverified civil start date');
      }
      if (t.status == 'incomingRecognized' &&
          (t.recognizedAt == null ||
              t.recognizedAt!.isAfter(snapshot.publishedAt) ||
              !claims.any(['incomingRecognition', 'certification'].contains))) {
        throw const FormatException('Unverified government recognition');
      }
      if (t.status == 'incomingRecognized' &&
          t.displayStart != null &&
          !claims.contains('scheduledStart')) {
        throw const FormatException('Unverified incoming start');
      }
      if (t.status == 'incomingRecognized' &&
          t.certifiedAt != null &&
          !t.certificationVerified) {
        throw const FormatException('Unverified certification time');
      }
      if (t.status == 'incomingRecognized' &&
          t.certificationVerified &&
          (t.certifiedAt == null ||
              t.certifiedAt!.isAfter(snapshot.publishedAt) ||
              !claims.contains('certification'))) {
        throw const FormatException('Recognition cannot imply certification');
      }
      if (t.actualStart?.isAfter(snapshot.publishedAt) ?? false) {
        throw const FormatException('Future service start');
      }
    }
    return snapshot;
  }

  /// Client time controls visibility and expiry only. It never promotes anyone.
  FederalOfficeView view(String officeId, DateTime now) {
    now = now.toUtc();
    final candidates = terms.values
        .where((t) => t.officeId == officeId)
        .toList();
    FederalTerm? current;
    for (final t in candidates) {
      if (t.status == 'current' &&
          (t.actualStart == null || !now.isBefore(t.actualStart!)) &&
          (t.actualEnd == null || now.isBefore(t.actualEnd!)) &&
          (t.scheduledEnd == null || now.isBefore(t.scheduledEnd!))) {
        current = t;
      }
    }
    // Decoding permits at most one incoming record per office.
    final future = candidates.where(
      (t) => ['incoming', 'incomingRecognized'].contains(t.status),
    );
    FederalTerm? visible;
    var pending = false;
    for (final t in future) {
      final start = t.displayStart;
      final verified = t.certifiedAt ?? t.recognizedAt!;
      if (now.isBefore(verified)) continue;
      var withinWindow = false;
      if (start != null) {
        pending = !now.isBefore(start);
        withinWindow =
            !now.isBefore(start.subtract(const Duration(days: 90))) &&
            now.isBefore(start.add(const Duration(days: 7)));
      } else if (t.scheduledStartDate != null) {
        final day = _civilDate(t.scheduledStartDate!)!;
        // Without an IANA conversion library, use the latest conservative
        // reference date. This cannot open or close the card before the legal
        // local date, even when the user's device is in another time zone.
        final today = _CivilDate.fromCalendar(
          now.subtract(const Duration(hours: 14)),
        );
        // An unspecified time on this day has not necessarily passed yet.
        pending = today.compareTo(day) > 0;
        withinWindow =
            today.compareTo(day.addDays(-90)) >= 0 &&
            today.compareTo(day.addDays(7)) < 0;
      } else {
        withinWindow = now.isBefore(verified.add(const Duration(days: 90)));
      }
      if (withinWindow) {
        visible = t;
        break;
      }
    }
    return FederalOfficeView(
      offices[officeId]!,
      current,
      visible,
      pending,
      current != null && visible?.personId == current.personId,
    );
  }
}
