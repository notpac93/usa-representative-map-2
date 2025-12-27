import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/data_provider.dart';
import '../map/state_map_painter.dart';
import 'lawmaker_detail_screen.dart';

class StateDetailScreen extends StatefulWidget {
  final String stateId;

  const StateDetailScreen({super.key, required this.stateId});

  @override
  State<StateDetailScreen> createState() => _StateDetailScreenState();
}

class _StateDetailScreenState extends State<StateDetailScreen> {
  bool _showCounties = false;
  bool _showDistricts = false;
  bool _showUrban = false;
  bool _showZcta = false;
  bool _showLakes = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapDataProvider>();
    final atlas = provider.atlas;
    final pathCache = provider.pathCache;

    if (atlas == null || pathCache == null) {
      return const Scaffold(body: Center(child: Text("Data not loaded")));
    }

    final stateRecord = atlas.states.cast<StateRecord?>().firstWhere(
      (s) => s!.id == widget.stateId,
      orElse: () => null,
    );

    if (stateRecord == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(child: Text("State ${widget.stateId} not found")),
      );
    }

    // Retrieve Data
    final governorData = provider.governors?[widget.stateId];
    final senatorsList = (provider.senators?[widget.stateId] as List?) ?? [];
    final houseList = (provider.houseMembers?[widget.stateId] as List?) ?? [];
    final cityList = provider.cities?[widget.stateId] ?? [];

    // Retrieve Overlays (National Lists)
    final counties = provider.counties;
    final cd116 = provider.cd116;
    final urbanAreas = provider.urbanAreas;

    return Scaffold(
      appBar: AppBar(title: Text(stateRecord.name)),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showLayersModal(context);
        },
        child: const Icon(Icons.layers),
        tooltip: "Map Layers",
      ),
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
                        counties: counties,
                        cd116: cd116,
                        urbanAreas: urbanAreas,
                        showCounties: _showCounties,
                        showDistricts: _showDistricts,
                        showUrban: _showUrban,
                        zcta: provider.zcta,
                        lakes: provider.lakes,
                        showZcta: _showZcta,
                        showLakes: _showLakes,
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LawmakerDetailScreen(
                                lawmaker: governorData,
                                role: "Governor",
                              ),
                            ),
                          );
                        },
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LawmakerDetailScreen(
                              lawmaker: sen,
                              role: "Senator",
                            ),
                          ),
                        );
                      },
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LawmakerDetailScreen(
                              lawmaker: rep,
                              role: "Representative",
                            ),
                          ),
                        );
                      },
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

  void _showLayersModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Map Layers",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text("Show Counties"),
                    value: _showCounties,
                    onChanged: (val) {
                      setState(() => _showCounties = val);
                      setModalState(() {});
                    },
                    secondary: const Icon(Icons.grid_on, color: Colors.grey),
                  ),
                  SwitchListTile(
                    title: const Text("Show Congressional Districts"),
                    value: _showDistricts,
                    onChanged: (val) {
                      setState(() => _showDistricts = val);
                      setModalState(() {});
                    },
                    secondary: const Icon(
                      Icons.people_outline,
                      color: Colors.purple,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text("Show Urban Areas"),
                    value: _showUrban,
                    onChanged: (val) {
                      setState(() => _showUrban = val);
                      setModalState(() {});
                    },
                    secondary: const Icon(
                      Icons.location_city,
                      color: Colors.orange,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text("Show Zip Codes"),
                    value: _showZcta,
                    onChanged: (val) {
                      setState(() => _showZcta = val);
                      setModalState(() {});
                    },
                    secondary: const Icon(
                      Icons.markunread_mailbox,
                      color: Colors.green,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text("Show Lakes"),
                    value: _showLakes,
                    onChanged: (val) {
                      setState(() => _showLakes = val);
                      setModalState(() {});
                    },
                    secondary: const Icon(Icons.water, color: Colors.blue),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
