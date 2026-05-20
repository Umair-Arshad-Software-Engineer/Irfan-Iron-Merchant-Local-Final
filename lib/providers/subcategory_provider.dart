// lib/providers/subcategory_provider.dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/category.dart';
import '../config/api_config.dart';

class SubcategoryProvider with ChangeNotifier {
  List<Subcategory> _subcategories = [];
  bool _isLoading = false;
  String _error = '';

  List<Subcategory> get subcategories => _subcategories;
  bool get isLoading => _isLoading;
  String get error => _error;

  Future<void> fetchSubcategoriesByCategory(int categoryId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/categories/$categoryId/subcategories'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _subcategories = (data['data'] as List)
              .map((sub) => Subcategory.fromJson(sub))
              .toList();
        } else {
          _error = data['message'] ?? 'Failed to load subcategories';
        }
      } else {
        _error = 'Failed to load subcategories: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSubcategories() {
    _subcategories.clear();
    notifyListeners();
  }
}