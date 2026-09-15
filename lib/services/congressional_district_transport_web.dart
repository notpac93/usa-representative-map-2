// The Census Geocoder does not support browser CORS. Its official API guide
// directs browser clients to use the callback + JSONP response mode.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

Future<({int statusCode, String body})> fetchCensusResponse(
  Uri uri,
  http.Client client,
) async {
  final callbackName =
      'censusGeocoder_${DateTime.now().microsecondsSinceEpoch}';
  final requestUri = uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      'format': 'jsonp',
      'callback': callbackName,
    },
  );
  final completer = Completer<({int statusCode, String body})>();
  final script = web.HTMLScriptElement()..src = requestUri.toString();
  Timer? timeout;

  void cleanup() {
    timeout?.cancel();
    script.remove();
    globalContext.delete(callbackName.toJS);
  }

  globalContext.setProperty(
    callbackName.toJS,
    ((JSAny? payload) {
      if (completer.isCompleted) return;
      final converted = payload?.dartify();
      completer.complete((statusCode: 200, body: jsonEncode(converted)));
      cleanup();
    }).toJS,
  );
  script.addEventListener(
    'error',
    ((web.Event _) {
      if (completer.isCompleted) return;
      completer.complete((statusCode: 503, body: 'Census JSONP failed'));
      cleanup();
    }).toJS,
  );
  timeout = Timer(const Duration(seconds: 15), () {
    if (completer.isCompleted) return;
    completer.complete((statusCode: 504, body: 'Census JSONP timed out'));
    cleanup();
  });
  web.document.head?.append(script);
  return completer.future;
}
