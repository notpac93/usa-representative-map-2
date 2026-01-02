import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/data_provider.dart';
import 'map/national_map_painter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'screens/state_detail_screen.dart';

void main() {
  // PORT CONFIGURATION: Always run on port 8080 to ensure consistency.
  // Command: flutter run -d web-server --web-port=8080 --web-hostname=localhost
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => MapDataProvider())],
      child: const UsaMapApp(),
    ),
  );
}

class UsaMapApp extends StatelessWidget {
  const UsaMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USA Representative Map',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7), // Apple-like grey
      ),
      home: const MapScreen(),
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

  @override
  void initState() {
    super.initState();
    // Trigger load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MapDataProvider>().loadAllData();
    });
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
          setState(() => _selectedStateId = null);
        });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapDataProvider>();

    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (provider.atlas == null) {
      return const Scaffold(
        body: Center(child: Text("Failed to load map data.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Ensure no back button/drawer icon
        title: const Text("USA Representative Map"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: SvgPicture.asset(
              'assets/img/logo.svg',
              width: 32,
              height: 32,
            ),
          ),
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
        ],
      ),
      body: LayoutBuilder(
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
                        atlas: provider.atlas!,
                        pathCache: provider.pathCache!,
                        selectedStateId: _selectedStateId,
                        zoomLevel: 1.0,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
