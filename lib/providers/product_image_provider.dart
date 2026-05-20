// lib/providers/product_image_provider.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Add this for MediaType
import '../config/api_config.dart';
import '../models/product_image_model.dart';

class ProductImageProvider with ChangeNotifier {
  List<ProductImage> _images = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ProductImage> get images => _images;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get primary image for a product
  ProductImage? getPrimaryImage(int productId) {
    try {
      return _images.firstWhere(
            (img) => img.productId == productId && img.isPrimary,
      );
    } catch (e) {
      return null;
    }
  }

  // Get all images for a product
  List<ProductImage> getImagesForProduct(int productId) {
    return _images.where((img) => img.productId == productId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  // Fetch images for a product
  Future<void> fetchProductImages(int productId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/products/$productId/images'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> imagesData = responseData['data'];
          _images = imagesData.map((json) => ProductImage.fromJson(json)).toList();
        }
      } else {
        _errorMessage = 'Failed to load images';
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Upload images for a product
  Future<Map<String, dynamic>> uploadImages(int productId, List<File> imageFiles) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/products/$productId/images'),
      );

      // Log the files being uploaded for debugging
      print('Uploading ${imageFiles.length} files');

      for (var i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];

        // Check if file exists
        if (!await file.exists()) {
          print('File does not exist: ${file.path}');
          continue;
        }

        // Get file info for debugging
        final fileStat = await file.stat();
        print('File ${i + 1}:');
        print('  Path: ${file.path}');
        print('  Size: ${fileStat.size} bytes');
        print('  Extension: ${file.path.split('.').last}');

        // Ensure we're using the correct field name 'images' (match backend)
        request.files.add(
          await http.MultipartFile.fromPath(
            'images', // Must match backend field name
            file.path,
            filename: 'product_${productId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
            contentType: MediaType('image', 'jpeg'), // Explicitly set content type
          ),
        );
      }

      if (request.files.isEmpty) {
        return {'success': false, 'error': 'No valid files to upload'};
      }

      print('Sending request with ${request.files.length} files');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          await fetchProductImages(productId);
          return {'success': true, 'data': responseData['data']};
        } else {
          return {'success': false, 'error': responseData['message'] ?? 'Unknown error'};
        }
      } else {
        return {
          'success': false,
          'error': 'Failed to upload images (Status: ${response.statusCode})'
        };
      }
    } catch (e) {
      print('Upload error: $e');
      return {'success': false, 'error': e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set primary image
  Future<Map<String, dynamic>> setPrimaryImage(int imageId) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/product-images/$imageId/set-primary'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Refresh images for the product
          final image = _images.firstWhere((img) => img.id == imageId);
          await fetchProductImages(image.productId);
          return {'success': true};
        } else {
          return {'success': false, 'error': responseData['message']};
        }
      } else {
        return {'success': false, 'error': 'Failed to set primary image'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Delete image
  Future<Map<String, dynamic>> deleteImage(int imageId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/product-images/$imageId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          _images.removeWhere((img) => img.id == imageId);
          notifyListeners();
          return {'success': true};
        } else {
          return {'success': false, 'error': responseData['message']};
        }
      } else {
        return {'success': false, 'error': 'Failed to delete image'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Reorder images
  Future<Map<String, dynamic>> reorderImages(int productId, List<int> imageIds) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/products/$productId/images/reorder'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'image_ids': imageIds}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          await fetchProductImages(productId);
          return {'success': true};
        } else {
          return {'success': false, 'error': responseData['message']};
        }
      } else {
        return {'success': false, 'error': 'Failed to reorder images'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  void clearImages() {
    _images = [];
    notifyListeners();
  }
}