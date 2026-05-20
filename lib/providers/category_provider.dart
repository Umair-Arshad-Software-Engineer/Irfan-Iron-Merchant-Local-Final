import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/category.dart';
import '../config/api_config.dart';

class CategoryProvider with ChangeNotifier {
  List<Category> _categories = [];
  List<Category> _filteredCategories = [];
  bool _isLoading = false;
  String _error = '';

  List<Category> get categories => _filteredCategories;
  bool get isLoading => _isLoading;
  String get error => _error;

  Future<void> loadCategories() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/categories'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _categories = (data['data'] as List)
              .map((category) => Category.fromJson(category))
              .toList();
          _filteredCategories = List.from(_categories);
        } else {
          _error = data['message'] ?? 'Failed to load categories';
        }
      } else {
        _error = 'Failed to load categories: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createCategory(String name) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/categories'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      );

      final data = json.decode(response.body);

      if (data['success']) {
        final category = Category.fromJson(data['data']);
        _categories.insert(0, category);
        _filteredCategories = List.from(_categories);
        notifyListeners();
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateCategory(String id, String name) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/categories/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      );

      final data = json.decode(response.body);

      if (data['success']) {
        final index = _categories.indexWhere((cat) => cat.id == id);
        if (index != -1) {
          _categories[index] = Category.fromJson(data['data']);
          _filteredCategories = List.from(_categories);
          notifyListeners();
        }
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteCategory(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/categories/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(response.body);

      if (data['success']) {
        _categories.removeWhere((cat) => cat.id == id);
        _filteredCategories = List.from(_categories);
        notifyListeners();
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createSubcategory(String categoryId, String name) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/categories/$categoryId/subcategories'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'category_id': categoryId}),
      );

      final data = json.decode(response.body);

      if (data['success']) {
        final subcategory = Subcategory.fromJson(data['data']);
        final categoryIndex = _categories.indexWhere((cat) => cat.id == categoryId);
        if (categoryIndex != -1) {
          _categories[categoryIndex].subcategories ??= [];
          _categories[categoryIndex].subcategories!.add(subcategory);
          _filteredCategories = List.from(_categories);
          notifyListeners();
        }
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateSubcategory(
      String id, String name, String categoryId)
  async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/subcategories/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'category_id': categoryId}),
      );

      final data = json.decode(response.body);

      if (data['success']) {
        // Remove from old category
        for (var category in _categories) {
          category.subcategories?.removeWhere((sub) => sub.id == id);
        }

        // Add to new category
        final categoryIndex = _categories.indexWhere((cat) => cat.id == categoryId);
        if (categoryIndex != -1) {
          _categories[categoryIndex].subcategories ??= [];
          _categories[categoryIndex].subcategories!.add(Subcategory.fromJson(data['data']));
          _filteredCategories = List.from(_categories);
          notifyListeners();
        }
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteSubcategory(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/subcategories/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(response.body);

      if (data['success']) {
        for (var category in _categories) {
          category.subcategories?.removeWhere((sub) => sub.id == id);
        }
        _filteredCategories = List.from(_categories);
        notifyListeners();
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  void searchCategories(String query) {
    if (query.isEmpty) {
      _filteredCategories = List.from(_categories);
    } else {
      _filteredCategories = _categories.where((category) {
        final nameMatches = category.name.toLowerCase().contains(query.toLowerCase());
        final subcategoryMatches = category.subcategories?.any((sub) =>
            sub.name.toLowerCase().contains(query.toLowerCase())) ??
            false;
        return nameMatches || subcategoryMatches;
      }).toList();
    }
    notifyListeners();
  }
}