// lib/providers/sale_image_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class SaleImageMeta {
  final int id;
  final int saleId;
  final String imageType;
  final String? description;
  final DateTime createdAt;

  SaleImageMeta({
    required this.id,
    required this.saleId,
    required this.imageType,
    this.description,
    required this.createdAt,
  });

  factory SaleImageMeta.fromJson(Map<String, dynamic> json) {
    return SaleImageMeta(
      id: json['id'] ?? 0,
      saleId: json['sale_id'] ?? 0,
      imageType: json['image_type'] ?? 'custom',
      description: json['description'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class SaleImageFull extends SaleImageMeta {
  final String imageData; // base64

  SaleImageFull({
    required super.id,
    required super.saleId,
    required super.imageType,
    super.description,
    required super.createdAt,
    required this.imageData,
  });

  factory SaleImageFull.fromJson(Map<String, dynamic> json) {
    return SaleImageFull(
      id: json['id'] ?? 0,
      saleId: json['sale_id'] ?? 0,
      imageType: json['image_type'] ?? 'custom',
      description: json['description'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      imageData: json['image_data'] ?? '',
    );
  }

  /// Decode base64 to raw bytes for Image.memory()
  List<int> get imageBytes {
    try {
      // Strip data-URI prefix if present (e.g. "data:image/png;base64,...")
      final data = imageData.contains(',') ? imageData.split(',').last : imageData;
      return base64Decode(data);
    } catch (_) {
      return [];
    }
  }
}

class SaleImageProvider with ChangeNotifier {
  // Cache: saleId -> list of image metadata
  final Map<int, List<SaleImageMeta>> _cache = {};
  final Map<int, bool> _loading = {};
  final Map<int, String?> _errors = {};

  List<SaleImageMeta> imagesFor(int saleId) => _cache[saleId] ?? [];
  bool isLoading(int saleId) => _loading[saleId] ?? false;
  String? errorFor(int saleId) => _errors[saleId];

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _imagesUrl(int saleId) => '${ApiConfig.salesUrl}/$saleId/images';
  String _imageUrl(int saleId, int imageId) =>
      '${ApiConfig.salesUrl}/$saleId/images/$imageId';

  // ── Fetch metadata list for a sale ──────────────────────────────────────
  Future<void> fetchImages(int saleId) async {
    _loading[saleId] = true;
    _errors[saleId] = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(_imagesUrl(saleId)),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _cache[saleId] = (json['data'] as List)
              .map((e) => SaleImageMeta.fromJson(e))
              .toList();
        } else {
          _errors[saleId] = json['message'];
        }
      } else {
        _errors[saleId] = 'Server error ${response.statusCode}';
      }
    } catch (e) {
      _errors[saleId] = 'Network error: $e';
    } finally {
      _loading[saleId] = false;
      notifyListeners();
    }
  }

  // ── Fetch single image with base64 data ─────────────────────────────────
  Future<SaleImageFull?> fetchImageData(int saleId, int imageId) async {
    try {
      final response = await http.get(
        Uri.parse(_imageUrl(saleId, imageId)),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          return SaleImageFull.fromJson(json['data']);
        }
      }
    } catch (e) {
      debugPrint('fetchImageData error: $e');
    }
    return null;
  }

  // ── Upload (create or replace) an image ─────────────────────────────────
  Future<Map<String, dynamic>> uploadImage({
    required int saleId,
    required String base64Data,
    required String imageType,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_imagesUrl(saleId)),
        headers: await _headers(),
        body: jsonEncode({
          'image_type': imageType,
          'image_data': base64Data,
          if (description != null && description.isNotEmpty)
            'description': description,
        }),
      );

      final json = jsonDecode(response.body);
      if (response.statusCode == 201 && json['success'] == true) {
        // Refresh cache
        await fetchImages(saleId);
        return {'success': true};
      }
      return {'success': false, 'message': json['message'] ?? 'Upload failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ── Delete an image ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> deleteImage(int saleId, int imageId) async {
    try {
      final response = await http.delete(
        Uri.parse(_imageUrl(saleId, imageId)),
        headers: await _headers(),
      );

      final json = jsonDecode(response.body);
      if (response.statusCode == 200 && json['success'] == true) {
        _cache[saleId]?.removeWhere((img) => img.id == imageId);
        notifyListeners();
        return {'success': true};
      }
      return {'success': false, 'message': json['message'] ?? 'Delete failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  void clearCache(int saleId) {
    _cache.remove(saleId);
    _loading.remove(saleId);
    _errors.remove(saleId);
    notifyListeners();
  }
}