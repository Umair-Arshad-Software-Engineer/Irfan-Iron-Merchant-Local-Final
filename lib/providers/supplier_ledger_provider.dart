import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../config/api_config.dart';
import 'auth_provider.dart';

class LedgerEntry {
  final int id;
  final int supplierId;
  final String referenceType;
  final int? referenceId;
  final String? referenceNumber;
  final double debit;
  final double credit;
  final double balance;
  final String? description;
  final DateTime transactionDate;
  final DateTime createdAt;

  // ── Payment-specific fields ──────────────────────────────────────────────
  final String? paymentMethod;   // 'cash' | 'bank' | 'cheque' | 'slip'
  final String? bankName;
  final String? chequeNumber;
  final String? chequeDate;      // formatted string e.g. "2025-01-15"
  final bool? chequeCleared;
  final DateTime? chequeClearedDate;
  // ────────────────────────────────────────────────────────────────────────

  LedgerEntry({
    required this.id,
    required this.supplierId,
    required this.referenceType,
    this.referenceId,
    this.referenceNumber,
    required this.debit,
    required this.credit,
    required this.balance,
    this.description,
    required this.transactionDate,
    required this.createdAt,
    this.paymentMethod,
    this.bankName,
    this.chequeNumber,
    this.chequeDate,
    this.chequeCleared,        // Add this
    this.chequeClearedDate,    // Add this
  });


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'reference_number': referenceNumber,
      'debit': debit,
      'credit': credit,
      'balance': balance,
      'description': description,
      'transaction_date': transactionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'payment_method': paymentMethod,
      'bank_name': bankName,
      'cheque_number': chequeNumber,
      'cheque_date': chequeDate,
      'cheque_cleared': chequeCleared,        // Add this
      'cheque_cleared_date': chequeClearedDate?.toIso8601String(), // Add this
    };
  }

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id:              json['id'] as int,
      supplierId:      json['supplier_id'] as int,
      referenceType:   json['reference_type'] as String,
      referenceId:     json['reference_id'] as int?,
      referenceNumber: json['reference_number'] as String?,
      debit:           double.tryParse(json['debit']?.toString() ?? '0') ?? 0.0,
      credit:          double.tryParse(json['credit']?.toString() ?? '0') ?? 0.0,
      balance:         double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
      description:     json['description'] as String?,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      createdAt:       DateTime.parse(json['created_at'] as String),
      // Payment fields – null for non-payment entries
      paymentMethod:   json['payment_method'] as String?,
      bankName:        json['bank_name'] as String?,
      chequeNumber:    json['cheque_number'] as String?,
      chequeDate:      json['cheque_date'] as String?,
      chequeCleared: json['cheque_cleared'] as bool?,           // Add this
      chequeClearedDate: json['cheque_cleared_date'] != null
          ? DateTime.parse(json['cheque_cleared_date'] as String)
          : null,
    );
  }
}

class LedgerSummary {
  final double totalDebit;
  final double totalCredit;
  final double closingBalance;

  LedgerSummary({
    required this.totalDebit,
    required this.totalCredit,
    required this.closingBalance,
  });

  Map<String, dynamic> toJson() {
    return {
      'total_debit': totalDebit,
      'total_credit': totalCredit,
      'closing_balance': closingBalance,
    };
  }

  factory LedgerSummary.fromJson(Map<String, dynamic> json) {
    return LedgerSummary(
      totalDebit: double.tryParse(json['total_debit'].toString()) ?? 0.0,
      totalCredit: double.tryParse(json['total_credit'].toString()) ?? 0.0,
      closingBalance: double.tryParse(json['closing_balance'].toString()) ?? 0.0,
    );
  }
}

class SupplierLedgerProvider with ChangeNotifier {
  List<LedgerEntry> _entries = [];
  LedgerSummary? _summary;
  bool _isLoading = false;
  String _error = '';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  List<LedgerEntry> get entries => _entries;
  LedgerSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  bool get hasMorePages => _currentPage < _totalPages;



  String? _getToken(BuildContext context) {
    try {
      return Provider.of<AuthProvider>(context, listen: false).user?.token;
    } catch (e) {
      return null;
    }
  }

  Map<String, String> _getHeaders(BuildContext context) {
    final token = _getToken(context);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> fetchLedger({
    required BuildContext context,
    required int supplierId,
    int page = 1,
    int limit = 50,  // Add this parameter with default value
    String? fromDate,
    String? toDate,
    String? referenceType,
    bool showUnclearedCheques = false,  // Add this parameter
    String sortBy = 'transaction_date',   // ADD
    String sortOrder = 'asc',             // ADD
  }) async {
    if (page == 1) {
      _entries = [];
    }
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      String url =
          '${ApiConfig.baseUrl}/suppliers/$supplierId/ledger?page=$page&limit=50';
      if (fromDate != null) url += '&from_date=$fromDate';
      if (toDate != null) url += '&to_date=$toDate';
      if (referenceType != null && referenceType != 'all')
        url += '&reference_type=$referenceType';
        url += '&sort_by=$sortBy&sort_order=$sortOrder';   // ADD

      // Add this parameter
      url += '&show_uncleared_cheques=$showUnclearedCheques';
      url += '&sort_by=$sortBy&sort_order=$sortOrder';

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(context),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final d = data['data'];
          final fetched = (d['entries'] as List)
              .map((e) => LedgerEntry.fromJson(e))
              .toList();

          if (page == 1) {
            _entries = fetched;
          } else {
            _entries.addAll(fetched);
          }

          _summary = LedgerSummary.fromJson(d['summary']);
          _currentPage = d['pagination']['page'];
          _totalPages = d['pagination']['pages'];
          _totalItems = d['pagination']['total'];
        }
      } else {
        _error = 'Failed to load ledger: ${response.statusCode}';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> addManualEntry({
    required BuildContext context,
    required int supplierId,
    required double debit,
    required double credit,
    required String description,
    String? referenceNumber,
    DateTime? transactionDate,
  }) async {
    try {
      final url = '${ApiConfig.baseUrl}/suppliers/$supplierId/ledger';
      final response = await http.post(
        Uri.parse(url),
        headers: _getHeaders(context),
        body: json.encode({
          'debit': debit,
          'credit': credit,
          'description': description,
          'reference_number': referenceNumber,
          'transaction_date':
          (transactionDate ?? DateTime.now()).toIso8601String(),
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 201 && data['success']) {
        // Refresh ledger
        await fetchLedger(context: context, supplierId: supplierId);
        return {'success': true, 'message': 'Entry added successfully'};
      } else {
        throw Exception(data['message'] ?? 'Failed to add entry');
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  void clear() {
    _entries = [];
    _summary = null;
    _currentPage = 1;
    _totalPages = 1;
    _totalItems = 0;
    _error = '';
    notifyListeners();
  }
}
