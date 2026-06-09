import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../models/customer.dart';

class CustomerProvider with ChangeNotifier {
  List<Customer> _customers = [];
  List<Customer> _activeCustomers = [];
  bool _isLoading = false;
  String _error = '';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  String _searchQuery = '';

  List<Customer> get customers => _customers;
  List<Customer> get activeCustomers => _activeCustomers;
  bool get isLoading => _isLoading;
  String get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  bool get hasMorePages => _currentPage < _totalPages;

  // Helper method to get headers (simplified without token)
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<Map<String, dynamic>> fetchCustomers({
    int page = 1,
    int limit = 20,
    String search = '',
    bool? active,
    String? customerType,
  })
  async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      String url = '${ApiConfig.baseUrl}/customers?page=$page&limit=$limit';

      if (search.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search)}';
      }

      if (active != null) {
        url += '&active=$active';
      }

      if (customerType != null && customerType.isNotEmpty) {
        url += '&customer_type=$customerType';
      }

      if (kDebugMode) {
        print('Fetching customers from: $url');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      if (kDebugMode) {
        print('Customers Response: ${response.statusCode} - ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success']) {
          final List<Customer> fetchedCustomers = List<Customer>.from(
              data['data'].map((x) => Customer.fromJson(x))
          );

          if (page == 1) {
            _customers = fetchedCustomers;
          } else {
            _customers.addAll(fetchedCustomers);
          }

          _currentPage = data['pagination']['page'];
          _totalPages = data['pagination']['pages'];
          _totalItems = data['pagination']['total'];
          _searchQuery = search;

          _isLoading = false;
          notifyListeners();

          return {
            'success': true,
            'message': 'Customers fetched successfully',
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch customers');
        }
      } else {
        throw Exception('Failed to load customers: ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('Error fetching customers: $e');
      }

      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<void> loadSubcategoriesForCategory(String categoryId) async {
    try {
      // Implementation for loading subcategories for a specific category
      // This should fetch from your API endpoint like: /api/categories/:id/subcategories
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> fetchActiveCustomers() async {
    try {
      final url = '${ApiConfig.baseUrl}/customers/active';

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success']) {
          _activeCustomers = List<Customer>.from(
              data['data'].map((x) => Customer.fromJson(x))
          );
          notifyListeners();

          return {
            'success': true,
            'message': 'Active customers fetched successfully',
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch active customers');
        }
      } else {
        throw Exception('Failed to load active customers: ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error fetching active customers: $e');
      }
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> fetchCustomerById(int id) async {
    try {
      final url = '${ApiConfig.baseUrl}/customers/$id';

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success']) {
          final customer = Customer.fromJson(data['data']);

          final index = _customers.indexWhere((c) => c.id == id);
          if (index != -1) {
            _customers[index] = customer;
          }

          notifyListeners();

          return {
            'success': true,
            'message': 'Customer fetched successfully',
            'data': customer,
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch customer');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Customer not found');
      } else {
        throw Exception('Failed to load customer: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

// Add discountPercent to createCustomer method
  Future<Map<String, dynamic>> createCustomer({
    required String name,
    required String contact,
    String? address,
    String? email,
    String customerType = 'regular',
    double balance = 0.0,
    double discountPercent = 0.0, // Add this parameter
  })
  async {
    _isLoading = true;
    notifyListeners();

    try {
      final url = '${ApiConfig.baseUrl}/customers';

      final response = await http.post(
        Uri.parse(url),
        headers: _getHeaders(),
        body: json.encode({
          'name': name,
          'contact': contact,
          'address': address,
          'email': email,
          'customer_type': customerType,
          'balance': balance,
          'discount_percent': discountPercent, // Add this field
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['success']) {
        final customer = Customer.fromJson(data['data']);
        _customers.insert(0, customer);
        _totalItems++;

        if (customer.isActive) {
          _activeCustomers.add(customer);
          _activeCustomers.sort((a, b) => a.name.compareTo(b.name));
        }

        _isLoading = false;
        notifyListeners();

        return {
          'success': true,
          'message': 'Customer created successfully',
          'data': customer,
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to create customer');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('Error creating customer: $e');
      }

      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

// Add discountPercent to updateCustomer method
  Future<Map<String, dynamic>> updateCustomer({
    required int id,
    String? name,
    String? contact,
    String? address,
    String? email,
    String? customerType,
    double? balance,
    bool? isActive,
    double? discountPercent, // Add this parameter
  })
  async {
    _isLoading = true;
    notifyListeners();

    try {
      final url = '${ApiConfig.baseUrl}/customers/$id';

      final response = await http.put(
        Uri.parse(url),
        headers: _getHeaders(),
        body: json.encode({
          'name': name,
          'contact': contact,
          'address': address,
          'email': email,
          'customer_type': customerType,
          'balance': balance,
          'is_active': isActive,
          'discount_percent': discountPercent, // Add this field
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final customer = Customer.fromJson(data['data']);

        final index = _customers.indexWhere((c) => c.id == id);
        if (index != -1) {
          _customers[index] = customer;
        }

        final activeIndex = _activeCustomers.indexWhere((c) => c.id == id);
        if (customer.isActive) {
          if (activeIndex == -1) {
            _activeCustomers.add(customer);
            _activeCustomers.sort((a, b) => a.name.compareTo(b.name));
          } else {
            _activeCustomers[activeIndex] = customer;
          }
        } else {
          if (activeIndex != -1) {
            _activeCustomers.removeAt(activeIndex);
          }
        }

        _isLoading = false;
        notifyListeners();

        return {
          'success': true,
          'message': 'Customer updated successfully',
          'data': customer,
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to update customer');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> deleteCustomer(int id) async {
    try {
      final url = '${ApiConfig.baseUrl}/customers/$id';

      final response = await http.delete(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        _customers.removeWhere((c) => c.id == id);
        _activeCustomers.removeWhere((c) => c.id == id);
        _totalItems--;
        notifyListeners();

        return {
          'success': true,
          'message': 'Customer deleted successfully',
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to delete customer');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> toggleCustomerStatus(int id) async {
    try {
      final url = '${ApiConfig.baseUrl}/customers/$id/toggle-status';

      final response = await http.patch(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final index = _customers.indexWhere((c) => c.id == id);
        if (index != -1) {
          _customers[index] = _customers[index].copyWith(
            isActive: data['data']['is_active'],
          );

          if (data['data']['is_active']) {
            _activeCustomers.add(_customers[index]);
            _activeCustomers.sort((a, b) => a.name.compareTo(b.name));
          } else {
            _activeCustomers.removeWhere((c) => c.id == id);
          }
        }

        notifyListeners();

        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to toggle customer status');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> updateCustomerBalance({
    required int id,
    required double amount,
    required String operation, // 'add' or 'subtract'
  })
  async {
    try {
      final url = '${ApiConfig.baseUrl}/customers/$id/update-balance';

      final response = await http.patch(
        Uri.parse(url),
        headers: _getHeaders(),
        body: json.encode({
          'amount': amount,
          'operation': operation,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        // Update local customer balance
        final index = _customers.indexWhere((c) => c.id == id);
        if (index != -1) {
          final oldCustomer = _customers[index];
          _customers[index] = oldCustomer.copyWith(
            balance: data['data']['new_balance'].toDouble(),
          );
        }

        // Update in active customers list if present
        final activeIndex = _activeCustomers.indexWhere((c) => c.id == id);
        if (activeIndex != -1) {
          final oldActiveCustomer = _activeCustomers[activeIndex];
          _activeCustomers[activeIndex] = oldActiveCustomer.copyWith(
            balance: data['data']['new_balance'].toDouble(),
          );
        }

        notifyListeners();

        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to update customer balance');
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
    notifyListeners();
  }

  void clearCustomers() {
    _customers.clear();
    _currentPage = 1;
    _totalPages = 1;
    _totalItems = 0;
    notifyListeners();
  }

  Customer? getCustomerById(int id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Filter customers by type
  List<Customer> getCustomersByType(String type) {
    return _customers.where((c) => c.customerType == type).toList();
  }

  // Get total outstanding balance
  double get totalOutstandingBalance {
    return _customers.fold(0.0, (sum, customer) => sum + customer.balance);
  }

  // Get customers with outstanding balance
  List<Customer> get customersWithBalance {
    return _customers.where((c) => c.balance > 0).toList();
  }
}