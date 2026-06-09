import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class CustomerLedgerProvider with ChangeNotifier {
  List<dynamic> _entries = [];
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _pagination;
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;

  List<dynamic> get entries => _entries;
  Map<String, dynamic>? get summary => _summary;
  Map<String, dynamic>? get pagination => _pagination;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;

  bool get hasMorePages {
    if (_pagination == null) return false;
    final totalPages = _pagination!['pages'] as int? ?? 1;
    final currentPage = _pagination!['page'] as int? ?? 1;
    return currentPage < totalPages;
  }

  Future<void> fetchCustomerLedger({
    required int customerId,
    int page = 1,
    int limit = 50,
    String? fromDate,
    String? toDate,
    String? transactionType,
    String? sortBy = 'created_at', // Add this parameter to specify which field to sort by
    String? sortOrder = 'desc', // Add this parameter with default 'desc'
  })
  async {
    _isLoading = true;
    _error = null;
    _currentPage = page;
    notifyListeners();

    try {
      // Build query parameters
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (fromDate != null) 'from_date': fromDate,
        if (toDate != null) 'to_date': toDate,
        if (transactionType != null && transactionType != 'All')
          'transaction_type': transactionType,
        if (sortBy != null) 'sort_by': sortBy, // Add sort_by parameter
        if (sortOrder != null) 'sort_order': sortOrder, // Add sort_order parameter
      };

      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/customer-ledger/$customerId'
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (page == 1) {
            _entries = data['data']['entries'];
          } else {
            _entries.addAll(data['data']['entries']);
          }
          _summary = data['data']['summary'];
          _pagination = data['data']['pagination'];
        } else {
          _error = data['message'] ?? 'Failed to load ledger';
        }
      } else {
        _error = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getAllCustomersLedgerSummary() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/customer-ledger/summary'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }
      return {'success': false, 'message': 'Failed to load summary'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addAdjustment({
    required int customerId,
    required String description,
    double debit = 0,
    double credit = 0,
    DateTime? date,
  })
  async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/customer-ledger/$customerId/adjustment'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'date': date?.toIso8601String().split('T').first,
          'description': description,
          'debit': debit,
          'credit': credit,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        // Refresh ledger after adding adjustment
        await fetchCustomerLedger(customerId: customerId);
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  void clear() {
    _entries = [];
    _summary = null;
    _pagination = null;
    _error = null;
    _currentPage = 1;
    notifyListeners();
  }
}