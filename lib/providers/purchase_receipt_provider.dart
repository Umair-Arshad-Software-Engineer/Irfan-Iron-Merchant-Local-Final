// lib/providers/purchase_receipt_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/purchase_order_model.dart';

class PurchaseReceiptProvider with ChangeNotifier {
  List<PurchaseReceiptModel> _receipts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<PurchaseReceiptModel> get receipts => _receipts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get receipts for a purchase order
  Future<Map<String, dynamic>> fetchReceiptsByPurchaseOrder(int purchaseOrderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/purchase-orders/$purchaseOrderId/receipts'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['success']) {
          final List<dynamic> receiptsJson = jsonResponse['data'];
          _receipts = receiptsJson
              .map((json) => PurchaseReceiptModel.fromJson(json))
              .toList();
          _isLoading = false;
          notifyListeners();
          return {'success': true, 'data': _receipts};
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to fetch receipts');
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

  // Create purchase receipt
  Future<Map<String, dynamic>> createPurchaseReceipt(Map<String, dynamic> receiptData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/purchase-orders/receipts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(receiptData),
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 201 && jsonResponse['success']) {
        // Refresh receipts list
        await fetchReceiptsByPurchaseOrder(receiptData['purchase_order_id']);
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'data': jsonResponse['data']};
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to create receipt');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deletePurchaseReceipt(int receiptId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/purchase-orders/receipts/$receiptId'),
        headers: {'Content-Type': 'application/json'},
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['success']) {
        // Remove from local list immediately
        _receipts.removeWhere((r) => r.id == receiptId);
        _isLoading = false;
        notifyListeners();
        return {'success': true};
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to delete receipt');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }


  void clearReceipts() {
    _receipts = [];
    notifyListeners();
  }
}