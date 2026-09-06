import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'storage_service.dart';
import 'api_service.dart';

class ExtractedBillItem {
  int? productId;
  String productName;
  double quantity;
  double costPrice;
  double sellingPrice;
  double totalAmount;
  bool isNewProduct;
  int? categoryId;
  String unit;

  ExtractedBillItem({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.costPrice,
    required this.sellingPrice,
    required this.totalAmount,
    required this.isNewProduct,
    this.categoryId,
    this.unit = 'Piece',
  });

  factory ExtractedBillItem.fromJson(Map<String, dynamic> json) {
    return ExtractedBillItem(
      productId: json['productId'],
      productName: json['productName'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      costPrice: (json['costPrice'] ?? 0).toDouble(),
      sellingPrice: (json['sellingPrice'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      isNewProduct: json['isNewProduct'] ?? false,
      unit: json['unit']?.toString().isNotEmpty == true
          ? json['unit'].toString()
          : 'Piece',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'categoryId': categoryId,
      'unit': unit,
    };
  }
}

class BillUploadService {
  static Future<List<ExtractedBillItem>> extractBill(String filePath) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.extractBill}');
      final request = http.MultipartRequest('POST', uri);

      final token = await StorageService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await http.MultipartFile.fromPath('image', filePath));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        ApiService.onUnauthorized?.call();
        throw Exception('Session expired. Please log in again.');
      }

      dynamic body;
      try {
        if (response.body.isNotEmpty) {
          body = jsonDecode(response.body);
        }
      } catch (_) {}

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body != null &&
          body['success'] == true) {
        List<dynamic> dataList = body['data'];
        return dataList.map((e) => ExtractedBillItem.fromJson(e)).toList();
      } else {
        final message =
            (body != null && body is Map && body.containsKey('message'))
                ? body['message']
                : 'Failed to extract bill data (Status ${response.statusCode})';
        throw Exception(message);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> processBill(List<ExtractedBillItem> items) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.processBill}');
    final token = await StorageService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final payload = {
      'items': items.map((item) => item.toJson()).toList(),
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 401) {
      ApiService.onUnauthorized?.call();
      throw Exception('Session expired. Please log in again.');
    }

    dynamic body;
    try {
      if (response.body.isNotEmpty) {
        body = jsonDecode(response.body);
      }
    } catch (_) {}

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body != null &&
        body['success'] == true) {
      return;
    } else {
      final message =
          (body != null && body is Map && body.containsKey('message'))
              ? body['message']
              : 'Failed to process bill (Status ${response.statusCode})';
      throw Exception(message);
    }
  }
}
