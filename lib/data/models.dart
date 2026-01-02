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

class CountyDemographics {
  final String? population;
  final double? republican;
  final double? democrat;
  final String? description;

  CountyDemographics({
    this.population,
    this.republican,
    this.democrat,
    this.description,
  });

  factory CountyDemographics.fromJson(Map<String, dynamic> json) {
    return CountyDemographics(
      population: json['population'] as String?,
      republican: (json['republican'] as num?)?.toDouble(),
      democrat: (json['democrat'] as num?)?.toDouble(),
      description: json['description'] as String?,
    );
  }
}

class SelectedFeature {
  final OverlayFeature feature;
  final String displayName;
  CountyDemographics? demographics;

  SelectedFeature(this.feature, this.displayName, {this.demographics});
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

/// A Mayor record.
class Mayor {
  final String name;
  final String city;
  final String? photoUrl;
  final String? detailsUrl;

  Mayor({
    required this.name,
    required this.city,
    this.photoUrl,
    this.detailsUrl,
  });

  factory Mayor.fromJson(Map<String, dynamic> json) {
    return Mayor(
      name: json['name'] ?? '',
      city: json['city'] ?? '',
      photoUrl: json['photoUrl'],
      detailsUrl: json['detailsUrl'],
    );
  }
}

/// A Place (city/town) boundary feature from Census TIGER/Line.
class PlaceFeature {
  final String id; // GEOID
  final String name; // e.g., "Austin city"
  final String stateFips;
  final String lsad; // Legal/Statistical Area Description
  final String path; // SVG path data
  final List<double> bbox; // [minX, minY, maxX, maxY]

  PlaceFeature({
    required this.id,
    required this.name,
    required this.stateFips,
    required this.lsad,
    required this.path,
    required this.bbox,
  });

  factory PlaceFeature.fromGeoJson(
    Map<String, dynamic> feature,
    String stateFips,
  ) {
    final properties = feature['properties'] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;

    // Extract GEOID and NAME from properties
    final id = properties['GEOID'] as String? ?? '';
    final name = properties['NAME'] as String? ?? '';
    final lsad = properties['LSAD'] as String? ?? '';

    // Convert GeoJSON geometry to SVG path
    // This is a simplified conversion - actual implementation would need
    // proper coordinate projection and path generation
    final path = _geometryToPath(geometry);
    final bbox = _calculateBbox(geometry);

    return PlaceFeature(
      id: id,
      name: name,
      stateFips: stateFips,
      lsad: lsad,
      path: path,
      bbox: bbox,
    );
  }

  static String _geometryToPath(Map<String, dynamic> geometry) {
    final type = geometry['type'] as String;
    final buffer = StringBuffer();

    if (type == 'Polygon') {
      final coordinates = geometry['coordinates'] as List;
      _writePolygon(buffer, coordinates);
    } else if (type == 'MultiPolygon') {
      final coordinates = geometry['coordinates'] as List;
      for (final poly in coordinates) {
        _writePolygon(buffer, poly as List);
      }
    }
    return buffer.toString();
  }

  static void _writePolygon(StringBuffer buffer, List ringList) {
    if (ringList.isEmpty) return;
    // Exterior ring
    final exterior = ringList[0] as List;
    if (exterior.isEmpty) return;

    buffer.write('M${exterior[0][0]},${exterior[0][1]}');
    for (int i = 1; i < exterior.length; i++) {
      buffer.write('L${exterior[i][0]},${exterior[i][1]}');
    }
    buffer.write('Z');

    // Interior rings (holes)
    // SVG path fill-rule usually handles this if drawn in sequence
    for (int i = 1; i < ringList.length; i++) {
      final hole = ringList[i] as List;
      if (hole.isEmpty) continue;
      buffer.write('M${hole[0][0]},${hole[0][1]}');
      for (int k = 1; k < hole.length; k++) {
        buffer.write('L${hole[k][0]},${hole[k][1]}');
      }
      buffer.write('Z');
    }
  }

  static List<double> _calculateBbox(Map<String, dynamic> geometry) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    void processRing(List ring) {
      for (final point in ring) {
        final x = (point[0] as num).toDouble();
        final y = (point[1] as num).toDouble();
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }

    final type = geometry['type'] as String;
    if (type == 'Polygon') {
      final coordinates = geometry['coordinates'] as List;
      for (final ring in coordinates) processRing(ring as List);
    } else if (type == 'MultiPolygon') {
      final coordinates = geometry['coordinates'] as List;
      for (final poly in coordinates) {
        for (final ring in poly) processRing(ring as List);
      }
    }

    if (minX == double.infinity) return [0, 0, 0, 0];
    return [minX, minY, maxX, maxY];
  }
}
