// import 'dart:convert';

/// Represents a State geometry record from the Atlas.
class StateRecord {
  final String id;
  final String name;
  final String fips;
  final String path; // SVG path data
  final List<double> bbox;
  final List<double> centroid;

  StateRecord({
    required this.id,
    required this.name,
    required this.fips,
    required this.path,
    required this.bbox,
    required this.centroid,
  });

  factory StateRecord.fromJson(Map<String, dynamic> json) {
    return StateRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      fips: json['fips'] as String,
      path: json['path'] as String,
      bbox: (json['bbox'] as List).map((e) => (e as num).toDouble()).toList(),
      centroid: (json['centroid'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }
}

/// The root Atlas object containing all map geometry.
class Atlas {
  final double width;
  final double height;
  final String projection;
  final List<StateRecord> states;

  Atlas({
    required this.width,
    required this.height,
    required this.projection,
    required this.states,
  });

  factory Atlas.fromJson(Map<String, dynamic> json) {
    return Atlas(
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      projection: json['projection'] as String? ?? 'albersUsa',
      states: (json['states'] as List)
          .map((e) => StateRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A City feature with projected coordinates.
class CityFeature {
  final String id;
  final String name;
  final double x;
  final double y;
  final double lon;
  final double lat;
  final int? population;

  CityFeature({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.lon,
    required this.lat,
    this.population,
  });

  factory CityFeature.fromJson(Map<String, dynamic> json) {
    return CityFeature(
      id: json['id'] as String,
      name: json['name'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      lat: (json['lat'] as num).toDouble(),
      population: json['population'] as int?,
    );
  }
}

/// Generic overlay feature (paths).
class OverlayFeature {
  final String id;
  final String name;
  final String path;
  final List<double> bbox;

  OverlayFeature({
    required this.id,
    required this.name,
    required this.path,
    required this.bbox,
  });

  factory OverlayFeature.fromJson(Map<String, dynamic> json) {
    return OverlayFeature(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      bbox: (json['bbox'] as List).map((e) => (e as num).toDouble()).toList(),
    );
  }
}

/// A Governor record.
class Governor {
  final String name;
  final String? party;
  final String? photoUrl;
  final String? photoLocalPath;
  final List<String> terms;
  final String? phone;
  final String? address;

  Governor({
    required this.name,
    this.party,
    this.photoUrl,
    this.photoLocalPath,
    this.terms = const [],
    this.phone,
    this.address,
  });

  factory Governor.fromJson(Map<String, dynamic> json) {
    var gov = json['governor'] ?? json; // Handle nested or direct
    // If nested in "governor" key from scraping:
    if (json.containsKey('governor')) {
      gov = json['governor'];
    }

    // Parse contact info if available
    String? phone;
    String? address;
    if (gov['contact'] != null) {
      phone = gov['contact']['phone'];
      address = gov['contact']['address'];
    }

    return Governor(
      name: gov['name'] ?? '',
      party: gov['party'],
      photoUrl: gov['photoUrl'],
      photoLocalPath: gov['photoLocalPath'],
      terms: (gov['terms'] as List?)?.map((e) => e.toString()).toList() ?? [],
      phone: phone,
      address: address,
    );
  }
}

/// A Senator record.
class Senator {
  final String name;
  final String? party; // 'R', 'D', 'I'
  final String? photoUrl;
  final String? photoLocalPath;
  final String? phone;
  final String? address;
  final String? website;

  Senator({
    required this.name,
    this.party,
    this.photoUrl,
    this.photoLocalPath,
    this.phone,
    this.address,
    this.website,
  });

  factory Senator.fromJson(Map<String, dynamic> json) {
    return Senator(
      name: json['name'] ?? '',
      party: json['party'],
      photoUrl: json['photoUrl'],
      photoLocalPath: json['photoLocalPath'],
      phone: json['phone'],
      address: json['officeAddress'],
      website: json['website'],
    );
  }
}

/// A House Representative record.
class Representative {
  final String name;
  final String? party; // 'R', 'D'
  final String? district; // "1st", "At Large"
  final String? photoUrl;
  final String? photoLocalPath;
  final String? phone;
  final String? office;
  final String? website;

  Representative({
    required this.name,
    this.party,
    this.district,
    this.photoUrl,
    this.photoLocalPath,
    this.phone,
    this.office,
    this.website,
  });

  factory Representative.fromJson(Map<String, dynamic> json) {
    return Representative(
      name: json['name'] ?? '',
      party: json['party'],
      district: json['district'],
      photoUrl: json['photoUrl'],
      photoLocalPath: json['photoLocalPath'],
      phone: json['phone'],
      office: json['office'],
      website: json['website'],
    );
  }
}
