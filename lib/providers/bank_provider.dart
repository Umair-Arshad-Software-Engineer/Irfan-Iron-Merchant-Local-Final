// lib/providers/bank_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/bank.dart';
import '../models/bank_transaction.dart';
import 'auth_provider.dart';

class BankProvider with ChangeNotifier {
  List<Bank> _banks = [];
  List<BankTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  List<Bank> get banks => _banks;
  List<BankTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String? _getToken(AuthProvider? authProvider) {
    if (authProvider != null && authProvider.user != null) {
      return authProvider.user!.token;
    }
    return null;
  }

  // Fetch all banks from API
  Future<void> fetchBanks({String? search, bool? active, AuthProvider? authProvider}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (search != null) queryParams['search'] = search;
      if (active != null) queryParams['active'] = active.toString();

      final uri = Uri.parse('${ApiConfig.baseUrl}/banks')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (_getToken(authProvider) != null)
            'Authorization': 'Bearer ${_getToken(authProvider)}',
        },
      );

      debugPrint('fetchBanks → status: ${response.statusCode}');
      debugPrint('fetchBanks → body: ${response.body.substring(0, response.body.length.clamp(0, 300))}');

      // Guard against HTML error pages
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        _error = 'Server error (status ${response.statusCode}). Check server logs.';
        return;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _banks = (data['data'] as List)
              .map((json) => Bank.fromJson(json))
              .toList();
        } else {
          _error = data['message'] ?? 'Failed to load banks';
        }
      } else {
        _error = 'Failed to load banks: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error: $e';
      debugPrint('Fetch banks error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch bank summary
  Future<Map<String, dynamic>?> fetchBankSummary({AuthProvider? authProvider}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/banks/summary'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken(authProvider) != null) 'Authorization': 'Bearer ${_getToken(authProvider)}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Fetch bank summary error: $e');
      return null;
    }
  }

  // Create new bank
  Future<bool> createBank({
    required String name,
    String? iconPath,
    String? accountNumber,
    String? branchCode,
    String? swiftCode,
    String? iban,
    double? openingBalance,
    String? notes,
    AuthProvider? authProvider,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/banks'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken(authProvider) != null) 'Authorization': 'Bearer ${_getToken(authProvider)}',
        },
        body: json.encode({
          'name': name,
          'icon_path': iconPath ?? 'asset/bank_icons/default.png',
          'account_number': accountNumber,
          'branch_code': branchCode,
          'swift_code': swiftCode,
          'iban': iban,
          'opening_balance': openingBalance ?? 0,
          'notes': notes,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        await fetchBanks(authProvider: authProvider); // Refresh list
        return true;
      }
      _error = data['message'] ?? 'Failed to create bank';
      return false;
    } catch (e) {
      _error = 'Error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add transaction
  Future<bool> addTransaction({
    required int bankId,
    required String type,
    required double amount,
    required String description,
    String? referenceNumber,
    DateTime? transactionDate,
    AuthProvider? authProvider,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/banks/$bankId/transactions'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken(authProvider) != null) 'Authorization': 'Bearer ${_getToken(authProvider)}',
        },
        body: json.encode({
          'transaction_type': type,
          'amount': amount,
          'description': description,
          'reference_number': referenceNumber,
          'transaction_date': transactionDate?.toIso8601String(),
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        await fetchBanks(authProvider: authProvider); // Refresh bank list
        await fetchTransactions(bankId, authProvider: authProvider); // Refresh transactions
        return true;
      }
      _error = data['message'] ?? 'Failed to add transaction';
      return false;
    } catch (e) {
      _error = 'Error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch transactions for a bank
  Future<void> fetchTransactions(int bankId,
      {String? type, DateTime? fromDate, DateTime? toDate, AuthProvider? authProvider}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (type != null) queryParams['type'] = type;
      if (fromDate != null) queryParams['from_date'] = fromDate.toIso8601String().split('T').first;
      if (toDate != null) queryParams['to_date'] = toDate.toIso8601String().split('T').first;

      final uri = Uri.parse('${ApiConfig.baseUrl}/banks/$bankId/transactions')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (_getToken(authProvider) != null) 'Authorization': 'Bearer ${_getToken(authProvider)}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _transactions = (data['data']['transactions'] as List)
              .map((json) => BankTransaction.fromJson(json))
              .toList();
        }
      } else {
        _error = 'Failed to load transactions';
      }
    } catch (e) {
      _error = 'Error: $e';
      debugPrint('Fetch transactions error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get transactions by bank name (for compatibility with older code)
  List<BankTransaction> getTransactionsForBank(String bankName) {
    final bank = _banks.firstWhere((b) => b.name == bankName, orElse: () => Bank(id: 0, name: '', iconPath: '', balance: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()));
    if (bank.id == 0) return [];
    return _transactions.where((t) => t.bankId == bank.id).toList();
  }

  // Get bank balance by name
  double getBankBalance(String bankName) {
    final bank = _banks.firstWhere((b) => b.name == bankName, orElse: () => Bank(id: 0, name: '', iconPath: '', balance: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()));
    return bank.balance;
  }

  double getBankBalanceById(int bankId) {
    final bank = _banks.firstWhere((b) => b.id == bankId, orElse: () => Bank(id: 0, name: '', iconPath: '', balance: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()));
    return bank.balance;
  }

  Future<bool> transferBetweenBanks({
    required int fromBankId,
    required int toBankId,
    required double amount,
    required String description,
    String? referenceNumber,
    AuthProvider? authProvider,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = _getToken(authProvider);

      // Log the request for debugging
      debugPrint('=== Transfer Between Banks ===');
      debugPrint('From Bank ID: $fromBankId');
      debugPrint('To Bank ID: $toBankId');
      debugPrint('Amount: $amount');
      debugPrint('Description: $description');
      debugPrint('Token present: ${token != null}');

      final url = '${ApiConfig.baseUrl}/banks/transfers';
      debugPrint('URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json', // Add this to request JSON
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'from_bank_id': fromBankId,
          'to_bank_id': toBankId,
          'amount': amount,
          'description': description,
          'reference_number': referenceNumber,
          'transfer_date': DateTime.now().toIso8601String(),
        }),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response headers: ${response.headers}');
      debugPrint('Response body: ${response.body.substring(0, response.body.length.clamp(0, 500))}');

      // Check if response is HTML
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        _error = 'Server returned ${contentType.split(';').first} instead of JSON. Status: ${response.statusCode}';
        debugPrint('Error: Non-JSON response received');
        return false;
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Refresh both banks' data
          await fetchBanks(authProvider: authProvider);
          await fetchTransactions(fromBankId, authProvider: authProvider);
          if (fromBankId != toBankId) {
            await fetchTransactions(toBankId, authProvider: authProvider);
          }
          return true;
        } else {
          _error = data['message'] ?? 'Transfer failed';
          return false;
        }
      } else {
        _error = 'Transfer failed with status: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      _error = 'Error: $e';
      debugPrint('Transfer error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<bool> deleteTransaction(int bankId, int transactionId, {AuthProvider? authProvider}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/banks/$bankId/transactions/$transactionId'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken(authProvider) != null) 'Authorization': 'Bearer ${_getToken(authProvider)}',
        },
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        await fetchBanks(authProvider: authProvider); // Refresh balances
        await fetchTransactions(bankId, authProvider: authProvider); // Refresh transactions
        return true;
      }
      _error = data['message'] ?? 'Failed to delete transaction';
      return false;
    } catch (e) {
      _error = 'Error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset all balances (for testing)
  Future<void> resetAllBalances({AuthProvider? authProvider}) async {
    // This is a dangerous operation - only for testing
    // In production, you might want to implement this as an admin-only API endpoint
    for (var i = 0; i < _banks.length; i++) {
      _banks[i] = Bank(
        id: _banks[i].id,
        name: _banks[i].name,
        iconPath: _banks[i].iconPath,
        balance: 0,
        isActive: _banks[i].isActive,
        accountNumber: _banks[i].accountNumber,
        branchCode: _banks[i].branchCode,
        swiftCode: _banks[i].swiftCode,
        iban: _banks[i].iban,
        createdAt: _banks[i].createdAt,
        updatedAt: DateTime.now(),
      );
    }
    notifyListeners();
  }



  double getTotalBalance() {
    return _banks.fold(0.0, (sum, bank) => sum + bank.balance);
  }
}