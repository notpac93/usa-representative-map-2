import 'package:web/web.dart' as web;

Future<String?> readFederalCache() async {
  try {
    return web.window.localStorage.getItem('federal-officials-v1');
  } catch (_) {
    return null;
  }
}

Future<void> writeFederalCache(String value) async {
  try {
    web.window.localStorage.setItem('federal-officials-v1', value);
  } catch (_) {
    /* Keep the loaded snapshot if storage is full. */
  }
}
