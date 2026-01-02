import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/data_provider.dart';
import '../map/state_map_painter.dart';
import '../utils/map_transform.dart';
import 'package:path_drawing/path_drawing.dart';
import 'lawmaker_detail_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'section_detail_screen.dart'; // Correctly placed

class StateDetailScreen extends StatefulWidget {
  final String stateId;

  const StateDetailScreen({super.key, required this.stateId});

  @override
  State<StateDetailScreen> createState() => _StateDetailScreenState();
}

class _StateDetailScreenState extends State<StateDetailScreen> {
  bool _showCounties = true;
  bool _showDistricts = false;
  bool _showUrban = false;
  bool _showZcta = false;
  bool _showLakes = false;
  bool _showJudicial = false;

  // Selection
  List<SelectedFeature> _selectedFeatures = [];

  // Track zoom for invariant stroke width
  final TransformationController _transformController =
      TransformationController();
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onZoomChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onZoomChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onZoomChanged() {
    // scale is usually m[0] or m[5] in diagonal matrix
    final newZoom = _transformController.value.getMaxScaleOnAxis();
    if (newZoom != _currentZoom) {
      setState(() {
        _currentZoom = newZoom;
      });
    }
  }

  void _clearAllLayers() {
    setState(() {
      _showCounties = false;
      _showDistricts = false;
      _showUrban = false;
      _showZcta = false;
      _showLakes = false;
      _showJudicial = false;
      _selectedFeatures = [];
    });
  }

  void _handleTap(
    TapUpDetails details,
    Size mapSize,
    StateRecord stateRecord,
    MapDataProvider provider,
  ) {
    if (provider.pathCache == null) return;

    // 1. Calculate Transform
    final transform = MapTransform.calculateFit(stateRecord.bbox, mapSize);

    // 2. Convert Tap to Data Coordinate
    final dataPoint = transform.screenToData(details.localPosition);

    // 3. Check Intersections (Active Layers Only)
    final newSelection = <SelectedFeature>[];

    void checkLayer(List<OverlayFeature>? features, String typeLabel) {
      if (features == null) return;
      for (var f in features) {
        // Fast BBox check
        if (dataPoint.dx < f.bbox[0] ||
            dataPoint.dx > f.bbox[2] ||
            dataPoint.dy < f.bbox[1] ||
            dataPoint.dy > f.bbox[3]) {
          continue;
        }

        // Precise Path check
        var path = provider.pathCache!.getPathById(f.id);
        if (path == null) {
          try {
            path = parseSvgPathData(f.path);
            provider.pathCache!.cachePath(f.id, f.path);
          } catch (e) {
            continue;
          }
        }

        if (path.contains(dataPoint)) {
          var rawName = f.name;
          if (rawName.toLowerCase().startsWith("feature")) {
            rawName = rawName.substring(7).trim();
            if (rawName.startsWith(":") || rawName.startsWith("-")) {
              rawName = rawName.substring(1).trim();
            }
          }
          final displayName = "$typeLabel - $rawName";

          CountyDemographics? demo;
          if (typeLabel == "County") {
            demo = provider.countyDemo?[f.id];
          } else if (typeLabel == "District") {
            demo = provider.districtDemo?[f.id];
          }

          newSelection.add(SelectedFeature(f, displayName, demographics: demo));
        }
      }
    }

    if (_showCounties) checkLayer(provider.counties, "County");
    if (_showDistricts) checkLayer(provider.cd116, "District");
    if (_showUrban) checkLayer(provider.urbanAreas, "Urban");
    if (_showZcta) checkLayer(provider.zcta, "Zip");
    if (_showLakes) checkLayer(provider.lakes, "Lake");
    if (_showJudicial) checkLayer(provider.judicial, "Judicial");

    setState(() {
      if (newSelection.isNotEmpty) {
        final firstNew = newSelection.first;
        // Check if already selected -> Toggle Off
        bool alreadySelected = _selectedFeatures.any(
          (sf) => sf.feature.id == firstNew.feature.id,
        );
        if (alreadySelected) {
          _selectedFeatures = [];
        } else {
          _selectedFeatures = [firstNew]; // Select new
        }
      } else {
        _selectedFeatures = []; // Deselect if clicking empty space
      }
    });
  }

  // Helper to filter leaders based on selection
  List<dynamic> _getFilteredLeaders(
    SelectedFeature selection,
    MapDataProvider provider,
  ) {
    final stateId = widget.stateId;
    final allMayors = provider.mayors?[stateId] ?? [];
    final allReps = (provider.houseMembers?[stateId] as List?) ?? [];
    final allSenators = (provider.senators?[stateId] as List?) ?? [];
    final governor = provider.governors?[stateId];

    List<dynamic> filtered = [];

    // Spatial / Text Logic

    // 1. Mayors: Check if City Lat/Lon is inside Feature Path
    final featurePath = provider.pathCache?.getPathById(selection.feature.id);
    if (featurePath != null) {
      for (var mayor in allMayors) {
        // Mayor city is often "Austin, TX". We need "Austin".
        var mName = mayor.city.toLowerCase();
        if (mName.contains(',')) {
          mName = mName.split(',')[0].trim();
        }

        // Normalize mayor city and find matching feature
        final cityFeat = provider.cities?[stateId]?.firstWhere(
          (c) {
            final cName = c.name.toLowerCase();
            // Check for exact match first (after stripping state from mayor)
            if (cName == mName) return true;

            // Census often has " city", " "town", " village" suffixes
            // We strip them from the feature name to compare with mayor's city name
            var normalizedCName = cName;
            for (final suffix in [
              " city",
              " town",
              " village",
              " borough",
              " cdp",
            ]) {
              if (normalizedCName.endsWith(suffix)) {
                normalizedCName = normalizedCName
                    .substring(0, normalizedCName.length - suffix.length)
                    .trim();
              }
            }

            return normalizedCName == mName;
          },
          orElse: () =>
              CityFeature(id: '', name: '', x: 0, y: 0, lon: 0, lat: 0),
        );

        if (cityFeat != null && cityFeat.x != 0) {
          final pt = Offset(cityFeat.x, cityFeat.y);
          // Check bounds first (optimization and sanity check)
          if (featurePath.getBounds().contains(pt)) {
            if (featurePath.contains(pt)) {
              filtered.add(mayor);
            }
          }
        }
      }
    }

    // 2. Reps: Check if District matches (District 1 vs 1st)
    // Also, if selecting a County, we might want to show Reps if we could map them.
    // For now, only District selection maps to Reps well.
    if (selection.displayName.startsWith("District")) {
      for (var rep in allReps) {
        // Basic string match: "District 2" vs "2nd"
        // Let's normalize digits.
        final featureDigits = selection.displayName.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );
        final repDigits = (rep.district ?? "").replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );

        if (featureDigits.isNotEmpty && featureDigits == repDigits) {
          filtered.add(rep);
        }
      }
    }

    // 3. Senators & Governor always relevant
    filtered.addAll(allSenators);
    if (governor != null) filtered.add(governor);

    return filtered;
  }

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

    // 1. Gather all leaders
    final governorData = provider.governors?[widget.stateId];
    final senatorsList = (provider.senators?[widget.stateId] as List?) ?? [];
    final houseList = (provider.houseMembers?[widget.stateId] as List?) ?? [];
    final mayorList = provider.mayors?[widget.stateId] ?? [];

    // 2. Filter Logic for Selected Section
    List<dynamic> specificSectionLeaders = [];
    if (_selectedFeatures.isNotEmpty) {
      specificSectionLeaders = _getFilteredLeaders(
        _selectedFeatures.first,
        provider,
      );
    }

    // 2. Sort/Filter logic
    List<dynamic> displayLeaders = [];
    bool isSelectionActive = _selectedFeatures.isNotEmpty;

    if (isSelectionActive) {
      // Logic for "Specific Section"
      // user wants: Mayor -> House Rep -> Senator -> Governor

      // Filter primarily by intersection if possible, but for now we might just show relevant ones?
      // "Most local leader" implies if I click a City, I see Mayor.
      // If I click a County, I see Reps/Senators/Governor?
      // Since specific geographic filtering is complex without point-in-poly for every leader,
      // we will implement the SORTING hierarchy first.

      // TODO: Actual intersection filtering if we had lat/lon for every leader.
      // For now, we will include ALL state leaders but sorted by hierarchy.

      // Rank: Mayor(1), Rep(2), Senator(3), Governor(4)

      var sorted = <dynamic>[];
      sorted.addAll(mayorList);
      sorted.addAll(houseList);
      sorted.addAll(senatorsList);
      if (governorData != null) sorted.add(governorData);

      // Need real filtering to be useful, but user asking for "Sorting".
      // We'll simulate "Relevant" by just showing all for now, but sorted bottom-up.
      // (Improving this would require lat/lon for every leader).

      displayLeaders = sorted;
    } else {
      // Default Hierarchy: Governor -> Senator -> Rep -> Mayor
      if (governorData != null) displayLeaders.add(governorData);
      displayLeaders.addAll(senatorsList);
      displayLeaders.addAll(houseList);
      displayLeaders.addAll(mayorList);
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(), // 1. Back Button on Left
        title: Text(stateRecord.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: SvgPicture.asset(
              'assets/img/logo.svg',
              width: 32,
              height: 32,
            ),
          ),
        ],
      ),

      body: Row(
        children: [
          // Left: Map
          Expanded(
            flex: 2,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 1.0,
                      maxScale: 20.0,
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.white,
                        child: GestureDetector(
                          onTapUp: (details) => _handleTap(
                            details,
                            constraints.biggest,
                            stateRecord,
                            provider,
                          ),
                          child: CustomPaint(
                            painter: StateMapPainter(
                              stateRecord: stateRecord,
                              atlas: atlas,
                              pathCache: pathCache,
                              zoomLevel: _currentZoom,
                              cities: provider.cities?[widget.stateId] ?? [],
                              counties: provider.counties,
                              cd116: provider.cd116,
                              urbanAreas: provider.urbanAreas,
                              showCounties: _showCounties,
                              showDistricts: _showDistricts,
                              showUrban: _showUrban,
                              zcta: provider.zcta,
                              lakes: provider.lakes,
                              judicial: provider.judicial,
                              showZcta: _showZcta,
                              showLakes: _showLakes,
                              showJudicial: _showJudicial,
                              selectedFeatures: _selectedFeatures
                                  .map((sf) => sf.feature)
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Map Controls Overlays (Keep existing)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_showCounties ||
                              _showDistricts ||
                              _showUrban ||
                              _selectedFeatures.isNotEmpty) ...[
                            OutlinedButton(
                              onPressed: _clearAllLayers,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.9),
                                side: const BorderSide(color: Colors.red),
                                foregroundColor: Colors.red,
                              ),
                              child: const Text("CLEAR"),
                            ),
                            const SizedBox(width: 8),
                          ],
                          FloatingActionButton.small(
                            heroTag: "layers_fab",
                            onPressed: () => _showLayersModal(context),
                            child: const Icon(Icons.layers),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Right: Info Panel
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[50],
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. SPECIFIC FILTERED SECTION (If Selected)
                  if (_selectedFeatures.isNotEmpty) ...[
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SectionDetailScreen(
                                      selectedFeature: _selectedFeatures.first,
                                      stateId: widget.stateId,
                                      stateRecord: stateRecord,
                                      sortedLeaders: specificSectionLeaders,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.05),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _selectedFeatures
                                                    .first
                                                    .displayName,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue[900],
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                "Tap for more info >",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_selectedFeatures
                                                .first
                                                .demographics
                                                ?.republican !=
                                            null)
                                          _buildPartySplitBar(
                                            context,
                                            _selectedFeatures
                                                .first
                                                .demographics!,
                                          ),
                                      ],
                                    ),
                                    if (_selectedFeatures.first.demographics !=
                                        null) ...[
                                      const SizedBox(height: 12),
                                      if (_selectedFeatures
                                              .first
                                              .demographics!
                                              .population !=
                                          null)
                                        Text(
                                          "Population: ${_selectedFeatures.first.demographics!.population}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      if (_selectedFeatures
                                              .first
                                              .demographics!
                                              .description !=
                                          null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _selectedFeatures
                                              .first
                                              .demographics!
                                              .description!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            // Filtered Leaders List
                            if (specificSectionLeaders.isNotEmpty)
                              ...specificSectionLeaders
                                  .take(10)
                                  .map(
                                    (l) => _buildLeaderTile(
                                      context,
                                      l,
                                      widget.stateId,
                                    ),
                                  ),

                            if (specificSectionLeaders.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  "No specific local leaders found for this section.",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 32, thickness: 1),
                    Text(
                      "State Leadership",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. FULL CATEGORIZED LIST (Pushed Down)
                  Text(
                    "Governor",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (governorData != null)
                    Card(
                      child: _buildLeaderTile(
                        context,
                        governorData,
                        widget.stateId,
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text("No Governor Data"),
                    ),

                  const SizedBox(height: 16),
                  const Divider(),
                  Text(
                    "Senators",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ...senatorsList.map(
                    (s) => _buildLeaderTile(context, s, widget.stateId),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  Text(
                    "Representatives (${houseList.length})",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ...houseList.map(
                    (r) => _buildLeaderTile(context, r, widget.stateId),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  Text(
                    "Mayors (${mayorList.length})",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ...mayorList.map(
                    (m) => _buildLeaderTile(context, m, widget.stateId),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartySplitBar(BuildContext context, CountyDemographics demo) {
    if (demo.republican == null || demo.democrat == null)
      return const SizedBox.shrink();

    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "D ${demo.democrat!}%",
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "R ${demo.republican!}%",
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.red],
                  ),
                ),
              ),
              // Indicator Dot
              Positioned(
                left:
                    (demo.democrat! / (demo.democrat! + demo.republican!)) *
                        120 -
                    3,
                top: -1,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderTile(
    BuildContext context,
    dynamic leader,
    String stateId,
  ) {
    String role = "Officer";
    String name = "";
    String? party;
    String? photoPath;
    String? photoUrl;
    String? subtitle;

    if (leader is Mayor) {
      role = "Mayor";
      name = leader.name;
      subtitle = leader.city;
      photoUrl = leader.photoUrl;
    } else if (leader is Representative) {
      role = "Representative";
      name = leader.name;
      party = leader.party;
      photoPath = leader.photoLocalPath;
      subtitle = "District ${leader.district}";
    } else if (leader is Senator) {
      role = "Senator";
      name = leader.name;
      party = leader.party;
      photoPath = leader.photoLocalPath;
    } else if (leader is Governor) {
      role = "Governor";
      name = leader.name;
      party = leader.party;
      photoPath = leader.photoLocalPath;
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
      leading: photoUrl != null
          ? CircleAvatar(
              backgroundImage: NetworkImage(photoUrl),
              onBackgroundImageError: (_, __) => const Icon(Icons.person),
            )
          : (photoPath != null
                ? CircleAvatar(
                    backgroundImage: AssetImage('assets/img/$photoPath'),
                  )
                : const Icon(Icons.person)),
      title: Text(name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (role == "Representative" ||
              role == "Mayor" ||
              role == "Governor" ||
              role == "Senator")
            Text(
              role,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.blue,
              ),
            ),
          if (subtitle != null) Text(subtitle),
          if (party != null) Text(party),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Map Layers",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () {
                          _clearAllLayers();
                          setModalState(() {}); // Force local modal rebuild
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text("CLEAR"),
                      ),
                    ],
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
                  SwitchListTile(
                    title: const Text("Show Judicial Districts"),
                    value: _showJudicial,
                    onChanged: (val) {
                      setState(() => _showJudicial = val);
                      setModalState(() {});
                    },
                    secondary: const Icon(Icons.gavel, color: Colors.brown),
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
