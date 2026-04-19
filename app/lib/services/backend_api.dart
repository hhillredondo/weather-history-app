import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/aws_config.dart';
import '../models/app_settings.dart';
import '../models/saved_location.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';

/// Authenticated calls to the HTTP API (Lambda).
class BackendApi {
  BackendApi(this._auth);

  final AuthState _auth;

  Uri _uri(String path) {
    final base = AwsConfig.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = _auth.accessToken;
    if (token == null) throw Exception('Not signed in');
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<http.Response> _get(String path) async {
    var res = await http.get(_uri(path), headers: await _authHeaders());
    if (res.statusCode == 401) {
      if (await _auth.refreshAccessToken()) {
        res = await http.get(_uri(path), headers: await _authHeaders());
      }
    }
    return res;
  }

  Future<http.Response> _put(String path, String body) async {
    var res = await http.put(
      _uri(path),
      headers: await _authHeaders(),
      body: body,
    );
    if (res.statusCode == 401) {
      if (await _auth.refreshAccessToken()) {
        res = await http.put(
          _uri(path),
          headers: await _authHeaders(),
          body: body,
        );
      }
    }
    return res;
  }

  Future<http.Response> _delete(String path) async {
    var res = await http.delete(_uri(path), headers: await _authHeaders());
    if (res.statusCode == 401) {
      if (await _auth.refreshAccessToken()) {
        res = await http.delete(_uri(path), headers: await _authHeaders());
      }
    }
    return res;
  }

  Future<http.Response> _post(String path, String body) async {
    var res = await http.post(
      _uri(path),
      headers: await _authHeaders(),
      body: body,
    );
    if (res.statusCode == 401) {
      if (await _auth.refreshAccessToken()) {
        res = await http.post(
          _uri(path),
          headers: await _authHeaders(),
          body: body,
        );
      }
    }
    return res;
  }

  void _throwIfBad(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  /// Download settings, locations, favourite from API into [app].
  Future<void> pullIntoApp(AppState app) async {
    final res = await _get('/v1/settings');
    _throwIfBad(res);
    final map = json.decode(res.body) as Map<String, dynamic>;
    final raw = map['settings'];
    final s = raw is Map<String, dynamic>
        ? AppSettings.fromJson(raw)
        : AppSettings.defaults;

    final locRes = await _get('/v1/locations');
    _throwIfBad(locRes);
    final locMap = json.decode(locRes.body) as Map<String, dynamic>;
    final list = locMap['locations'] as List<dynamic>? ?? [];
    final locs = list
        .map((e) => SavedLocation.fromJson(e as Map<String, dynamic>))
        .toList();

    final prof = await _get('/v1/profile');
    _throwIfBad(prof);
    final p = json.decode(prof.body) as Map<String, dynamic>;
    final fav = p['favouriteLocationId'] as String?;

    await app.replaceFromCloud(
      newSettings: s,
      newLocations: locs,
      favouriteId: fav,
    );
  }

  Future<void> upsertLocation(SavedLocation loc) async {
    final res = await _post('/v1/locations', json.encode(loc.toJson()));
    _throwIfBad(res);
  }

  Future<void> putFavourite(String? favouriteId) async {
    final res = await _put(
      '/v1/locations/favourite',
      json.encode({'favouriteId': favouriteId}),
    );
    _throwIfBad(res);
  }

  Future<void> putSettings(AppSettings settings) async {
    final res = await _put(
      '/v1/settings',
      json.encode(settings.toJson()),
    );
    _throwIfBad(res);
  }

  Future<void> deleteLocation(String id) async {
    final encoded = Uri.encodeComponent(id);
    final res = await _delete('/v1/locations/$encoded');
    _throwIfBad(res);
  }

  /// Upload local app state to the API.
  Future<void> pushAll(AppState app) async {
    final res = await _put(
      '/v1/settings',
      json.encode(app.settings.toJson()),
    );
    _throwIfBad(res);
    for (final loc in app.locations) {
      final r = await _post('/v1/locations', json.encode(loc.toJson()));
      _throwIfBad(r);
    }
    final fav = await _put(
      '/v1/locations/favourite',
      json.encode({'favouriteId': app.favouriteLocationId}),
    );
    _throwIfBad(fav);
  }
}
