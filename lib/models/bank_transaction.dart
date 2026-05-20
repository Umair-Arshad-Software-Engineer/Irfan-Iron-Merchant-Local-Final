// lib/models/bank_transaction.dart
class BankTransaction {
  final int id;
  final int bankId;
  final String type;
  final double amount;
  final String description;
  final String? referenceNumber;
  final double balanceAfter;
  final int? createdBy;
  final DateTime timestamp;

  BankTransaction({
    required this.id,
    required this.bankId,
    required this.type,
    required this.amount,
    required this.description,
    this.referenceNumber,
    required this.balanceAfter,
    this.createdBy,
    required this.timestamp,
  });

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool get isFromSupplier {
    final desc = description.toLowerCase();
    return desc.contains('supplier') ||
        desc.contains('purchase') ||
        desc.contains('payment to') ||
        desc.contains('bill payment') ||
        desc.contains('bank transfer to') ||      // ← add this
        desc.contains('cheque payment to') ||     // ← add this
        desc.contains('reversal of payment to');  // ← add this
  }
  factory BankTransaction.fromJson(Map<String, dynamic> json) => BankTransaction(
    id: _parseInt(json['id']),
    bankId: _parseInt(json['bank_id']),
    type: json['transaction_type'] ?? 'in',
    amount: _parseDouble(json['amount']),
    description: json['description'] ?? '',
    referenceNumber: json['reference_number'],
    balanceAfter: _parseDouble(json['balance_after']),
    createdBy: json['created_by'] != null ? _parseInt(json['created_by']) : null,
    timestamp: json['transaction_date'] != null
        ? DateTime.parse(json['transaction_date'])
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bank_id': bankId,
    'transaction_type': type,
    'amount': amount,
    'description': description,
    'reference_number': referenceNumber,
    'balance_after': balanceAfter,
    'created_by': createdBy,
    'transaction_date': timestamp.toIso8601String(),
  };
}