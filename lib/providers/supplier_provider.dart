import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../config/api_config.dart';
import '../models/supplier.dart';
import 'auth_provider.dart';

class SupplierProvider with ChangeNotifier {
  List<Supplier> _suppliers = [];
  List<Supplier> _activeSuppliers = [];
  bool _isLoading = false;
  String _error = '';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  String _searchQuery = '';

  List<Supplier> get suppliers => _suppliers;
  List<Supplier> get activeSuppliers => _activeSuppliers;
  bool get isLoading => _isLoading;
  String get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  bool get hasMorePages => _currentPage < _totalPages;

  // Helper method to get token from auth provider
  String? _getToken(BuildContext context) {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.user?.token;
      if (kDebugMode) {
        print('Getting token: ${token != null ? "${token.substring(0, 20)}..." : "null"}');
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting token: $e');
      }
      return null;
    }
  }

  // Helper method to get headers
  Map<String, String> _getHeaders(BuildContext context) {
    final token = _getToken(context);
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (kDebugMode) {
      print('Request headers: $headers');
    }

    return headers;
  }

  Future<Map<String, dynamic>> fetchSuppliers({
    required BuildContext context,
    int page = 1,
    int limit = 20,
    String search = '',
    bool? active,
  })
  async {
    _isLoading = true;
    _error = '';

    // Remove immediate notifyListeners() call here
    // Future.microtask(() => notifyListeners()); // REMOVE THIS LINE

    try {
      String url = '${ApiConfig.baseUrl}/suppliers?page=$page&limit=$limit';

      if (search.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search)}';
      }

      if (active != null) {
        url += '&active=$active';
      }

      if (kDebugMode) {
        print('Fetching suppliers from: $url');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(context),
      );

      if (kDebugMode) {
        print('Suppliers Response: ${response.statusCode} - ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success']) {
          final List<Supplier> fetchedSuppliers = List<Supplier>.from(
              data['data'].map((x) => Supplier.fromJson(x))
          );

          if (page == 1) {
            _suppliers = fetchedSuppliers;
          } else {
            _suppliers.addAll(fetchedSuppliers);
          }

          _currentPage = data['pagination']['page'];
          _totalPages = data['pagination']['pages'];
          _totalItems = data['pagination']['total'];
          _searchQuery = search;

          _isLoading = false;
          notifyListeners(); // Keep this one

          return {
            'success': true,
            'message': 'Suppliers fetched successfully',
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch suppliers');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to load suppliers: ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners(); // Keep this one

      if (kDebugMode) {
        print('Error fetching suppliers: $e');
      }

      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> fetchActiveSuppliers(BuildContext context) async {
    try {
      final url = '${ApiConfig.baseUrl}/suppliers/active';

      if (kDebugMode) {
        print('Fetching active suppliers from: $url');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(context),
      );

      if (kDebugMode) {
        print('Active Suppliers Response: ${response.statusCode} - ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success']) {
          _activeSuppliers = List<Supplier>.from(
              data['data'].map((x) => Supplier.fromJson(x))
          );
          Future.microtask(() => notifyListeners());

          return {
            'success': true,
            'message': 'Active suppliers fetched successfully',
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch active suppliers');
        }
      } else {
        throw Exception('Failed to load active suppliers: ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error fetching active suppliers: $e');
      }
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> fetchSupplierById(int id, BuildContext context) async {
    try {
      final url = '${ApiConfig.baseUrl}/suppliers/$id';

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(context),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success']) {
          final supplier = Supplier.fromJson(data['data']);

          final index = _suppliers.indexWhere((s) => s.id == id);
          if (index != -1) {
            _suppliers[index] = supplier;
          }

          Future.microtask(() => notifyListeners());

          return {
            'success': true,
            'message': 'Supplier fetched successfully',
            'data': supplier,
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch supplier');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Supplier not found');
      } else {
        throw Exception('Failed to load supplier: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> createSupplier({
    required BuildContext context,
    required String name,
    required String contact,
    String? address,
    double discountPercent = 0,
  })
  async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      final url = '${ApiConfig.baseUrl}/suppliers';

      if (kDebugMode) {
        print('Creating supplier at: $url');
        print('Data: name=$name, contact=$contact, address=$address');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: _getHeaders(context),
        body: json.encode({
          'name': name,
          'contact': contact,
          'address': address,
          'discount_percent': discountPercent,
        }),
      );

      if (kDebugMode) {
        print('Create Supplier Response: ${response.statusCode} - ${response.body}');
      }

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['success']) {
        final supplier = Supplier.fromJson(data['data']);
        _suppliers.insert(0, supplier);
        _totalItems++;

        if (supplier.isActive) {
          _activeSuppliers.add(supplier);
          _activeSuppliers.sort((a, b) => a.name.compareTo(b.name));
        }

        _isLoading = false;
        Future.microtask(() => notifyListeners());

        return {
          'success': true,
          'message': 'Supplier created successfully',
          'data': supplier,
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to create supplier');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      Future.microtask(() => notifyListeners());

      if (kDebugMode) {
        print('Error creating supplier: $e');
      }

      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> updateSupplier({
    required BuildContext context,
    required int id,
    String? name,
    String? contact,
    String? address,
    bool? isActive,
    double discountPercent = 0,
  }) async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      final url = '${ApiConfig.baseUrl}/suppliers/$id';

      final response = await http.put(
        Uri.parse(url),
        headers: _getHeaders(context),
        body: json.encode({
          'name': name,
          'contact': contact,
          'address': address,
          'is_active': isActive,
          'discount_percent': discountPercent,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final supplier = Supplier.fromJson(data['data']);

        final index = _suppliers.indexWhere((s) => s.id == id);
        if (index != -1) {
          _suppliers[index] = supplier;
        }

        final activeIndex = _activeSuppliers.indexWhere((s) => s.id == id);
        if (supplier.isActive) {
          if (activeIndex == -1) {
            _activeSuppliers.add(supplier);
            _activeSuppliers.sort((a, b) => a.name.compareTo(b.name));
          } else {
            _activeSuppliers[activeIndex] = supplier;
          }
        } else {
          if (activeIndex != -1) {
            _activeSuppliers.removeAt(activeIndex);
          }
        }

        _isLoading = false;
        Future.microtask(() => notifyListeners());

        return {
          'success': true,
          'message': 'Supplier updated successfully',
          'data': supplier,
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to update supplier');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      Future.microtask(() => notifyListeners());
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> deleteSupplier(int id, BuildContext context) async {
    try {
      final url = '${ApiConfig.baseUrl}/suppliers/$id';

      final response = await http.delete(
        Uri.parse(url),
        headers: _getHeaders(context),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        _suppliers.removeWhere((s) => s.id == id);
        _activeSuppliers.removeWhere((s) => s.id == id);
        _totalItems--;
        Future.microtask(() => notifyListeners());

        return {
          'success': true,
          'message': 'Supplier deleted successfully',
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to delete supplier');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> toggleSupplierStatus(int id, BuildContext context) async {
    try {
      final url = '${ApiConfig.baseUrl}/suppliers/$id/toggle-status';

      final response = await http.patch(
        Uri.parse(url),
        headers: _getHeaders(context),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final index = _suppliers.indexWhere((s) => s.id == id);
        if (index != -1) {
          _suppliers[index] = _suppliers[index].copyWith(
            isActive: data['data']['is_active'],
          );

          if (data['data']['is_active']) {
            _activeSuppliers.add(_suppliers[index]);
            _activeSuppliers.sort((a, b) => a.name.compareTo(b.name));
          } else {
            _activeSuppliers.removeWhere((s) => s.id == id);
          }
        }

        Future.microtask(() => notifyListeners());

        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to toggle supplier status');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  void clearError() {
    _error = '';
    Future.microtask(() => notifyListeners());
  }

  void clearSuppliers() {
    _suppliers.clear();
    _currentPage = 1;
    _totalPages = 1;
    _totalItems = 0;
    Future.microtask(() => notifyListeners());
  }

  Supplier? getSupplierById(int id) {
    try {
      return _suppliers.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }
}