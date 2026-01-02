import '../data/models.dart';

enum TerritoryContext { city, county, state, nation }

class OfficialHierarchy {
  /// Sorts a list of officials based on Universal Order (Top-Down).
  ///
  /// [prioritizeWhere]: Optional predicate function. Officials matching this will be moved to the top.
  static List<dynamic> sortOfficials(
    List<dynamic> officials, {
    bool Function(dynamic)? prioritizeWhere,
  }) {
    if (officials.isEmpty) return [];

    // Create a copy to avoid mutating the original list
    final sortedList = List<dynamic>.from(officials);

    sortedList.sort((a, b) {
      // 0. Priority Check
      final isPriorityA = prioritizeWhere != null && prioritizeWhere(a);
      final isPriorityB = prioritizeWhere != null && prioritizeWhere(b);

      if (isPriorityA && !isPriorityB) return -1; // A comes first
      if (!isPriorityA && isPriorityB) return 1; // B comes first

      // 1. Universal Rank Check
      final rankA = _getUniversalRank(a);
      final rankB = _getUniversalRank(b);
      return rankA.compareTo(rankB);
    });

    return sortedList;
  }

  /// Returns the static rank for an official type.
  /// Lower number = Higher Authority (Top of list).
  static int _getUniversalRank(dynamic official) {
    // User Preferred Order:
    // 1. President (Future)
    // 2. Governor
    // 3. Senators
    // 4. Representatives
    // 5. Local (Mayors, County Judges, etc.)

    if (official is Governor) return 20;

    // Legislative
    if (official is Senator) return 30;
    if (official is Representative) return 31;

    // County (Future)
    // if (official is CountyJudge) return 40;

    // Local
    if (official is Mayor) return 50;

    return 100; // Unknown/Other
  }
}
