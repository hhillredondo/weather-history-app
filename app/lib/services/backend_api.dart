import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/aws_config.dart';
import '../models/chat_message.dart';
import '../models/saved_location.dart';
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

  Future<http.Response> _getUri(Uri uri) async {
    var res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode == 401) {
      if (await _auth.refreshAccessToken()) {
        res = await http.get(uri, headers: await _authHeaders());
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

  /// Historical weather (Lambda → Open-Meteo, DynamoDB TTL cache). Response: `{ cached, data }`.
  Future<Map<String, dynamic>> getWeatherArchive({
    required double latitude,
    required double longitude,
    required String startDate,
    required String endDate,
    bool hourly = false,
    String timezone = 'auto',
  }) async {
    final uri = _uri('/v1/weather/archive').replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'start_date': startDate,
      'end_date': endDate,
      'timezone': timezone,
      if (hourly) 'hourly': '1',
    });
    final res = await _getUri(uri);
    _throwIfBad(res);
    return json.decode(res.body) as Map<String, dynamic>;
  }

  /// POST /v1/chat — sends a single user turn plus rolling history.
  /// Optional [location] gives the model a default lat/lon to use when the
  /// user doesn't name a place explicitly.
  Future<ChatReply> postChat({
    required String message,
    required List<ChatMessage> history,
    SavedLocation? location,
  }) async {
    final body = {
      'message': message,
      'history': history.map((m) => m.toWireJson()).toList(),
      if (location != null)
        'location': {
          'name': location.name,
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
    };
    final res = await _post('/v1/chat', json.encode(body));
    _throwIfBad(res);
    return ChatReply.fromJson(json.decode(res.body) as Map<String, dynamic>);
  }
}
