import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';
import 'storage_service.dart';

class ApiService {
  static void Function()? onUnauthorized;

  static dynamic _safeJsonDecode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, String>> _getHeaders({bool isJson = true}) async {
    final token = await StorageService.getToken();
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParameters}) async {
    Uri uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    if (queryParameters != null) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    final headers = await _getHeaders();
    final response = await http.get(uri, headers: headers);
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

  static Future<dynamic> post(String endpoint, dynamic data) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders();
    final response =
        await http.post(uri, headers: headers, body: jsonEncode(data));
    return _processResponse(response);
  }

  static Future<dynamic> put(String endpoint, dynamic data) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders();
    final response =
        await http.put(uri, headers: headers, body: jsonEncode(data));
    return _processResponse(response);
  }

  static Future<dynamic> patch(String endpoint, dynamic data) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders();
    final response =
        await http.patch(uri, headers: headers, body: jsonEncode(data));
    return _processResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders();
    final response = await http.delete(uri, headers: headers);
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
            ? value.map((message) => message.toString()).where((message) => message.isNotEmpty)
            : [value?.toString() ?? ''];
        final joined = messages.where((message) => message.isNotEmpty).join(', ');
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
