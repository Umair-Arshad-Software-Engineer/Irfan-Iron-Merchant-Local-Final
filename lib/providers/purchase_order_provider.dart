// lib/providers/purchase_order_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/purchase_order_model.dart';

class PurchaseOrderProvider with ChangeNotifier {
  List<PurchaseOrderModel> _purchaseOrders = [];
  PurchaseOrderModel? _selectedPurchaseOrder;
  bool _isLoading = false;
  String? _errorMessage;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  List<PurchaseOrderModel> get purchaseOrders => _purchaseOrders;
  PurchaseOrderModel? get selectedPurchaseOrder => _selectedPurchaseOrder;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;

  // Fetch all purchase orders
  Future<Map<String, dynamic>> fetchPurchaseOrders({
    int? page,
    String? status,
    int? supplierId,
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int? limit,  // ← Add this parameter
    bool refresh = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (refresh) {
        _currentPage = 1;
      }

      final queryParams = <String, String>{
        'page': (page ?? _currentPage).toString(),
        'limit': (limit ?? 20).toString(),  // ← Use limit or default to 20
      };

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (supplierId != null) {
        queryParams['supplier_id'] = supplierId.toString();
      }
      if (fromDate != null) {
        queryParams['from_date'] = fromDate.toIso8601String().split('T')[0];
      }
      if (toDate != null) {
        queryParams['to_date'] = toDate.toIso8601String().split('T')[0];
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/purchase-orders')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['success']) {
          final List<dynamic> ordersJson = jsonResponse['data'];
          _purchaseOrders = ordersJson
              .map((json) => PurchaseOrderModel.fromJson(json))
              .toList();

          final pagination = jsonResponse['pagination'];
          _totalItems = pagination['total'];
          _currentPage = pagination['page'];
          _totalPages = pagination['pages'];

          _isLoading = false;
          notifyListeners();
          return {'success': true, 'data': _purchaseOrders};
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to fetch orders');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  // Fetch purchase order by ID
  Future<Map<String, dynamic>> fetchPurchaseOrderById(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/purchase-orders/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['success']) {
          _selectedPurchaseOrder = PurchaseOrderModel.fromJson(jsonResponse['data']);
          _isLoading = false;
          notifyListeners();
          return {'success': true, 'data': _selectedPurchaseOrder};
        } else {
          throw Exception(jsonResponse['message'] ?? 'Order not found');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  // Create purchase order
  Future<Map<String, dynamic>> createPurchaseOrder(Map<String, dynamic> orderData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/purchase-orders'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(orderData),
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 201 && jsonResponse['success']) {
        await fetchPurchaseOrders(refresh: true);
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'data': jsonResponse['data']};
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  // Update order status
  Future<Map<String, dynamic>> updateOrderStatus(int id, String status) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/purchase-orders/$id/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['success']) {
        await fetchPurchaseOrders(refresh: true);
        if (_selectedPurchaseOrder?.id == id) {
          await fetchPurchaseOrderById(id);
        }
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'message': jsonResponse['message']};
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to update status');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  // Delete order (draft only)
  Future<Map<String, dynamic>> deletePurchaseOrder(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/purchase-orders/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['success']) {
        _purchaseOrders.removeWhere((po) => po.id == id);
        if (_selectedPurchaseOrder?.id == id) {
          _selectedPurchaseOrder = null;
        }
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'message': jsonResponse['message']};
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to delete order');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  void clearSelectedOrder() {
    _selectedPurchaseOrder = null;
    notifyListeners();
  }

  void setPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      fetchPurchaseOrders(page: page);
    }
  }

  // Update full purchase order (for editing)
  Future<Map<String, dynamic>> updatePurchaseOrder(int id, Map<String, dynamic> orderData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/purchase-orders/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(orderData),
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['success']) {
        await fetchPurchaseOrders(refresh: true);
        if (_selectedPurchaseOrder?.id == id) {
          await fetchPurchaseOrderById(id);
        }
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'data': jsonResponse['data']};
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to update order');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }
}