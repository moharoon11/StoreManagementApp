import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'storage_service.dart';

class ApiService {
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

  static Future<dynamic> get(String endpoint, {Map<String, String>? queryParameters}) async {
    Uri uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    if (queryParameters != null) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    final headers = await _getHeaders();
    final response = await http.get(uri, headers: headers);
    return _processResponse(response);
  }

  static Future<dynamic> post(String endpoint, dynamic data) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders();
    final response = await http.post(uri, headers: headers, body: jsonEncode(data));
    return _processResponse(response);
  }

  static Future<dynamic> put(String endpoint, dynamic data) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders();
    final response = await http.put(uri, headers: headers, body: jsonEncode(data));
    return _processResponse(response);
  }

  static Future<dynamic> patch(String endpoint, dynamic data) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders();
    final response = await http.patch(uri, headers: headers, body: jsonEncode(data));
    return _processResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders();
    final response = await http.delete(uri, headers: headers);
    return _processResponse(response);
  }

  static Future<String?> uploadImage(String filePath) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.uploadImage}');
      final request = http.MultipartRequest('POST', uri);
      
      final token = await StorageService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
        return data['data']['url'] as String?;
      } else {
        throw Exception(data['message'] ?? 'Failed to upload image');
      }
    } catch (e) {
      rethrow;
    }
  }

  static dynamic _processResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      final message = body['message'] ?? 'An error occurred (Status ${response.statusCode})';
      throw Exception(message);
    }
  }
}
