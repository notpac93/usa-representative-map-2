import 'package:flutter/material.dart';
import '../data/models.dart';
import '../screens/lawmaker_detail_screen.dart'; // Needed for navigation

class TerritorySummaryCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? population;
  final double? republicanPct;
  final double? democratPct;
  final List<dynamic> officials;
  final String? selectedCityId;
  final String? selectedCityName;
  final VoidCallback? onLayersTap;
  final String stateId;

  const TerritorySummaryCard({
    super.key,
    required this.title,
    this.subtitle,
    this.population,
    this.republicanPct,
    this.democratPct,
    required this.officials,
    this.selectedCityId,
    this.selectedCityName,
    this.onLayersTap,
    required this.stateId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50], // Initial grey background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Territory Header & Demographics
          // We can reuse/adapt the header style from the current sidebar if desired,
          // or just standard cleaner header.
          if (selectedCityId == null) ...[
            _buildTerritoryHeader(context),
            if (population != null) _buildDemographicsBar(),
          ],

          // 2. Selected City Highlight (if any)
          if (selectedCityId != null && selectedCityName != null) ...[
            _buildSelectedCityHeader(context),
          ],

          const Divider(height: 1),

          // 3. Officials List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: officials.length,
              separatorBuilder: (ctx, i) => const Divider(),
              itemBuilder: (context, index) {
                return _buildOfficialTile(context, officials[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerritoryHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
          if (population != null) ...[
            const SizedBox(height: 8),
            Text(
              "Population: $population",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDemographicsBar() {
    if (republicanPct == null || democratPct == null)
      return const SizedBox.shrink();

    // Normalize just in case
    // Assuming pct is 0.0 to 100.0 or 0.0 to 1.0?
    // In previous code it seemed to be percentage points (e.g. 82.0)

    return Container(
      height: 6,
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            flex: (democratPct! * 100)
                .toInt(), // Safety logic needed if totals != 100
            child: Container(color: Colors.blue),
          ),
          Expanded(
            flex: (republicanPct! * 100).toInt(),
            child: Container(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCityHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: Colors.blue.withOpacity(0.3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "SELECTED CITY",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            selectedCityName!,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialTile(BuildContext context, dynamic leader) {
    String role = "Officer";
    if (leader is Mayor) role = "Mayor";
    if (leader is Representative) role = "Representative";
    if (leader is Senator) role = "Senator";
    if (leader is Governor) role = "Governor";
    // if (leader is CountyJudge) role = "County Judge"; // If we have this type

    String name = "";
    String? party;
    String? photoPath;

    if (leader is Mayor) {
      name = leader.name;
      party = null; // Maybe show City name?
      photoPath = null;
    } else if (leader is Representative) {
      name = leader.name;
      party = leader.party;
      photoPath = leader.photoLocalPath;
    } else if (leader is Senator) {
      name = leader.name;
      party = leader.party;
      photoPath = leader.photoLocalPath;
    } else if (leader is Governor) {
      name = leader.name;
      party = leader.party;
      photoPath = leader.photoLocalPath;
      // } else if (leader is CountyJudge) {
      //   name = leader.name;
      // etc
    }

    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LawmakerDetailScreen(
              lawmaker: leader,
              role: role,
              stateId: stateId,
            ),
          ),
        );
      },
      leading: (leader is Mayor && leader.photoUrl != null)
          ? CircleAvatar(backgroundImage: NetworkImage(leader.photoUrl!))
          : (photoPath != null
                ? CircleAvatar(
                    backgroundImage: AssetImage('assets/img/$photoPath'),
                  )
                : const Icon(Icons.person)),
      title: Text(name),
      subtitle: Text("$role${party != null ? ' • $party' : ''}"),
    );
  }
}
