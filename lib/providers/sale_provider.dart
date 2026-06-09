// lib/providers/sale_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/sale_model.dart';

class SaleProvider with ChangeNotifier {
  List<SaleModel> _sales = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  Map<String, dynamic> _summary = {};

  // Getters
  List<SaleModel> get sales => _sales;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  Map<String, dynamic> get summary => _summary;

  // Helper method to get auth headers
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  Future<void> fetchSales({
    int page = 1,
    int limit = 20,
    String? search,
    String? saleType,
    String? saleCategory, // Add this parameter
    String? paymentStatus,
    int? customerId,
    DateTime? fromDate,
    DateTime? toDate,
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
    } else {
      _currentPage = page;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (saleType != null && saleType.isNotEmpty) 'sale_type': saleType,
        if (saleCategory != null && saleCategory.isNotEmpty) 'sale_category': saleCategory, // Add this line
        if (paymentStatus != null && paymentStatus.isNotEmpty) 'payment_status': paymentStatus,
        if (customerId != null) 'customer_id': customerId.toString(),
        if (fromDate != null) 'date_from': fromDate.toIso8601String().split('T').first,
        if (toDate != null) 'date_to': toDate.toIso8601String().split('T').first,
        'sort_by': 'created_at',
        'sort_order': 'DESC',
      };

      final uri = Uri.parse(ApiConfig.salesUrl).replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _sales = (json['data'] as List).map((e) => SaleModel.fromJson(e)).toList();
          _totalItems = json['pagination']['total'] ?? 0;
          _totalPages = json['pagination']['pages'] ?? 1;
          _summary = json['summary'] ?? {};
        } else {
          _errorMessage = json['message'] ?? 'Failed to fetch sales';
        }
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get single sale by ID
  Future<SaleModel?> getSaleById(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.salesUrl}/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          return SaleModel.fromJson(json['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching sale: $e');
      return null;
    }
  }

  // Create new sale
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData) async {
    _isLoading = true;
    notifyListeners();

    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.salesUrl),
        headers: headers,
        body: jsonEncode(saleData),
      );

      final json = jsonDecode(response.body);

      if (response.statusCode == 201 && json['success'] == true) {
        await fetchSales(refresh: true);
        return {'success': true, 'data': json['data']};
      } else {
        return {
          'success': false,
          'message': json['message'] ?? 'Failed to create sale',
          'errors': json['errors'],
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update sale
  Future<Map<String, dynamic>> updateSale(int id, Map<String, dynamic> saleData) async {
    _isLoading = true;
    notifyListeners();

    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConfig.salesUrl}/$id'),
        headers: headers,
        body: jsonEncode(saleData),
      );

      final json = jsonDecode(response.body);

      if (response.statusCode == 200 && json['success'] == true) {
        await fetchSales(refresh: true);
        return {'success': true, 'data': json['data']};
      } else {
        return {'success': false, 'message': json['message'] ?? 'Failed to update sale'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete sale
  Future<Map<String, dynamic>> deleteSale(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.salesUrl}/$id'),
        headers: headers,
      );

      final json = jsonDecode(response.body);

      if (response.statusCode == 200 && json['success'] == true) {
        await fetchSales(refresh: true);
        return {'success': true};
      } else {
        return {'success': false, 'message': json['message'] ?? 'Failed to delete sale'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<Map<String, dynamic>> recordPayment(
      int id,
      double amount,
      String paymentMethod, {
        DateTime? paymentDate,
        String? chequeNumber,
        String? bankName,
        int? bankId,           // Add this parameter
        DateTime? chequeDate,
        bool fromSimpleCashbook = false, // ✅ new

      })
  async {
    _isLoading = true;
    notifyListeners();

    try {
      final headers = await _getHeaders();

      final Map<String, dynamic> requestBody = {
        'amount': amount,
        'payment_method': paymentMethod,
        if (fromSimpleCashbook) 'from_simple_cashbook': true, // ✅ add
      };

      if (paymentDate != null) {
        requestBody['payment_date'] = paymentDate.toIso8601String().split('T').first;
      }

      if (chequeNumber != null && chequeNumber.isNotEmpty) {
        requestBody['cheque_number'] = chequeNumber;
      }

      if (bankName != null && bankName.isNotEmpty) {
        requestBody['bank_name'] = bankName;
      }

      if (bankId != null) {
        requestBody['bank_id'] = bankId;  // ✅ Send bank_id to backend
      }

      if (chequeDate != null) {
        requestBody['cheque_date'] = chequeDate.toIso8601String().split('T').first;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.salesUrl}/$id/payment'),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      final json = jsonDecode(response.body);

      if (response.statusCode == 200 && json['success'] == true) {
        await fetchSales(refresh: true);
        return {
          'success': true,
          'data': json['data'],
          'message': json['message']
        };
      } else {
        return {'success': false, 'message': json['message'] ?? 'Failed to record payment'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get daily summary
  Future<Map<String, dynamic>> getDailySummary({DateTime? date}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{};
      if (date != null) {
        queryParams['date'] = date.toIso8601String().split('T').first;
      }

      final uri = Uri.parse('${ApiConfig.salesUrl}/summary/daily').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          return {'success': true, 'data': json['data']};
        }
      }
      return {'success': false, 'message': 'Failed to fetch summary'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  void setPage(int page) {
    if (page != _currentPage) {
      fetchSales(page: page);
    }
  }

}
