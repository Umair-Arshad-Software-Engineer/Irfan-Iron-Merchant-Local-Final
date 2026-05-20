import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/unit.dart';
import '../config/api_config.dart';

class UnitProvider with ChangeNotifier {
  List<Unit> _units = [];
  List<Unit> _filteredUnits = [];
  bool _isLoading = false;
  String _error = '';

  // Filter states
  String _searchQuery = '';
  String? _selectedType;
  bool _showActiveOnly = false;  // Add this property

  // For conversion
  bool _isConverting = false;
  String _conversionError = '';
  UnitConversion? _conversionResult;

  List<Unit> get units => _filteredUnits;
  List<Unit> get activeUnits => _units.where((unit) => unit.isActive).toList();
  bool get isLoading => _isLoading;
  String get error => _error;
  bool get isConverting => _isConverting;
  String get conversionError => _conversionError;
  UnitConversion? get conversionResult => _conversionResult;
  bool get showActiveOnly => _showActiveOnly;  // Getter for showActiveOnly

  // Get units by type
  List<Unit> getUnitsByType(String type) {
    return activeUnits.where((unit) => unit.type == type).toList();
  }

  // Get base units
  List<Unit> getBaseUnits() {
    return activeUnits.where((unit) => unit.baseUnitId == null).toList();
  }

  // Get derived units for a base unit
  List<Unit> getDerivedUnits(String baseUnitId) {
    return activeUnits.where((unit) => unit.baseUnitId == baseUnitId).toList();
  }

  Future<void> loadUnits() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/units'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _units = (data['data'] as List)
              .map((unit) => Unit.fromJson(unit))
              .toList();
          _applyFilters();  // Apply existing filters after loading
        } else {
          _error = data['message'] ?? 'Failed to load units';
        }
      } else {
        _error = 'Failed to load units: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createUnit({
    required String name,
    required String symbol,
    required String type,
    double conversionFactor = 1.0,
    String? baseUnitId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/units'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'symbol': symbol,
          'type': type,
          'conversion_factor': conversionFactor,
          'base_unit_id': baseUnitId,
        }),
      );

      final data = json.decode(response.body);

      if (data['success']) {
        final unit = Unit.fromJson(data['data']);
        _units.insert(0, unit);
        _applyFilters();  // Apply filters after adding
        notifyListeners();
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateUnit({
    required String id,
    String? name,
    String? symbol,
    String? type,
    bool? isActive,
    double? conversionFactor,
    String? baseUnitId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/units/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          if (name != null) 'name': name,
          if (symbol != null) 'symbol': symbol,
          if (type != null) 'type': type,
          if (isActive != null) 'is_active': isActive,
          if (conversionFactor != null) 'conversion_factor': conversionFactor,
          if (baseUnitId != null) 'base_unit_id': baseUnitId,
        }),
      );

      final data = json.decode(response.body);

      if (data['success']) {
        final index = _units.indexWhere((unit) => unit.id == id);
        if (index != -1) {
          _units[index] = Unit.fromJson(data['data']);
          _applyFilters();  // Apply filters after updating
          notifyListeners();
        }
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteUnit(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/units/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(response.body);

      if (data['success']) {
        _units.removeWhere((unit) => unit.id == id);
        _applyFilters();  // Apply filters after deleting
        notifyListeners();
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> convertUnits({
    required String fromUnitId,
    required String toUnitId,
    required double value,
  }) async {
    _isConverting = true;
    _conversionError = '';
    _conversionResult = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/units/convert'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'from_unit_id': fromUnitId,
          'to_unit_id': toUnitId,
          'value': value,
        }),
      );

      final data = json.decode(response.body);

      if (data['success']) {
        _conversionResult = UnitConversion.fromJson(data['data']);
      } else {
        _conversionError = data['message'] ?? 'Conversion failed';
      }

      return data;
    } catch (e) {
      _conversionError = 'Error: $e';
      return {'success': false, 'message': 'Error: $e'};
    } finally {
      _isConverting = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> seedDefaultUnits() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/units/seed-defaults'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(response.body);

      if (data['success']) {
        await loadUnits(); // Reload units after seeding
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  void searchUnits(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void filterByType(String? type) {
    _selectedType = type;
    _applyFilters();
  }

  void filterActive(bool activeOnly) {
    _showActiveOnly = activeOnly;
    _applyFilters();
  }

  // In unit_provider.dart, add this method if it doesn't exist:
  Future<void> fetchUnits() async {
    await loadUnits(); // Just call loadUnits
  }

  // Combined filter method
  void _applyFilters() {
    List<Unit> result = List.from(_units);

    // Apply active filter
    if (_showActiveOnly) {
      result = result.where((unit) => unit.isActive).toList();
    }

    // Apply type filter
    if (_selectedType != null) {
      result = result.where((unit) => unit.type == _selectedType).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((unit) {
        final nameMatches = unit.name.toLowerCase().contains(query);
        final symbolMatches = unit.symbol.toLowerCase().contains(query);
        final typeMatches = unit.typeDisplay.toLowerCase().contains(query);
        return nameMatches || symbolMatches || typeMatches;
      }).toList();
    }

    _filteredUnits = result;
    notifyListeners();
  }

  void clearConversion() {
    _conversionResult = null;
    _conversionError = '';
    notifyListeners();
  }

  // Method to clear all filters
  void clearFilters() {
    _searchQuery = '';
    _selectedType = null;
    _showActiveOnly = false;
    _filteredUnits = List.from(_units);
    notifyListeners();
  }
}