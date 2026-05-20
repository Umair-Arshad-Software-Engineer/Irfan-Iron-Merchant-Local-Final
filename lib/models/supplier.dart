// models/supplier.dart - Updated without Product
import 'package:flutter/foundation.dart';

class Supplier {
  final int id;
  final String name;
  final String contact;
  final String? address;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double discountPercent;
  Supplier({
    required this.id,
    required this.name,
    required this.contact,
    this.address,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.discountPercent,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      contact: json['contact'] ?? '',
      address: json['address'],
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      discountPercent: double.tryParse(json['discount_percent']?.toString() ?? '0') ?? 0.0,
    );
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? contact,
    String? address,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? discountPercent,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      discountPercent: discountPercent ?? this.discountPercent,

    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contact': contact,
      'address': address,
      'is_active': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'discount_percent': discountPercent,
    };
  }
}