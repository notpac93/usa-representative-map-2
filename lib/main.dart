import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'data/data_provider.dart';
import 'screens/landing_screen.dart';

export 'screens/national_map_screen.dart' show MapScreen;

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
