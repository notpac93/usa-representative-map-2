import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../data/models.dart';

/// Caches parsed Paths to avoid expensive re-parsing on every paint.
class AtlasPathCache {
  final Map<String, Path> _paths = {};

  Path? getPath(String stateId) => _paths[stateId];

  void parseAndCache(Atlas atlas) {
    if (_paths.isNotEmpty) return;
    for (var state in atlas.states) {
      _paths[state.id] = parseSvgPathData(state.path);
    }
  }

  Path? getPathById(String id) => _paths[id];

  void cachePath(String id, String svgPath) {
    if (_paths.containsKey(id)) return;
    _paths[id] = parseSvgPathData(svgPath);
  }
}
