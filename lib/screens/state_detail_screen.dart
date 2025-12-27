import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/data_provider.dart';
import '../map/state_map_painter.dart';

class StateDetailScreen extends StatelessWidget {
  final String stateId;

  const StateDetailScreen({super.key, required this.stateId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapDataProvider>();
    final atlas = provider.atlas;
    final pathCache = provider.pathCache;

    if (atlas == null || pathCache == null) {
      return const Scaffold(body: Center(child: Text("Data not loaded")));
    }

    final stateRecord = atlas.states.cast<StateRecord?>().firstWhere(
      (s) => s!.id == stateId,
      orElse: () => null,
    );

    if (stateRecord == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(child: Text("State $stateId not found")),
      );
    }

    // Retrieve Data
    final governorData = provider.governors?[stateId];
    final senatorsList = (provider.senators?[stateId] as List?) ?? [];
    final houseList = (provider.houseMembers?[stateId] as List?) ?? [];
    final cityList = provider.cities?[stateId] ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(stateRecord.name)),
      body: Row(
        children: [
          // Left: Map
          Expanded(
            flex: 2,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 10.0,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity, // Fill layout
                    color: Colors.white,
                    child: CustomPaint(
                      painter: StateMapPainter(
                        stateRecord: stateRecord,
                        atlas: atlas,
                        pathCache: pathCache,
                        zoomLevel: 1.0,
                        cities: cityList,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Right: Info Panel
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  Text(
                    "Governor",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (governorData != null) ...[
                    Card(
                      child: ListTile(
                        leading: governorData.photoLocalPath != null
                            ? CircleAvatar(
                                backgroundImage: AssetImage(
                                  'assets/img/${governorData.photoLocalPath}',
                                ),
                              )
                            : const Icon(Icons.person),
                        title: Text(governorData.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(governorData.party ?? ""),
                            if (governorData.phone != null)
                              Text(
                                governorData.phone!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    const Text("No Governor Data"),

                  const Divider(),
                  Text(
                    "Senators",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...senatorsList.map(
                    (sen) => ListTile(
                      leading: sen.photoLocalPath != null
                          ? CircleAvatar(
                              backgroundImage: AssetImage(
                                'assets/img/${sen.photoLocalPath}',
                              ),
                            )
                          : const Icon(Icons.person),
                      title: Text(sen.name),
                      subtitle: Text(sen.party ?? ""),
                      dense: true,
                    ),
                  ),

                  const Divider(),
                  Text(
                    "Representatives (${houseList.length})",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...houseList.map(
                    (rep) => ListTile(
                      leading: rep.photoLocalPath != null
                          ? CircleAvatar(
                              backgroundImage: AssetImage(
                                'assets/img/${rep.photoLocalPath}',
                              ),
                            )
                          : const Icon(Icons.person),
                      title: Text(rep.name),
                      subtitle: Text("District ${rep.district} • ${rep.party}"),
                      dense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
