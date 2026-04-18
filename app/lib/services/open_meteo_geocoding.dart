import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/saved_location.dart';

/// [Geocoding API](https://open-meteo.com/en/docs/geocoding-api)
class OpenMeteoGeocoding {
  OpenMeteoGeocoding({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _base = 'https://geocoding-api.open-meteo.com/v1/search';

  Future<List<GeocodingHit>> search(String query, {int count = 8}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final uri = Uri.parse(_base).replace(queryParameters: {
      'name': q,
      'count': count.toString(),
      'language': 'en',
      'format': 'json',
    });

    final res = await _http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw Exception('Geocoding HTTP ${res.statusCode}');
    }

    final map = json.decode(res.body) as Map<String, dynamic>;
    final results = map['results'] as List<dynamic>?;
    if (results == null) return [];

    return results.map((e) => GeocodingHit.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class GeocodingHit {
  GeocodingHit({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.countryCode,
    this.admin1,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? countryCode;
  final String? admin1;

  factory GeocodingHit.fromJson(Map<String, dynamic> json) {
    return GeocodingHit(
      name: json['name'] as String? ?? 'Unknown',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      countryCode: json['country_code'] as String?,
      admin1: json['admin1'] as String?,
    );
  }

  SavedLocation toSavedLocation(String id) {
    return SavedLocation(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      countryCode: countryCode,
      admin1: admin1,
    );
  }
}
