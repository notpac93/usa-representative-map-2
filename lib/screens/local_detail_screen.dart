import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/data_provider.dart';
import '../utils/search_handler.dart';
import '../data/models.dart';
import '../data/civic_data_provider.dart';
import 'bill_detail_screen.dart';
import 'lawmaker_detail_screen.dart';

class LocalDetailScreen extends StatelessWidget {
  final SearchResult searchResult;

  const LocalDetailScreen({super.key, required this.searchResult});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapDataProvider>();

    // Extract state
    StateRecord? stateRecord;
    if (searchResult.stateId != null && provider.atlas != null) {
      try {
        stateRecord = provider.atlas!.states.firstWhere(
          (s) => s.id == searchResult.stateId,
        );
      } catch (e) {
        // Not found
      }
    }

    // Extract Governor
    Governor? governor;
    if (searchResult.stateId != null && provider.governors != null) {
      governor = provider.governors![searchResult.stateId!];
    }

    // Extract Senators
    List<Senator> senators = [];
    if (searchResult.stateId != null && provider.senators != null) {
      senators = provider.senators![searchResult.stateId!] ?? [];
    }

    // Extract Mayor(s)
    List<Mayor> localMayors = [];
    if (searchResult.cityName != null &&
        searchResult.stateId != null &&
        provider.mayors != null) {
      final stateMayors = provider.mayors![searchResult.stateId!] ?? [];
      localMayors = stateMayors
          .where(
            (m) => m.city.toLowerCase() == searchResult.cityName!.toLowerCase(),
          )
          .toList();
    }

    // Extract County Demographics
    CountyDemographics? demographics;
    if (searchResult.featureId != null && provider.countyDemo != null) {
      demographics = provider.countyDemo![searchResult.featureId];
    } else if (searchResult.countyName != null && provider.counties != null) {
      // Find feature by name
      try {
        final countyFeature = provider.counties!.firstWhere(
          (f) => f.name.toLowerCase() == searchResult.countyName!.toLowerCase(),
        );
        demographics = provider.countyDemo?[countyFeature.id];
      } catch (e) {
        // Not found
      }
    }

    // Extract Representatives (House Members)
    // If we only have county, it might span multiple districts. We will show all for the state for now,
    // or filter by the county's bounding box if we could, but simpler to show state reps or note they vary by district.
    List<Representative> houseMembers = [];
    if (searchResult.stateId != null && provider.houseMembers != null) {
      houseMembers = provider.houseMembers![searchResult.stateId!] ?? [];
      // Ideally we'd filter to the specific district, but zip/city can span multiple.
    }

    final isAddress = searchResult.type == SearchResultType.address || searchResult.streetAddress != null;
    final isZip = searchResult.type == SearchResultType.zipCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(searchResult.title),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAddress ? Icons.home : isZip ? Icons.mark_as_unread : Icons.location_on,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAddress
                            ? 'YOUR HOME ADDRESS'
                            : isZip
                                ? 'YOUR HOME ZIP CODE'
                                : 'YOUR LOCAL JURISDICTION',
                        style: const TextStyle(
                          color: Color(0xFFFDE047),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        searchResult.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your Elected Local, State & Federal Officials',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Text(
            searchResult.subtitle,
            style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          const Divider(),

          if (localMayors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Local Mayor', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (var mayor in localMayors)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE2E8F0),
                    child: Icon(Icons.person, color: Color(0xFF1E3A8A)),
                  ),
                  title: Text(mayor.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Mayor of ${mayor.city}'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.blueGrey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LawmakerDetailScreen(
                          lawmaker: mayor,
                          role: "Mayor",
                          stateId: searchResult.stateId ?? 'US',
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],

          if (governor != null) ...[
            const SizedBox(height: 12),
            Text('State Governor', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE2E8F0),
                  backgroundImage: governor.photoLocalPath != null
                      ? AssetImage('assets/img/${governor.photoLocalPath}')
                      : null,
                  child: governor.photoLocalPath == null
                      ? const Icon(Icons.person, color: Color(0xFF1E3A8A))
                      : null,
                ),
                title: Text(governor.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Governor of ${searchResult.stateId} (${governor.party ?? "State Executive"})'),
                trailing: const Icon(Icons.chevron_right, color: Colors.blueGrey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LawmakerDetailScreen(
                        lawmaker: governor,
                        role: "Governor",
                        stateId: searchResult.stateId ?? 'US',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          if (senators.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('U.S. Senators (Federal)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (var senator in senators)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE2E8F0),
                    backgroundImage: senator.photoLocalPath != null
                        ? AssetImage('assets/img/${senator.photoLocalPath}')
                        : null,
                    child: senator.photoLocalPath == null
                        ? const Icon(Icons.person, color: Color(0xFF1E3A8A))
                        : null,
                  ),
                  title: Text(senator.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('U.S. Senator (${senator.party ?? "Senator"}) • ${searchResult.stateId}'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.blueGrey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LawmakerDetailScreen(
                          lawmaker: senator,
                          role: "Senator",
                          stateId: searchResult.stateId ?? 'US',
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],

          if (demographics != null) ...[
            const SizedBox(height: 16),
            Text(
              'County Demographics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (demographics.population != null)
                      Text('Total Population: ${demographics.population}'),
                    if (demographics.republican != null)
                      Text(
                        'Republican vote share: ${(demographics.republican! * 100).toStringAsFixed(1)}%',
                      ),
                    if (demographics.democrat != null)
                      Text(
                        'Democrat vote share: ${(demographics.democrat! * 100).toStringAsFixed(1)}%',
                      ),
                    if (demographics.description != null)
                      Text('${demographics.description}'),
                  ],
                ),
              ),
            ),
          ],

          if (houseMembers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'State Representatives (House)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Note: A city or county may span multiple congressional districts.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            // Just show a count or list them. Listing all might be long for big states, but it's an option.
            Text(
              'There are ${houseMembers.length} representatives in ${searchResult.stateId}. Use the map to find your specific district.',
            ),
          ],
          
          if (searchResult.stateId != null) ...[
            const SizedBox(height: 24),
            Text(
              "Local & State Legislation",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder(
              future: CivicDataProvider().loadData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final bills = CivicDataProvider().getBillsForState(searchResult.stateId!);
                if (bills.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text("No relevant bills found for this jurisdiction."),
                  );
                }
                return Column(
                  children: bills.map((b) => Card(
                    child: ListTile(
                      title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Status: ${b.status}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BillDetailScreen(bill: b),
                          ),
                        );
                      },
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
