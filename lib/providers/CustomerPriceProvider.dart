// lib/providers/customer_price_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/customer_price_model.dart';

class CustomerPriceProvider with ChangeNotifier {
  List<CustomerPriceModel> _prices = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CustomerPriceModel> get prices => _prices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Map<String, String> _getHeaders() => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Fetch all prices, optionally filtered by customerId or productId
  Future<void> fetchPrices({int? customerId, int? productId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String url = '${ApiConfig.baseUrl}/customer-prices?';
      if (customerId != null) url += 'customer_id=$customerId&';
      if (productId != null) url += 'product_id=$productId&';

      final response = await http.get(Uri.parse(url), headers: _getHeaders());
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        _prices = (data['data'] as List)
            .map((e) => CustomerPriceModel.fromJson(e))
            .toList();
      } else {
        _errorMessage = data['message'] ?? 'Failed to fetch prices';
      }
    } catch (e) {
      _errorMessage = e.toString();
      if (kDebugMode) print('Fetch customer prices error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set (create or update) a customer price
  Future<Map<String, dynamic>> setCustomerPrice({
    required int customerId,
    required int productId,
    required double price,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/customer-prices'),
        headers: _getHeaders(),
        body: json.encode({
          'customer_id': customerId,
          'product_id': productId,
          'price': price,
        }),
      );

      final data = json.decode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) && data['success']) {
        final newPrice = CustomerPriceModel.fromJson(data['data']);

        // Update local list — replace if exists, insert if new
        final idx = _prices.indexWhere(
              (p) => p.customerId == customerId && p.productId == productId,
        );
        if (idx != -1) {
          _prices[idx] = newPrice;
        } else {
          _prices.insert(0, newPrice);
        }
        notifyListeners();

        return {'success': true, 'data': newPrice, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to set price'};
      }
    } catch (e) {
      if (kDebugMode) print('Set customer price error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Delete a customer price by id
  Future<Map<String, dynamic>> deleteCustomerPrice(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/customer-prices/$id'),
        headers: _getHeaders(),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        _prices.removeWhere((p) => p.id == id);
        notifyListeners();
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to delete price'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Toggle active status
  Future<Map<String, dynamic>> toggleStatus(int id) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/customer-prices/$id/toggle-status'),
        headers: _getHeaders(),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final idx = _prices.indexWhere((p) => p.id == id);
        if (idx != -1) {
          _prices[idx] = _prices[idx].copyWith(isActive: data['data']['is_active']);
          notifyListeners();
        }
        return {'success': true, 'message': data['message'], 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to toggle status'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get bulk prices for a customer + list of products (returns map productId -> price)
  Future<Map<int, double>> getBulkPrices({
    required int customerId,
    required List<int> productIds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/customer-prices/bulk'),
        headers: _getHeaders(),
        body: json.encode({'customer_id': customerId, 'product_ids': productIds}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final Map<int, double> result = {};
        (data['data'] as Map<String, dynamic>).forEach((key, value) {
          result[int.parse(key)] = double.tryParse(value.toString()) ?? 0.0;
        });
        return result;
      }
    } catch (e) {
      if (kDebugMode) print('Get bulk prices error: $e');
    }
    return {};
  }

  // Prices for a specific product (from cached list)
  List<CustomerPriceModel> pricesForProduct(int productId) =>
      _prices.where((p) => p.productId == productId).toList();

  // Prices for a specific customer (from cached list)
  List<CustomerPriceModel> pricesForCustomer(int customerId) =>
      _prices.where((p) => p.customerId == customerId).toList();

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}