import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/app_settings.dart';
import '../models/saved_location.dart';

const _kSettings = 'app_settings_v1';
const _kLocations = 'saved_locations_v1';
const _kFavourite = 'favourite_location_id_v1';

class AppState extends ChangeNotifier {
  AppState._();

  static final AppState instance = AppState._();

  final _uuid = const Uuid();

  AppSettings settings = AppSettings.defaults;
  List<SavedLocation> locations = [];
  String? favouriteLocationId;

  SavedLocation get effectiveLocation {
    if (favouriteLocationId != null) {
      final f = locations.where((l) => l.id == favouriteLocationId).toList();
      if (f.isNotEmpty) return f.first;
    }
    return SavedLocation(
      id: 'default',
      name: 'London',
      latitude: AppConfig.defaultLatitude,
      longitude: AppConfig.defaultLongitude,
      countryCode: 'GB',
      admin1: 'England',
    );
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kSettings);
    if (s != null) {
      try {
        settings = AppSettings.fromJson(json.decode(s) as Map<String, dynamic>);
      } catch (_) {}
    }
    final locJson = prefs.getString(_kLocations);
    if (locJson != null) {
      try {
        final list = json.decode(locJson) as List<dynamic>;
        locations = list
            .map((e) => SavedLocation.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    favouriteLocationId = prefs.getString(_kFavourite);
    notifyListeners();
  }

  Future<void> setSettings(AppSettings value) async {
    settings = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettings, json.encode(value.toJson()));
  }

  /// Replace local state from cloud sync (still persisted locally).
  Future<void> replaceFromCloud({
    required AppSettings newSettings,
    required List<SavedLocation> newLocations,
    String? favouriteId,
  }) async {
    settings = newSettings;
    locations = newLocations;
    favouriteLocationId = favouriteId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettings, json.encode(settings.toJson()));
    await prefs.setString(
      _kLocations,
      json.encode(locations.map((e) => e.toJson()).toList()),
    );
    if (favouriteId == null) {
      await prefs.remove(_kFavourite);
    } else {
      await prefs.setString(_kFavourite, favouriteId);
    }
  }

  Future<void> addLocation(SavedLocation loc) async {
    locations = [...locations, loc];
    notifyListeners();
    await _persistLocations();
  }

  Future<void> removeLocation(String id) async {
    locations = locations.where((l) => l.id != id).toList();
    if (favouriteLocationId == id) {
      favouriteLocationId = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kFavourite);
    }
    notifyListeners();
    await _persistLocations();
  }

  Future<void> setFavourite(String? id) async {
    favouriteLocationId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_kFavourite);
    } else {
      await prefs.setString(_kFavourite, id);
    }
  }

  Future<void> _persistLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kLocations,
      json.encode(locations.map((e) => e.toJson()).toList()),
    );
  }

  String newId() => _uuid.v4();
}
