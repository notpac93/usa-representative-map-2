import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/congressional_roster.dart';

class LandingPortrait {
  const LandingPortrait(this.id, this.name, this.asset);
  final String id, name, asset;
}

/// Decoration only: these members are not the user's matched delegation.
class LandingPortraitService {
  static const preferenceKey = 'landing.lastPortraitIds.v1';
  static List<String> _sessionIds = [];

  Future<List<LandingPortrait>> loadPool() async {
    final roster = await CongressionalRoster.load();
    final assets = (await AssetManifest.loadFromAssetBundle(
      rootBundle,
    )).listAssets().toSet();
    final pool = <String, LandingPortrait>{};
    void add(String? id, String name, String? path) {
      if (id == null || path == null) return;
      final asset = path.startsWith('assets/') ? path : 'assets/img/$path';
      if (assets.contains(asset)) pool[id] = LandingPortrait(id, name, asset);
    }

    for (final member in roster.houseMembers.values.expand((v) => v)) {
      add(member.bioguideId, member.name, member.photoLocalPath);
    }
    for (final member in roster.senators.values.expand((v) => v)) {
      add(member.bioguideId, member.name, member.photoLocalPath);
    }
    return pool.values.toList();
  }

  Future<List<String>> readPrevious() async {
    try {
      return (await SharedPreferences.getInstance()).getStringList(
            preferenceKey,
          ) ??
          _sessionIds;
    } catch (_) {
      return _sessionIds;
    }
  }

  Future<void> remember(List<LandingPortrait> portraits) async {
    _sessionIds = portraits.map((p) => p.id).toList();
    try {
      await (await SharedPreferences.getInstance()).setStringList(
        preferenceKey,
        _sessionIds,
      );
    } catch (_) {
      // Storage unavailability must not prevent the home screen opening.
    }
  }

  /// Prefer an entirely different trio, not just a different order.
  static List<LandingPortrait> choose(
    List<LandingPortrait> pool,
    List<String> previous, {
    Random? random,
    int count = 3,
  }) {
    final rng = random ?? Random();
    final unique = {for (final p in pool) p.id: p}.values.toList();
    final fresh = unique.where((p) => !previous.contains(p.id)).toList()
      ..shuffle(rng);
    final remaining = unique.where((p) => previous.contains(p.id)).toList()
      ..shuffle(rng);
    return [...fresh, ...remaining].take(count).toList();
  }
}
