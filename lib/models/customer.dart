// lib/models/customer.dart
import 'package:flutter/foundation.dart';

class Customer {
  final int id;
  final String name;
  final String contact;
  final String? address;
  final String? email;
  final String customerType;
  final double balance;
  final double discountPercent; // ← NEW: customer-level discount (0–100)
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.name,
    required this.contact,
    this.address,
    this.email,
    required this.customerType,
    required this.balance,
    this.discountPercent = 0.0, // defaults to no discount
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id:              json['id'] ?? 0,
      name:            json['name'] ?? '',
      contact:         json['contact'] ?? '',
      address:         json['address'],
      email:           json['email'],
      customerType:    json['customer_type'] ?? 'regular',
      balance:         _parseDouble(json['balance']),
      discountPercent: _parseDouble(json['discount_percent']),
      isActive:        json['is_active'] ?? json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int)    return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Customer copyWith({
    int? id,
    String? name,
    String? contact,
    String? address,
    String? email,
    String? customerType,
    double? balance,
    double? discountPercent,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id:              id              ?? this.id,
      name:            name            ?? this.name,
      contact:         contact         ?? this.contact,
      address:         address         ?? this.address,
      email:           email           ?? this.email,
      customerType:    customerType    ?? this.customerType,
      balance:         balance         ?? this.balance,
      discountPercent: discountPercent ?? this.discountPercent,
      isActive:        isActive        ?? this.isActive,
      createdAt:       createdAt       ?? this.createdAt,
      updatedAt:       updatedAt       ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':               id,
      'name':             name,
      'contact':          contact,
      'address':          address,
      'email':            email,
      'customer_type':    customerType,
      'balance':          balance,
      'discount_percent': discountPercent,
      'is_active':        isActive,
      'createdAt':        createdAt.toIso8601String(),
      'updatedAt':        updatedAt.toIso8601String(),
    };
  }

  String get formattedBalance => '${balance.toStringAsFixed(2)}';

  /// True when this customer has a non-zero discount configured.
  bool get hasDiscount => discountPercent > 0;

  String get discountLabel => '${discountPercent.toStringAsFixed(discountPercent % 1 == 0 ? 0 : 1)}% off';

  String get typeLabel => customerType == 'wholesale'
      ? 'Wholesale'
      : customerType == 'retail'
      ? 'Retail'
      : 'Regular';
}