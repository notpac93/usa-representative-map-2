import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> readFederalCache() async {
  try {
    final folder = await getApplicationSupportDirectory();
    final file = File('${folder.path}/federal-officials-v1.json');
    return await file.exists() ? await file.readAsString() : null;
  } catch (_) {
    return null;
  }
}

Future<void> writeFederalCache(String value) async {
  try {
    final folder = await getApplicationSupportDirectory();
    await folder.create(recursive: true);
    final path = '${folder.path}/federal-officials-v1.json';
    await File('$path.tmp').writeAsString(value, flush: true);
    await File('$path.tmp').rename(path);
  } catch (_) {
    /* A storage failure must not discard the loaded snapshot. */
  }
}
