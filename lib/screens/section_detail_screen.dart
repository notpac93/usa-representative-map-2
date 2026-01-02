import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:path_drawing/path_drawing.dart';
import '../data/models.dart';
import '../data/data_provider.dart';
import '../map/feature_focus_painter.dart';
import '../map/place_map_painter.dart'; // New painter
import '../utils/map_transform.dart';
import '../utils/official_hierarchy.dart';
import '../widgets/territory_summary_card.dart';

class SectionDetailScreen extends StatefulWidget {
  final SelectedFeature selectedFeature; // Identify the section
  final String stateId;
  final StateRecord stateRecord; // Passed from StateDetail, contains FIPS/ID
  final List<dynamic> sortedLeaders;

  const SectionDetailScreen({
    super.key,
    required this.selectedFeature,
    required this.stateId,
    required this.stateRecord,
    required this.sortedLeaders,
  });

  @override
  State<SectionDetailScreen> createState() => _SectionDetailScreenState();
}

class _SectionDetailScreenState extends State<SectionDetailScreen> {
  List<PlaceFeature> _places = [];
  List<PlaceFeature> _backgroundPlaces = [];
  List<dynamic> _countyMayors = []; // Added
  bool _isLoadingPlaces = true;
  bool _showCities = true;

  String? _selectedCityId; // Track selected city

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  void _showLayersModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Map Layers",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text("Cities & Towns"),
                    subtitle: const Text("Show municipal boundaries"),
                    value: _showCities,
                    activeColor: Colors.blue,
                    secondary: const Icon(Icons.location_city),
                    onChanged: (val) {
                      setModalState(() => _showCities = val);
                      this.setState(() => _showCities = val);
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
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

  Future<void> _loadPlaces() async {
    final provider = Provider.of<MapDataProvider>(context, listen: false);

    // Get FIPS from record or fallback mapping
    final fips = widget.stateRecord.fips.isNotEmpty
        ? widget.stateRecord.fips
        : _stateFips[widget.stateId.toUpperCase()] ?? '';

    if (fips.isNotEmpty) {
      final loadedPlaces = await provider.loadPlacesForState(fips);

      if (mounted) {
        setState(() {
          // Filter by BBox intersection
          final countyBbox = widget.selectedFeature.feature.bbox;
          final allIntersecting = loadedPlaces.where((place) {
            final placeBbox = place.bbox;
            // Check intersection:
            // A.minX < B.maxX && A.maxX > B.minX &&
            // A.minY < B.maxY && A.maxY > B.minY
            return placeBbox[0] < countyBbox[2] &&
                placeBbox[2] > countyBbox[0] &&
                placeBbox[1] < countyBbox[3] &&
                placeBbox[3] > countyBbox[1];
          }).toList();

          _places = [];
          _backgroundPlaces = [];

          for (var place in allIntersecting) {
            // Filter by LSAD:
            // 25 = City, 43 = Town, 47 = Village, 21 = Borough
            const validLsads = ['25', '43', '47', '21'];

            final hasValidLsad = validLsads.contains(place.lsad);
            final hasValidName =
                place.lsad.isEmpty &&
                (place.name.toLowerCase().endsWith(' city') ||
                    place.name.toLowerCase().endsWith(' town') ||
                    place.name.toLowerCase().endsWith(' village') ||
                    place.name.toLowerCase().endsWith(' borough'));

            if (hasValidLsad || hasValidName) {
              _places.add(place);
            } else {
              _backgroundPlaces.add(place);
            }
          }

          // Fetch all relevant mayors for these places
          _countyMayors = provider.getMayorsForPlaces(widget.stateId, _places);

          _isLoadingPlaces = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingPlaces = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
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
        title: Text(widget.selectedFeature.displayName),
      ),
      body: Row(
        children: [
          // Left: Map Focus
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Transform to fit the selected feature
                  final transform = MapTransform.calculateFit(
                    widget.selectedFeature.feature.bbox,
                    Size(constraints.maxWidth, constraints.maxHeight),
                  );

                  return Stack(
                    children: [
                      InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 20.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        clipBehavior: Clip.none,
                        child: GestureDetector(
                          onTapUp: (details) {
                            final dataPoint = transform.screenToData(
                              details.localPosition,
                            );

                            if (!_showCities) return;
                            if (_places.isEmpty) return;

                            try {
                              final tappedPlace = _places.firstWhere((p) {
                                if (p.path.isEmpty) return false;
                                final path = parseSvgPathData(p.path);
                                return path.contains(dataPoint);
                              });

                              setState(() {
                                if (_selectedCityId == tappedPlace.id) {
                                  _selectedCityId = null;
                                } else {
                                  _selectedCityId = tappedPlace.id;
                                }
                              });
                            } catch (e) {
                              if (_selectedCityId != null) {
                                setState(() => _selectedCityId = null);
                              }
                            }
                          },
                          child: Stack(
                            children: [
                              // Base Layer
                              RepaintBoundary(
                                child: CustomPaint(
                                  size: Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  ),
                                  painter: FeatureFocusPainter(
                                    feature: widget.selectedFeature.feature,
                                    transform: transform,
                                  ),
                                ),
                              ),

                              // City Layer
                              if (_showCities && !_isLoadingPlaces)
                                RepaintBoundary(
                                  child: CustomPaint(
                                    size: Size(
                                      constraints.maxWidth,
                                      constraints.maxHeight,
                                    ),
                                    painter: PlaceMapPainter(
                                      places: _places,
                                      backgroundPlaces: _backgroundPlaces,
                                      transform: transform,
                                      highlightedPlaceId: _selectedCityId,
                                      clipPath: parseSvgPathData(
                                        widget.selectedFeature.feature.path,
                                      ),
                                    ),
                                  ),
                                ),

                              if (_isLoadingPlaces)
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Map Controls Overlays
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton.small(
                              heroTag: "layers_fab_county",
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
          ),
          // Right: Leadership List
          Expanded(
            flex: 1,
            child: Container(
              child: TerritorySummaryCard(
                stateId: widget.stateId,
                title: widget.selectedFeature.displayName,
                subtitle: "Located in the US.", // Or state name if available
                population: widget.selectedFeature.demographics?.population,
                republicanPct: widget.selectedFeature.demographics?.republican,
                democratPct: widget.selectedFeature.demographics?.democrat,
                officials: OfficialHierarchy.sortOfficials(
                  () {
                    final combined = [
                      ...widget.sortedLeaders,
                      ..._countyMayors,
                    ];
                    final unique = <String, dynamic>{};
                    for (var official in combined) {
                      // Create a unique key
                      String key = "";
                      if (official is Mayor) {
                        key = "mayor_${official.name}_${official.city}";
                      } else if (official is Representative) {
                        key = "rep_${official.name}_${official.district}";
                      } else if (official is Senator) {
                        key = "sen_${official.name}";
                      } else if (official is Governor) {
                        key = "gov_${official.name}";
                      } else {
                        key = official.toString();
                      }
                      unique[key] = official;
                    }
                    return unique.values.toList();
                  }(),
                  prioritizeWhere: _selectedCityId != null
                      ? (official) {
                          if (official is! Mayor) return false;
                          // Get the selected city name
                          final selectedCity = _places.firstWhere(
                            (p) => p.id == _selectedCityId,
                            orElse: () => PlaceFeature(
                              id: '',
                              name: '',
                              path: '',
                              lsad: '',
                              stateFips: '',
                              bbox: const [0, 0, 0, 0],
                            ),
                          );

                          // Normalize both names for comparison
                          var cityName = selectedCity.name.toLowerCase();
                          for (final suffix in [
                            " city",
                            " town",
                            " village",
                            " borough",
                          ]) {
                            if (cityName.endsWith(suffix)) {
                              cityName = cityName
                                  .substring(0, cityName.length - suffix.length)
                                  .trim();
                              break;
                            }
                          }

                          var mayorCity = official.city.toLowerCase();
                          if (mayorCity.contains(',')) {
                            mayorCity = mayorCity.split(',')[0].trim();
                          }

                          return mayorCity == cityName;
                        }
                      : null,
                ),
                selectedCityId: _selectedCityId,
                selectedCityName: _selectedCityId != null
                    ? _places
                          .firstWhere(
                            (p) => p.id == _selectedCityId,
                            orElse: () => PlaceFeature(
                              id: '',
                              name: 'Unknown',
                              path: '',
                              lsad: '',
                              stateFips: '',
                              bbox: const [0, 0, 0, 0],
                            ),
                          )
                          .name
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
