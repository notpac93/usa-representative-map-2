import 'package:http/http.dart' as http;

Future<({int statusCode, String body})> fetchCensusResponse(
  Uri uri,
  http.Client client,
) async {
  final response = await client.get(uri);
  return (statusCode: response.statusCode, body: response.body);
}
