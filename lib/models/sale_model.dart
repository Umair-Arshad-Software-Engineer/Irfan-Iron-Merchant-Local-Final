// lib/models/sale_model.dart
import 'dart:convert';
import 'package:flutter/material.dart';

// lib/models/sale_type.dart
enum SaleType {
  sarya,   // Weight-based calculation
  filled,  // Piece-based calculation
}

extension SaleTypeExtension on SaleType {
  String get displayName {
    switch (this) {
      case SaleType.sarya:
        return 'SARYA (Weight)';
      case SaleType.filled:
        return 'FILLED (Pieces)';
    }
  }

  String get apiValue {
    switch (this) {
      case SaleType.sarya:
        return 'sarya';
      case SaleType.filled:
        return 'filled';
    }
  }

  String get unitLabel {
    switch (this) {
      case SaleType.sarya:
        return 'Kg';
      case SaleType.filled:
        return 'Pieces';
    }
  }
}

class SaleModel {
  final int id;
  final String invoiceNumber;
  final String saleType;
  final int? customerId;
  final CustomerInfo? customer;
  final DateTime saleDate;
  final DateTime? dueDate;
  final double subtotal;
  final String discountType;
  final double discountValue;
  final double discountAmount;
  final double taxAmount;
  final double grandTotal;
  final double amountPaid;
  final double changeAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String? notes;
  final List<SaleItemModel>? items;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reference;
  final String saleCategory;

  // Payment details fields
  final Map<String, dynamic>? paymentDetails;
  final double? paidAmount;
  final double? remainingAmount;

  // Balance fields
  final double? previousBalance;  // Balance before this sale (excluded current sale)
  final double? customerBalance;  // Customer's total balance (including this sale)

  SaleModel({
    required this.id,
    required this.invoiceNumber,
    required this.saleType,
    this.customerId,
    this.customer,
    required this.saleDate,
    this.dueDate,
    required this.subtotal,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.taxAmount,
    required this.grandTotal,
    required this.amountPaid,
    required this.changeAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    this.notes,
    this.items,
    required this.createdAt,
    required this.updatedAt,
    this.reference,
    required this.saleCategory,
    this.paymentDetails,
    this.paidAmount,
    this.remainingAmount,
    this.previousBalance,
    this.customerBalance,
  });

  double get outstandingBalance => grandTotal - amountPaid;
  bool get isFullyPaid => paymentStatus == 'paid';
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now()) && !isFullyPaid;

  // // Helper method to get payment method totals
  // Map<String, double> get paymentMethodTotals {
  //   final Map<String, double> totals = {};
  //
  //   if (paymentDetails != null && paymentDetails!.isNotEmpty) {
  //     // Check for payment details from API
  //     final details = paymentDetails!;
  //
  //     if (details['cash'] != null) {
  //       totals['cash'] = _toDouble(details['cash']);
  //     }
  //     if (details['online'] != null) {
  //       totals['online'] = _toDouble(details['online']);
  //     }
  //     if (details['check'] != null) {
  //       totals['check'] = _toDouble(details['check']);
  //     }
  //     if (details['bank'] != null) {
  //       totals['bank'] = _toDouble(details['bank']);
  //     }
  //     if (details['slip'] != null) {
  //       totals['slip'] = _toDouble(details['slip']);
  //     }
  //     if (details['credit'] != null) {
  //       totals['credit'] = _toDouble(details['credit']);
  //     }
  //   } else if (paymentMethod == 'cash' || paymentMethod == 'credit') {
  //     // Fallback: use paymentMethod for single payment
  //     totals[paymentMethod] = amountPaid > 0 ? amountPaid : grandTotal;
  //   }
  //
  //   return totals;
  // }

  // Helper method to check if payment details exist

  Map<String, double> get paymentMethodTotals {
    final Map<String, double> totals = {};
    const allMethods = ['cash', 'online', 'check', 'bank', 'slip', 'credit'];

    if (paymentDetails != null && paymentDetails!.isNotEmpty) {
      for (final key in allMethods) {
        // Check both exact key and capitalized variants
        final val = paymentDetails![key]
            ?? paymentDetails![key.toUpperCase()]
            ?? paymentDetails![key[0].toUpperCase() + key.substring(1)];
        final amount = _toDouble(val);
        if (amount > 0) totals[key] = amount;
      }

      // If paymentDetails existed but none of our keys matched,
      // dump all entries so nothing is silently lost
      if (totals.isEmpty) {
        for (final entry in paymentDetails!.entries) {
          final amount = _toDouble(entry.value);
          if (amount > 0) totals[entry.key.toLowerCase()] = amount;
        }
      }
    } else {
      // Fallback only for single-method sales
      final method = paymentMethod.toLowerCase();
      final amount = _toDouble(paidAmount ?? amountPaid);
      if (amount > 0) totals[method] = amount;
    }

    return totals;
  }

  bool get hasPaymentDetails => paymentDetails != null && paymentDetails!.isNotEmpty;

  // ============ BALANCE GETTERS ============

  // Get previous balance (default to 0 if null)
  double get previousBalanceValue => previousBalance ?? 0.0;

  // Get customer balance (default to 0 if null)
  double get customerBalanceValue => customerBalance ?? 0.0;

  // Get total with previous balance (Grand Total + Previous Balance)
  double get totalWithPrevious => grandTotal + previousBalanceValue;

  // Get paid amount (use paidAmount if available, otherwise amountPaid)
  double get paidAmountValue => paidAmount ?? amountPaid;

  // Get remaining amount
  double get remainingAmountValue => remainingAmount ?? (grandTotal - paidAmountValue);

  // Get total balance (previous balance + remaining)
  double get totalBalance => previousBalanceValue + remainingAmountValue;

  // Check if customer has any balance
  bool get hasBalance => customerBalanceValue != 0 || previousBalanceValue != 0;

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }

  Color get statusColor {
    switch (paymentStatus) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'unpaid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    debugPrint('==========================================');
    debugPrint('SALE: ${json['invoice_number']}');
    debugPrint('payment_method: ${json['payment_method']}');
    debugPrint('payment_details: ${json['payment_details']}');
    debugPrint('amount_paid: ${json['amount_paid']}');
    debugPrint('paid_amount: ${json['paid_amount']}');
    debugPrint('==========================================');
    // Helper function to safely convert to double
    double toDoubleSafe(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          debugPrint('Error parsing double from string: $value');
          return 0.0;
        }
      }
      return 0.0;
    }

    // Helper function to safely parse date
    DateTime parseDateSafe(String? dateStr) {
      if (dateStr == null) return DateTime.now();
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        debugPrint('Error parsing date: $dateStr');
        return DateTime.now();
      }
    }

    // Helper to parse payment details
    // Map<String, dynamic>? parsePaymentDetails(dynamic details) {
    //   if (details == null) return null;
    //   if (details is Map) {
    //     return Map<String, dynamic>.from(details);
    //   }
    //   if (details is String && details.isNotEmpty) {
    //     try {
    //       final decoded = jsonDecode(details);
    //       if (decoded is Map) {
    //         return Map<String, dynamic>.from(decoded);
    //       }
    //     } catch (_) {}
    //   }
    //   return null;
    // }
    Map<String, dynamic>? parsePaymentDetails(dynamic details) {
      if (details == null) return null;

      // Already a map
      if (details is Map) {
        return Map<String, dynamic>.from(details);
      }

      // JSON string — try decoding once
      if (details is String && details.isNotEmpty) {
        try {
          var decoded = jsonDecode(details);
          // Handle double-encoded strings
          if (decoded is String) {
            decoded = jsonDecode(decoded);
          }
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('parsePaymentDetails error: $e, raw: $details');
        }
      }
      return null;
    }

    return SaleModel(
      id: json['id'] ?? 0,
      invoiceNumber: json['invoice_number'] ?? '',
      saleType: json['sale_type'] ?? 'pos',
      customerId: json['customer_id'],
      customer: json['customer'] != null ? CustomerInfo.fromJson(json['customer']) : null,
      saleDate: parseDateSafe(json['sale_date']),
      dueDate: json['due_date'] != null ? parseDateSafe(json['due_date']) : null,
      subtotal: toDoubleSafe(json['subtotal']),
      discountType: json['discount_type'] ?? 'fixed',
      discountValue: toDoubleSafe(json['discount_value']),
      discountAmount: toDoubleSafe(json['discount_amount']),
      taxAmount: toDoubleSafe(json['tax_amount']),
      grandTotal: toDoubleSafe(json['grand_total']),
      amountPaid: toDoubleSafe(json['amount_paid']),
      changeAmount: toDoubleSafe(json['change_amount']),
      paymentMethod: json['payment_method'] ?? 'cash',
      paymentStatus: json['payment_status'] ?? 'unpaid',
      notes: json['notes'],
      items: json['items'] != null
          ? (json['items'] as List).map((e) => SaleItemModel.fromJson(e)).toList()
          : null,
      createdAt: parseDateSafe(json['created_at']),
      updatedAt: parseDateSafe(json['updated_at']),
      reference: json['reference'],
      saleCategory: json['sale_category'] ?? 'filled',

      // Payment details fields
      paymentDetails: parsePaymentDetails(json['payment_details']),
      paidAmount: toDoubleSafe(json['paid_amount'] ?? json['amount_paid']),
      remainingAmount: toDoubleSafe(json['remaining_amount'] ?? (toDoubleSafe(json['grand_total']) - toDoubleSafe(json['amount_paid']))),

      // Balance fields
      previousBalance: json['previous_balance'] != null
          ? toDoubleSafe(json['previous_balance'])
          : null,
      customerBalance: json['customer_balance'] != null
          ? toDoubleSafe(json['customer_balance'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'sale_type': saleType,
      'customer_id': customerId,
      'sale_date': saleDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'subtotal': subtotal,
      'discount_type': discountType,
      'discount_value': discountValue,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'grand_total': grandTotal,
      'amount_paid': amountPaid,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'notes': notes,
      'reference': reference,
      'sale_category': saleCategory,
      'payment_details': paymentDetails,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'previous_balance': previousBalance,
      'customer_balance': customerBalance,
    };
  }
}

class CustomerInfo {
  final int id;
  final String name;
  final String? contact;
  final String? address;
  final String? email;
  final String customerType;
  final double discountPercent;
  final double? balance;  // Customer's total balance from Customer model

  CustomerInfo({
    required this.id,
    required this.name,
    this.contact,
    this.address,
    this.email,
    required this.customerType,
    this.discountPercent = 0.0,
    this.balance,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    double toDoubleSafe(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return CustomerInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      contact: json['contact'],
      address: json['address'],
      email: json['email'],
      customerType: json['customer_type'] ?? 'regular',
      discountPercent: toDoubleSafe(json['discount_percent']),
      balance: toDoubleSafe(json['balance']),
    );
  }
}

class SaleItemModel {
  final int id;
  final int? productId;
  final String productName;
  final String? description;
  final String? barcode;
  final double unitPrice;
  final int quantity;
  final double totalPrice;
  final ProductInfo? product;
  final bool usedCustomerPrice;
  final List<String>? selectedLengths;
  final Map<String, dynamic>? lengthQuantities;
  final String? selectedLengthsDisplay;
  final int? totalPieces;
  final double? weight;

  SaleItemModel({
    required this.id,
    this.productId,
    required this.productName,
    this.description,
    this.barcode,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
    this.product,
    this.usedCustomerPrice = false,
    this.selectedLengths,
    this.lengthQuantities,
    this.selectedLengthsDisplay,
    this.totalPieces,
    this.weight,
  });

  bool get hasLengthCombinations =>
      selectedLengths != null && selectedLengths!.isNotEmpty;

  // Helper to get lengths with quantities as a list
  List<Map<String, dynamic>> get lengthsWithQuantities {
    final List<Map<String, dynamic>> result = [];

    if (lengthQuantities != null && lengthQuantities!.isNotEmpty && selectedLengths != null) {
      for (var length in selectedLengths!) {
        final qty = (lengthQuantities![length] as num?)?.toDouble() ?? 1.0;
        result.add({'length': length, 'qty': qty});
      }
    } else if (selectedLengths != null && selectedLengths!.isNotEmpty) {
      for (var length in selectedLengths!) {
        result.add({'length': length, 'qty': 1.0});
      }
    } else if (selectedLengthsDisplay != null && selectedLengthsDisplay!.isNotEmpty) {
      // Parse from display string
      final parts = selectedLengthsDisplay!.split(',');
      for (var part in parts) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) {
          double qty = 1.0;
          String length = trimmed;
          // Check for quantity in parentheses
          final qtyMatch = RegExp(r'\((\d+(\.\d+)?)\)').firstMatch(trimmed);
          if (qtyMatch != null) {
            qty = double.tryParse(qtyMatch.group(1) ?? '1') ?? 1.0;
            length = trimmed.substring(0, trimmed.indexOf('(')).trim();
          }
          result.add({'length': length, 'qty': qty});
        }
      }
    }

    return result;
  }

  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    double toDoubleSafe(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try { return double.parse(value); } catch (_) { return 0.0; }
      }
      return 0.0;
    }

    List<String>? parsedLengths;
    final rawLengths = json['selected_lengths'];
    if (rawLengths is List) {
      parsedLengths = rawLengths.map((e) => e.toString()).toList();
    } else if (rawLengths is String && rawLengths.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawLengths);
        if (decoded is List) parsedLengths = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    Map<String, dynamic>? parsedQtys;
    final rawQtys = json['length_quantities'];
    if (rawQtys is Map) {
      parsedQtys = Map<String, dynamic>.from(rawQtys);
    } else if (rawQtys is String && rawQtys.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawQtys);
        if (decoded is Map) parsedQtys = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    return SaleItemModel(
      id: json['id'] ?? 0,
      productId: json['product_id'],
      productName: json['product_name'] ?? '',
      description: json['description'],
      barcode: json['barcode'],
      unitPrice: toDoubleSafe(json['unit_price']),
      quantity: json['quantity'] ?? 0,
      totalPrice: toDoubleSafe(json['total_price']),
      product: json['product'] != null ? ProductInfo.fromJson(json['product']) : null,
      usedCustomerPrice: json['used_customer_price'] == true,
      selectedLengths: parsedLengths,
      lengthQuantities: parsedQtys,
      selectedLengthsDisplay: json['selected_lengths_display'],
      totalPieces: json['total_pieces'],
      weight: toDoubleSafe(json['weight']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'description': description,
      'barcode': barcode,
      'unit_price': unitPrice,
      'quantity': quantity,
      'total_price': totalPrice,
      'used_customer_price': usedCustomerPrice,
      'selected_lengths': selectedLengths,
      'length_quantities': lengthQuantities,
      'selected_lengths_display': selectedLengthsDisplay,
      'total_pieces': totalPieces,
      'weight': weight,
    };
  }
}

class ProductInfo {
  final int id;
  final String itemName;
  final String? barcode;
  final UnitInfo? unit;

  ProductInfo({
    required this.id,
    required this.itemName,
    this.barcode,
    this.unit,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      id: json['id'] ?? 0,
      itemName: json['item_name'] ?? '',
      barcode: json['barcode'],
      unit: json['unit'] != null ? UnitInfo.fromJson(json['unit']) : null,
    );
  }
}

class UnitInfo {
  final int id;
  final String name;
  final String symbol;

  UnitInfo({
    required this.id,
    required this.name,
    required this.symbol,
  });

  factory UnitInfo.fromJson(Map<String, dynamic> json) {
    return UnitInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
    );
  }
}