import 'federal_snapshot_cache.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../data/federal_officials.dart';

/// Snapshots come from the publisher, never from election predictions on a device.
class FederalOfficialsService extends ChangeNotifier {
  static final instance = FederalOfficialsService();
  static const snapshotUrl = String.fromEnvironment('FEDERAL_SNAPSHOT_URL');
  final http.Client _client;
  final String remoteUrl;
  final bool automaticRefresh;
  final Future<String?> Function() readCache;
  final Future<void> Function(String) writeCache;
  FederalOfficialsService({
    http.Client? client,
    this.remoteUrl = snapshotUrl,
    this.automaticRefresh = true,
    Future<String?> Function()? readCache,
    Future<void> Function(String)? writeCache,
  }) : _client = client ?? http.Client(),
       readCache = readCache ?? readFederalCache,
       writeCache = writeCache ?? writeFederalCache;
  FederalSnapshot? snapshot;
  List<FederalSource> _sources = [];
  Future<void>? _loading;
  Timer? _timer;
  String? refreshError;

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      final registry = jsonDecode(
        await rootBundle.loadString('assets/data/federal_sources.json'),
      );
      _sources = (registry['sources'] as List)
          .map((x) => FederalSource.fromJson(Map<String, dynamic>.from(x)))
          .toList();
      snapshot = FederalSnapshot.decode(
        await rootBundle.loadString('assets/data/federal_officials.json'),
        _sources,
      );
      final cached = await readCache();
      if (cached != null) {
        try {
          final next = FederalSnapshot.decode(cached, _sources);
          if (next.publishedAt.isAfter(snapshot!.publishedAt) &&
              !next.publishedAt.isAfter(
                DateTime.now().toUtc().add(const Duration(minutes: 5)),
              )) {
            snapshot = next;
          }
        } catch (_) {
          /* Ignore invalid caches; use the validated bundled data. */
        }
      }
      notifyListeners();
      if (automaticRefresh) {
        unawaited(refresh());
        _timer ??= Timer.periodic(const Duration(minutes: 1), (timer) {
          notifyListeners(); // Re-evaluate visibility and verified expirations while offline.
          if (timer.tick % 5 == 0) unawaited(refresh());
        });
      }
    } catch (e) {
      refreshError = 'Federal records could not be loaded.';
      debugPrint('Federal data: $e');
      notifyListeners();
    }
  }

  Future<void>? _refreshTask;
  Future<void> refresh() =>
      _refreshTask ??= _refresh().whenComplete(() => _refreshTask = null);

  Future<void> _refresh() async {
    final uri = Uri.tryParse(remoteUrl);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) return;
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Invalid snapshot response');
      }
      final body = utf8.decode(response.bodyBytes);
      final next = FederalSnapshot.decode(body, _sources);
      if (next.publishedAt.isAfter(
        DateTime.now().toUtc().add(const Duration(minutes: 5)),
      )) {
        throw const FormatException('Future publication');
      }
      if (snapshot == null || next.publishedAt.isAfter(snapshot!.publishedAt)) {
        snapshot = next;
        await writeCache(body);
      }
      refreshError = null;
    } catch (_) {
      refreshError =
          'Update unavailable. Showing the last loaded official records.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    super.dispose();
  }
}
