import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';
import 'storage_service.dart';

class ApiService {
  static void Function()? onUnauthorized;
  static Future<bool>? _refreshInProgress;

  static dynamic _safeJsonDecode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, String>> _getHeaders({
    bool isJson = true,
    bool includeAuthorization = true,
  }) async {
    final token = await StorageService.getToken();
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (includeAuthorization && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<bool> refreshAccessToken() {
    final pending = _refreshInProgress;
    if (pending != null) return pending;
    final refresh = _refreshAccessToken();
    _refreshInProgress = refresh;
    return refresh.whenComplete(() => _refreshInProgress = null);
  }

  static Future<bool> _refreshAccessToken() async {
    final refreshToken = await StorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    final response = await http.post(
      Uri.parse(ApiConfig.baseUrl + ApiConfig.refresh),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    final body = _safeJsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body is! Map ||
        body['success'] != true ||
        body['data'] is! Map) {
      return false;
    }
    final data = Map<String, dynamic>.from(body['data'] as Map);
    final token = data['token']?.toString();
    final replacement = data['refreshToken']?.toString();
    if (token == null ||
        token.isEmpty ||
        replacement == null ||
        replacement.isEmpty) return false;
    await StorageService.updateTokens(token: token, refreshToken: replacement);
    return true;
  }

  static Future<http.Response> _send(
    Future<http.Response> Function() request, {
    bool retryOnUnauthorized = true,
  }) async {
    var response = await request();
    if (retryOnUnauthorized &&
        response.statusCode == 401 &&
        await refreshAccessToken()) {
      response = await request();
    }
    return response;
  }

  static Future<void> revokeRefreshToken() async {
    final refreshToken = await StorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return;
    try {
      await http.post(
        Uri.parse(ApiConfig.baseUrl + ApiConfig.logout),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
    } catch (_) {
      // Local credentials are still removed when the device is offline.
    }
  }

  static Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParameters}) async {
    Uri uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    if (queryParameters != null) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    final response = await _send(() async => http.get(
          uri,
          headers: await _getHeaders(),
        ));
    return _processResponse(response);
  }

  /// Downloads a non-JSON response while applying the same authentication
  /// headers as the rest of the API calls.
  static Future<Uint8List> getBytes(String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(isJson: false);
    headers['Accept'] = 'application/pdf';
    final response = await http.get(uri, headers: headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to download file (HTTP ${response.statusCode})');
    }

    return response.bodyBytes;
  }

  static Future<dynamic> post(
    String endpoint,
    dynamic data, {
    bool includeAuthorization = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await _send(
      () async => http.post(
        uri,
        headers: await _getHeaders(includeAuthorization: includeAuthorization),
        body: jsonEncode(data),
      ),
      retryOnUnauthorized: includeAuthorization,
    );
    return _processResponse(response);
  }

  static Future<dynamic> put(String endpoint, dynamic data) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await _send(() async => http.put(
          uri,
          headers: await _getHeaders(),
          body: jsonEncode(data),
        ));
    return _processResponse(response);
  }

  static Future<dynamic> patch(String endpoint, dynamic data) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await _send(() async => http.patch(
          uri,
          headers: await _getHeaders(),
          body: jsonEncode(data),
        ));
    return _processResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await _send(() async => http.delete(
          uri,
          headers: await _getHeaders(),
        ));
    return _processResponse(response);
  }

  static Future<String?> uploadImage(XFile imageFile) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.uploadImage}');
      final request = http.MultipartRequest('POST', uri);

      final token = await StorageService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          await imageFile.readAsBytes(),
          filename: _uploadFilename(imageFile, fallback: 'image.jpg'),
        ),
      );
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        onUnauthorized?.call();
        throw Exception('Session expired. Please log in again.');
      }

      final data = _safeJsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data != null &&
          data['success'] == true) {
        return data['data']['url'] as String?;
      } else {
        final message =
            (data != null && data is Map && data.containsKey('message'))
                ? data['message']
                : 'Failed to upload image (Status ${response.statusCode})';
        throw Exception(message);
      }
    } catch (e) {
      rethrow;
    }
  }

  static String _uploadFilename(XFile imageFile, {required String fallback}) {
    final explicitName = imageFile.name.trim();
    if (explicitName.isNotEmpty) {
      return explicitName;
    }

    final path = imageFile.path.trim();
    if (path.isEmpty) {
      return fallback;
    }

    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    final candidate = parts.isEmpty ? '' : parts.last.trim();
    return candidate.isEmpty ? fallback : candidate;
  }

  static dynamic _processResponse(http.Response response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw Exception('Session expired. Please log in again.');
    }

    final body = _safeJsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body ?? response.body;
    } else {
      throw Exception(_errorMessage(body, response.statusCode));
    }
  }

  /// ASP.NET validation responses use `errors` rather than the app's usual
  /// `message` property. Preserve those details so a 400 points to the input
  /// that needs attention instead of appearing as an unexplained failure.
  static String _errorMessage(dynamic body, int statusCode) {
    if (body is! Map) return 'An error occurred (Status $statusCode)';
    final map = Map<String, dynamic>.from(body);
    final errors = map['errors'];
    if (errors is Map) {
      final details = <String>[];
      for (final entry in errors.entries) {
        final value = entry.value;
        final messages = value is List
            ? value
                .map((message) => message.toString())
                .where((message) => message.isNotEmpty)
            : [value?.toString() ?? ''];
        final joined =
            messages.where((message) => message.isNotEmpty).join(', ');
        if (joined.isNotEmpty) details.add('${entry.key}: $joined');
      }
      if (details.isNotEmpty) return details.join('\n');
    }
    for (final key in const ['message', 'detail', 'title']) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return 'An error occurred (Status $statusCode)';
  }
}
