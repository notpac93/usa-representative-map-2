import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:usa_map_app/services/federal_officials_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> data;
  setUp(
    () => data = jsonDecode(
      File('assets/data/federal_officials.json').readAsStringSync(),
    ),
  );
  String publication(int seconds) {
    final next = jsonDecode(jsonEncode(data));
    next['publishedAt'] = DateTime.parse(
      data['publishedAt'],
    ).add(Duration(seconds: seconds)).toIso8601String();
    return jsonEncode(next);
  }

  test(
    'validated newer data is saved and a later outage preserves it',
    () async {
      var fail = false;
      String? cached;
      final service = FederalOfficialsService(
        automaticRefresh: false,
        remoteUrl: 'https://snapshot.example/federal.json',
        readCache: () async => null,
        writeCache: (value) async {
          cached = value;
        },
        client: MockClient((_) async {
          if (fail) throw Exception('offline');
          return http.Response(
            publication(1),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await service.load();
      final bundled = service.snapshot!.publishedAt;
      await service.refresh();
      expect(service.snapshot!.publishedAt.isAfter(bundled), isTrue);
      expect(cached, isNotNull);
      final verified = service.snapshot;
      fail = true;
      await service.refresh();
      expect(service.snapshot, same(verified));
      expect(service.refreshError, isNotNull);
      service.dispose();
    },
  );
  test('invalid cached data cannot replace the bundled snapshot', () async {
    final service = FederalOfficialsService(
      automaticRefresh: false,
      readCache: () async => 'corrupt cache',
      writeCache: (_) async {},
    );
    await service.load();
    expect(service.snapshot, isNotNull);
    expect(service.refreshError, isNull);
    service.dispose();
  });
  test(
    'older or invalid remote records never overwrite validated data',
    () async {
      String body = publication(-1);
      var writes = 0;
      final service = FederalOfficialsService(
        automaticRefresh: false,
        remoteUrl: 'https://snapshot.example/federal.json',
        readCache: () async => null,
        writeCache: (_) async {
          writes++;
        },
        client: MockClient(
          (_) async => http.Response(
            body,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await service.load();
      final original = service.snapshot;
      await service.refresh();
      expect(service.snapshot, same(original));
      body = '{"schemaVersion":99}';
      await service.refresh();
      expect(service.snapshot, same(original));
      expect(writes, 0);
      final future = jsonDecode(publication(1));
      future['publishedAt'] = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .toIso8601String();
      body = jsonEncode(future);
      await service.refresh();
      expect(service.snapshot, same(original));
      service.dispose();
    },
  );
  test('reopening offline uses the newer validated saved snapshot', () async {
    final service = FederalOfficialsService(
      automaticRefresh: false,
      readCache: () async => publication(1),
      writeCache: (_) async {},
    );
    await service.load();
    expect(
      service.snapshot!.publishedAt,
      DateTime.parse(data['publishedAt']).add(const Duration(seconds: 1)),
    );
    service.dispose();
  });
}
