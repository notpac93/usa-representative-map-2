import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'data/data_provider.dart';
import 'map/national_map_painter.dart';
import 'screens/state_detail_screen.dart';
import 'data/civic_data_provider.dart';
import 'screens/landing_screen.dart';
import 'screens/find_reps_screen.dart';
import 'widgets/civic_glass.dart';

void main() {
  // PORT CONFIGURATION: Always run on port 8080 to ensure consistency.
  // Command: flutter run -d web-server --web-port=8080 --web-hostname=localhost
  runApp(const UsaMapApp());
}

class UsaMapApp extends StatelessWidget {
  const UsaMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => MapDataProvider())],
      child: MaterialApp(
        title: 'USA Representative Map',
        theme: ThemeData(
          brightness: Brightness.light,
          primarySwatch: Colors.blueGrey,
          scaffoldBackgroundColor: const Color(0xFFF5F5F7), // Apple-like grey
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', 'US'),
          Locale('es', 'US'), // Spanish
          Locale('zh', 'CN'), // Chinese
        ],
        home: const LandingScreen(),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String? _selectedStateId;
  final TransformationController _transformController =
      TransformationController();

  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    // Trigger load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<MapDataProvider>();
      if (provider.atlas == null) provider.loadAllData();
      CivicDataProvider().loadData();
    });

    _transformController.addListener(() {
      final newZoom = _transformController.value.getMaxScaleOnAxis();
      if ((newZoom - _currentZoom).abs() > 0.05) {
        // Throttled redraw
        setState(() {
          _currentZoom = newZoom;
        });
      }
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _onMapTap(TapUpDetails details, double viewWidth, double viewHeight) {
    final provider = context.read<MapDataProvider>();
    if (provider.atlas == null || provider.pathCache == null) return;

    final atlas = provider.atlas!;
    final cache = provider.pathCache!;

    // Replicate Render Logic from Painter
    final scaleX = viewWidth / atlas.width;
    final scaleY = viewHeight / atlas.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final offsetX = (viewWidth - (atlas.width * scale)) / 2;
    final offsetY = (viewHeight - (atlas.height * scale)) / 2;

    // Inverse Transform: Screen -> Atlas
    final dx = (details.localPosition.dx - offsetX) / scale;
    final dy = (details.localPosition.dy - offsetY) / scale;

    for (var state in atlas.states) {
      final path = cache.getPath(state.id);
      if (path != null && path.contains(Offset(dx, dy))) {
        debugPrint("Tapped State: ${state.name} (${state.id})");
        _navigateToState(state.id);
        return;
      }
    }
  }

  void _navigateToState(String stateId) {
    setState(() => _selectedStateId = stateId);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (ctx) => StateDetailScreen(stateId: stateId),
          ),
        )
        .then((_) {
          if (mounted) setState(() => _selectedStateId = null);
        });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapDataProvider>();

    if (provider.isLoading && provider.atlas == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFDBE5F2),
        appBar: civicGlassAppBar('US States'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.atlas == null || provider.pathCache == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFDBE5F2),
        appBar: civicGlassAppBar('US States'),
        body: const Center(child: Text('Map data is unavailable. Please try again.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFDBE5F2),
      appBar: civicGlassAppBar(
        'US States',
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Find My Reps',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FindRepsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Reset map',
            onPressed: () => _transformController.value = Matrix4.identity(),
          ),
        ],
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 20.0,
                boundaryMargin: const EdgeInsets.all(
                  double.infinity,
                ), // Allow free pan
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTapUp: (details) {
                        _onMapTap(
                          details,
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                      },
                      child: Container(
                        // transparent container to catch hits
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        color: Colors.transparent,
                        child: CustomPaint(
                          painter: NationalMapPainter(
                            fillColor: const Color(0xFF456A99),
                            atlas: provider.atlas!,
                            pathCache: provider.pathCache!,
                            selectedStateId: _selectedStateId,
                            transformController: _transformController,
                            cities: provider.nationalCities ?? [],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
