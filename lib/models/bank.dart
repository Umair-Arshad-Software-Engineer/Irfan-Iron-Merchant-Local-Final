// lib/models/bank.dart

class Bank {
  final int id;
  final String name;
  final String iconPath;
  final double balance;
  final bool isActive;
  final String? accountNumber;
  final String? branchCode;
  final String? swiftCode;
  final String? iban;
  final DateTime createdAt;
  final DateTime updatedAt;

  Bank({
    required this.id,
    required this.name,
    required this.iconPath,
    required this.balance,
    this.isActive = true,
    this.accountNumber,
    this.branchCode,
    this.swiftCode,
    this.iban,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Bank.fromJson(Map<String, dynamic> json) {
    return Bank(
      id: json['id'] as int,
      name: json['name'] as String,
      iconPath: json['icon_path'] as String? ?? 'asset/bank_icons/default.png',

      // ← THIS IS THE FIX: safely parse balance whether it's String, int, or double
      balance: _parseDouble(json['balance']),

      isActive: json['is_active'] as bool? ?? true,
      accountNumber: json['account_number'] as String?,
      branchCode: json['branch_code'] as String?,
      swiftCode: json['swift_code'] as String?,
      iban: json['iban'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  // Safe parser that handles String, int, double, and null
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon_path': iconPath,
      'balance': balance,
      'is_active': isActive,
      'account_number': accountNumber,
      'branch_code': branchCode,
      'swift_code': swiftCode,
      'iban': iban,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}