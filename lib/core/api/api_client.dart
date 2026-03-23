import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Central HTTP client for the Echelon Finance backend API.
/// Auth uses a JWT stored in secure storage; falls back to PERSONAL_TOKEN
/// for the backend URL only (not for API auth — that requires login).
class ApiClient {
  final http.Client _http;
  final FlutterSecureStorage _storage;

  static const _baseUrlKey = 'backend_base_url';
  static const _tokenKey = 'backend_token';
  static const _jwtKey = 'auth_jwt';

  ApiClient({http.Client? httpClient, FlutterSecureStorage? storage})
      : _http = httpClient ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  // ─── Backend URL config ───────────────────────────────────────────────────

  Future<String?> getBaseUrl() => _storage.read(key: _baseUrlKey);
  Future<void> saveBaseUrl(String url) => _storage.write(
      key: _baseUrlKey,
      value: url.trimRight().replaceAll(RegExp(r'/$'), ''));

  // Legacy token (shown in Settings, kept for backward compat)
  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token.trim());

  // ─── JWT auth ─────────────────────────────────────────────────────────────

  Future<String?> getJwt() => _storage.read(key: _jwtKey);
  Future<void> saveJwt(String token) =>
      _storage.write(key: _jwtKey, value: token);
  Future<void> clearJwt() => _storage.delete(key: _jwtKey);

  /// True when the user is logged in (JWT present).
  Future<bool> isConfigured() async {
    final jwt = await getJwt();
    return jwt != null && jwt.isNotEmpty;
  }

  // ─── HTTP helpers ─────────────────────────────────────────────────────────

  Future<Map<String, String>> _headers() async {
    // Prefer JWT; fall back to stored PERSONAL_TOKEN for legacy installs
    final jwt = await getJwt();
    final stored = await getToken();
    final token = (jwt != null && jwt.isNotEmpty)
        ? jwt
        : (stored != null && stored.isNotEmpty)
            ? stored
            : AppConstants.defaultBackendToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> _noAuthHeaders() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<String> _base() async {
    final stored = await getBaseUrl();
    return (stored != null && stored.isNotEmpty)
        ? stored
        : AppConstants.defaultBackendUrl;
  }

  // ─── Authenticated requests ───────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final base = await _base();
    var uri = Uri.parse('$base$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final res = await _http
        .get(uri, headers: await _headers())
        .timeout(AppConstants.apiTimeout);
    return _parse(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final base = await _base();
    final res = await _http
        .post(
          Uri.parse('$base$path'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(AppConstants.apiTimeout);
    return _parse(res);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final base = await _base();
    final res = await _http
        .put(
          Uri.parse('$base$path'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(AppConstants.apiTimeout);
    return _parse(res);
  }

  Future<void> delete(String path) async {
    final base = await _base();
    final res = await _http
        .delete(Uri.parse('$base$path'), headers: await _headers())
        .timeout(AppConstants.apiTimeout);
    if (res.statusCode >= 400) _parse(res);
  }

  // ─── Unauthenticated requests (login / register) ──────────────────────────

  Future<dynamic> postNoAuth(String path, Map<String, dynamic> body) async {
    final base = await _base();
    final res = await _http
        .post(
          Uri.parse('$base$path'),
          headers: _noAuthHeaders(),
          body: jsonEncode(body),
        )
        .timeout(AppConstants.apiTimeout);
    return _parse(res);
  }

  // ─── Response parser ──────────────────────────────────────────────────────

  dynamic _parse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      message = body['message'] ?? body['error'] ?? message;
    } catch (_) {}
    throw ApiException(message, statusCode: res.statusCode);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
