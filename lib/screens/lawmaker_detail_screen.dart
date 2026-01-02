import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:collection/collection.dart';
import '../data/data_provider.dart';
import '../data/models.dart';
import '../widgets/jurisdiction_map.dart';

class LawmakerDetailScreen extends StatelessWidget {
  final dynamic lawmaker; // Governor, Senator, or Representative
  final String role;
  final String stateId;

  const LawmakerDetailScreen({
    super.key,
    required this.lawmaker,
    required this.role,
    required this.stateId, // Need for map context
  });

  @override
  @override
  Widget build(BuildContext context) {
    String name = '';
    String? party;
    String roleDisplay = role;
    String? subTitle;
    String? photoLocalPath;
    String? phone;
    String? address;
    String? website;
    List<String> extraInfo = [];

    // Extract Data
    if (lawmaker is Governor) {
      final g = lawmaker as Governor;
      name = g.name;
      party = g.party;
      photoLocalPath = g.photoLocalPath;
      phone = g.phone;
      address = g.address;
      if (g.terms.isNotEmpty) {
        extraInfo.add("Terms:\n${g.terms.join('\n')}");
      }
    } else if (lawmaker is Senator) {
      final s = lawmaker as Senator;
      name = s.name;
      party = s.party;
      photoLocalPath = s.photoLocalPath;
      phone = s.phone;
      address = s.address;
      website = s.website;
    } else if (lawmaker is Representative) {
      final r = lawmaker as Representative;
      name = r.name;
      party = r.party;
      photoLocalPath = r.photoLocalPath;
      phone = r.phone;
      address = r.office;
      website = r.website;
      if (r.district != null) {
        extraInfo.add("District: ${r.district}");
      }
    } else if (lawmaker is Mayor) {
      final m = lawmaker as Mayor;
      name = m.name;
      roleDisplay = "Mayor";
      subTitle = m.city;
      photoLocalPath = null;
      website = m.detailsUrl;
    }

    return Scaffold(
      appBar: AppBar(title: Text(name), elevation: 0),
      backgroundColor: Colors.grey[50],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;
          final contentPadding = const EdgeInsets.all(24.0);

          return SingleChildScrollView(
            padding: contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Section (Photo + Bio | Map)
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Photo & Bio
                      Expanded(
                        flex: 1,
                        child: _buildProfileCard(
                          context,
                          name,
                          roleDisplay,
                          party,
                          subTitle,
                          photoLocalPath,
                          lawmaker,
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right: Jurisdiction Map
                      Expanded(
                        flex: 1,
                        child: _buildJurisdictionMapWrapper(context),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildProfileCard(
                        context,
                        name,
                        roleDisplay,
                        party,
                        subTitle,
                        photoLocalPath,
                        lawmaker,
                      ),
                      const SizedBox(height: 24),
                      _buildJurisdictionMapWrapper(context),
                    ],
                  ),

                const SizedBox(height: 32),

                // 2. Info Grid (Cards)
                // We use Wrap to act as a responsive grid
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    // Job Duties (Full Width or Half on large)
                    _buildGridItem(
                      width: isDesktop
                          ? (constraints.maxWidth - 48 - 24) / 2
                          : constraints.maxWidth,
                      child: _buildSectionCard(
                        context,
                        "Job Duties",
                        _getJobDuties(role),
                        Icons.work_outline,
                      ),
                    ),

                    // Contact Info
                    if (phone != null || address != null)
                      _buildGridItem(
                        width: isDesktop
                            ? (constraints.maxWidth - 48 - 24) / 2
                            : constraints.maxWidth,
                        child: Column(
                          children: [
                            if (phone != null)
                              _buildInfoTile(
                                context,
                                Icons.phone,
                                "Phone",
                                phone,
                              ),
                            if (phone != null && address != null)
                              const SizedBox(height: 12),
                            if (address != null)
                              _buildInfoTile(
                                context,
                                Icons.location_on,
                                "Office",
                                address,
                              ),
                          ],
                        ),
                      ),

                    // Website
                    if (website != null)
                      _buildGridItem(
                        width: isDesktop
                            ? (constraints.maxWidth - 48 - 24) / 2
                            : constraints.maxWidth,
                        child: _buildInfoTile(
                          context,
                          Icons.language,
                          "Website",
                          website,
                          isLink: true,
                          isCard: true,
                        ),
                      ),

                    // Extra Info
                    for (var info in extraInfo)
                      _buildGridItem(
                        width: isDesktop
                            ? (constraints.maxWidth - 48 - 24) / 2
                            : constraints.maxWidth,
                        child: _buildSectionCard(
                          context,
                          "Details",
                          info,
                          Icons.info_outline,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridItem({required double width, required Widget child}) {
    // Helper to constrain width in the Wrap
    return SizedBox(width: width, child: child);
  }

  Widget _buildProfileCard(
    BuildContext context,
    String name,
    String roleDisplay,
    String? party,
    String? subTitle,
    String? photoLocalPath,
    dynamic lawmaker,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Photo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
              image: (lawmaker is Mayor && lawmaker.photoUrl != null)
                  ? DecorationImage(
                      image: NetworkImage(lawmaker.photoUrl!),
                      fit: BoxFit.cover,
                      onError: (_, __) {},
                    )
                  : (photoLocalPath != null
                        ? DecorationImage(
                            image: AssetImage('assets/img/$photoLocalPath'),
                            fit: BoxFit.cover,
                          )
                        : null),
            ),
            child: (lawmaker is Mayor && lawmaker.photoUrl != null)
                ? null
                : (photoLocalPath == null
                      ? Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.grey.shade400,
                        )
                      : null),
          ),
          const SizedBox(width: 24),
          // Text Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$roleDisplay${party != null ? ' • $party' : ''}",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subTitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    String content,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    IconData icon,
    String label,
    String? value, {
    bool isLink = false,
    bool isCard = false,
  }) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    final content = InkWell(
      onTap: isLink
          ? () async {
              final uri = Uri.tryParse(value);
              if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri);
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isLink ? Colors.blue : Colors.black87,
                      fontWeight: FontWeight.w500,
                      decoration: isLink ? TextDecoration.underline : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isLink)
              Icon(Icons.open_in_new, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );

    if (isCard) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: content,
      );
    }
    // If not a standalone card, we presume it's inside a column (like the contact block),
    // so we make it look like a card or just a tile.
    // Let's wrap it in a white container to match the grid style.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: content,
    );
  }

  String _getJobDuties(String role) {
    switch (role.toLowerCase()) {
      case 'governor':
        return "As the head of the state's executive branch, the Governor oversees the state government, issues executive orders, and prepares the state budget. They have the power to sign or veto legislation passed by the state legislature, grant pardons, and serve as the commander-in-chief of the state's National Guard.";
      case 'senator':
        return "Senators represent the entire state in the U.S. Senate. Their duties include writing and voting on federal legislation, approving presidential appointments (such as judges and cabinet members), and ratifying treaties. They serve 6-year terms and focus on national and international policy.";
      case 'representative':
        return "Representatives serve a specific congressional district within the state. They respond to local constituents' needs, introduce bills, and vote on legislation in the House of Representatives. They initiate revenue bills and have the power to impeach federal officials.";
      case 'mayor':
        return "The Mayor serves as the head of the city government. They oversee the administration of city services (like police, fire, housing, and transportation), enforce city ordinances, and prepare the municipal budget. They often work with a city council to shape local policy and development.";
      default:
        return "Serve the public interest.";
    }
  }

  Widget _buildJurisdictionMapWrapper(BuildContext context) {
    if (stateId.isEmpty) return const SizedBox.shrink();

    final provider = Provider.of<MapDataProvider>(context, listen: false);
    if (provider.isLoading) return const SizedBox.shrink();

    // Normalized FIPS lookup
    final fips = _stateFips[stateId.toUpperCase()] ?? _stateFips[stateId];
    if (fips == null) return const SizedBox.shrink();

    // Base State Feature
    StateRecord? stateFeature;
    try {
      stateFeature = provider.atlas?.states.firstWhere(
        (s) => s.id == stateId || s.id == fips || s.fips == fips,
      );
    } catch (_) {}

    if (stateFeature == null) return const SizedBox.shrink();

    // If it's a Mayor, we need to load Places asynchronously
    if (role.toLowerCase() == 'mayor' && lawmaker is Mayor) {
      return FutureBuilder<List<PlaceFeature>>(
        future: provider.loadPlacesForState(fips),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final places = snapshot.data ?? [];
          final m = lawmaker as Mayor;
          Path? targetPath;
          Rect bounds = parseSvgPathData(stateFeature!.path).getBounds();
          // Default bounds to state if city not found

          PlaceFeature? cityFeature;

          try {
            // Smart matching for city name
            // Mayor city: "Austin, TX" or "Austin"
            var mName = m.city.split(',')[0].trim().toLowerCase();

            cityFeature = places.firstWhereOrNull((p) {
              final pName = p.name.toLowerCase();
              // PName might be "Austin city" or "Austin town"
              // Check for inclusion
              return pName.contains(mName) ||
                  mName.contains(
                    pName.replaceAll(
                      RegExp(r'\s+(city|town|village|cdp|borough)$'),
                      '',
                    ),
                  );
            });

            if (cityFeature != null) {
              targetPath = parseSvgPathData(cityFeature.path);
              bounds = targetPath.getBounds();
              // Add padding
              bounds = bounds.inflate(bounds.width * 0.2);
            }
          } catch (_) {
            // City not found in Places
          }

          // If still no targetPath, maybe fallback to County/Urban like before?
          // For now, render State map with no target if city missing

          // Also need Context Path (State or County)
          // Ideally, we show County as context for City.
          // But finding the containing county for a city (polygon) geometry is expensive without index.
          // We'll use State as context for now.
          final contextPath = parseSvgPathData(stateFeature.path);

          return _buildMapContainer(
            context,
            contextPath,
            targetPath,
            bounds,
            250,
          );
        },
      );
    }

    // ... Original synchronous logic for other roles ...
    final contextPath = parseSvgPathData(stateFeature.path);
    Path? targetPath;
    Rect bounds = contextPath.getBounds();
    double mapHeight = 250;

    if (role.toLowerCase() == 'governor') {
      targetPath = contextPath;
      mapHeight = 200;
    } else if (role.toLowerCase() == 'senator') {
      targetPath = contextPath;
      final nationalPath = Path();
      if (provider.atlas != null) {
        for (var s in provider.atlas!.states) {
          try {
            nationalPath.addPath(parseSvgPathData(s.path), Offset.zero);
          } catch (_) {}
        }
      }
      bounds = targetPath.getBounds().inflate(
        targetPath.getBounds().width * 1.5,
      );
      return _buildMapContainer(
        context,
        nationalPath,
        targetPath,
        bounds,
        mapHeight,
      );
    } else if (role.toLowerCase() == 'representative' &&
        lawmaker is Representative) {
      final r = lawmaker as Representative;
      if (r.district != null && provider.cd116 != null) {
        // ... existing district logic ...
        String distNum = r.district!;
        // Normalize district number logic (copy-paste from original)
        if (distNum.toLowerCase().contains("at large")) {
          distNum = "00";
        } else {
          final match = RegExp(r'(\d+)').firstMatch(distNum);
          if (match != null) {
            distNum = match.group(0)!.padLeft(2, '0');
          } else {
            distNum = "00";
          }
        }
        final targetId = "$fips$distNum";
        try {
          final feature = provider.cd116!.firstWhere((f) => f.id == targetId);
          targetPath = parseSvgPathData(feature.path);
          bounds = targetPath.getBounds();
        } catch (_) {}
      }
    }

    return _buildMapContainer(
      context,
      contextPath,
      targetPath,
      bounds,
      mapHeight,
    );
  }

  Widget _buildMapContainer(
    BuildContext context,
    Path contextPath,
    Path? targetPath,
    Rect bounds,
    double mapHeight,
  ) {
    return Container(
      height: mapHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          JurisdictionMap(
            contextPath: contextPath,
            targetPath: targetPath,
            bounds: bounds,
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "Jurisdiction Map",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const Map<String, String> _stateFips = {
    'AL': '01',
    'AK': '02',
    'AZ': '04',
    'AR': '05',
    'CA': '06',
    'CO': '08',
    'CT': '09',
    'DE': '10',
    'DC': '11',
    'FL': '12',
    'GA': '13',
    'HI': '15',
    'ID': '16',
    'IL': '17',
    'IN': '18',
    'IA': '19',
    'KS': '20',
    'KY': '21',
    'LA': '22',
    'ME': '23',
    'MD': '24',
    'MA': '25',
    'MI': '26',
    'MN': '27',
    'MS': '28',
    'MO': '29',
    'MT': '30',
    'NE': '31',
    'NV': '32',
    'NH': '33',
    'NJ': '34',
    'NM': '35',
    'NY': '36',
    'NC': '37',
    'ND': '38',
    'OH': '39',
    'OK': '40',
    'OR': '41',
    'PA': '42',
    'RI': '44',
    'SC': '45',
    'SD': '46',
    'TN': '47',
    'TX': '48',
    'UT': '49',
    'VT': '50',
    'VA': '51',
    'WA': '53',
    'WV': '54',
    'WI': '55',
    'WY': '56',
  };
}
