// lib/models/product_model.dart
import 'dart:convert';

class ProductModel {
  final int id;
  final String itemName;
  final String? description;
  final double costPrice;
  final double salePrice;
  final int? supplierId;
  final int categoryId;
  final int? subcategoryId;
  final int unitId;
  final String? barcode;
  final int minStock;
  final int physicalQty;
  final int availableQty;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Sale type: 'sarya' (weight-based) or 'filled' (piece-based)
  final String saleType;

  // Length combination fields
  final List<LengthCombination>? lengthCombinations;
  final bool hasMultipleLengths;

  // Related models
  final SupplierInfo? supplier;
  final CategoryInfo? category;
  final SubcategoryInfo? subcategory;
  final UnitInfo? unit;
  final List<CustomerPriceInfo>? customerPrices;

  // BOM fields
  final bool isBom;
  final List<BomComponent>? bomComponents;
  final double? bomTotalCost;

  ProductModel({
    required this.id,
    required this.itemName,
    this.description,
    required this.costPrice,
    required this.salePrice,
    this.supplierId,
    required this.categoryId,
    this.subcategoryId,
    required this.unitId,
    this.barcode,
    required this.minStock,
    required this.physicalQty,
    required this.availableQty,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.saleType = 'filled', // Default to 'filled'
    this.lengthCombinations,
    this.hasMultipleLengths = false,
    this.supplier,
    this.category,
    this.subcategory,
    this.unit,
    this.customerPrices,
    this.isBom = false,
    this.bomComponents,
    this.bomTotalCost,
  });

  // Helper getters for sale type
  bool get isSaryaType => saleType == 'sarya';
  bool get isFilledType => saleType == 'filled';

  String get saleTypeDisplayName {
    switch (saleType) {
      case 'sarya':
        return 'SARYA (Weight)';
      case 'filled':
        return 'FILLED (Pieces)';
      default:
        return 'Unknown';
    }
  }

  String get calculationUnit => isSaryaType ? 'Kg' : 'Pieces';

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id:           json['id'],
      itemName:     json['item_name'] ?? '',
      description:  json['description'],
      costPrice:    double.tryParse(json['cost_price']?.toString() ?? '0') ?? 0.0,
      salePrice:    double.tryParse(json['sale_price']?.toString() ?? '0') ?? 0.0,
      supplierId:   json['supplier_id'],
      categoryId:   json['category_id'] ?? 0,
      subcategoryId: json['subcategory_id'],
      unitId:       json['unit_id'] ?? 0,
      barcode:      json['barcode'],
      minStock:     json['min_stock'] ?? 0,
      physicalQty:  json['physical_qty'] ?? 0,
      availableQty: json['available_qty'] ?? 0,
      isActive:     json['is_active'] ?? true,
      createdAt:    json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt:    json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      saleType:     json['sale_type'] ?? 'filled', // Parse sale_type from API
      // Parse length combinations from JSON array
      lengthCombinations: () {
        final raw = json['length_combinations'];
        if (raw == null) return null;
        // API may return a JSON string instead of a List — decode it first
        final List<dynamic> list = raw is String ? jsonDecode(raw) : raw as List<dynamic>;
        return list
            .map((e) => LengthCombination.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }(),
      hasMultipleLengths: json['has_multiple_lengths'] ?? false,
      supplier:     json['supplier']     != null ? SupplierInfo.fromJson(json['supplier'])         : null,
      category:     json['category']     != null ? CategoryInfo.fromJson(json['category'])         : null,
      subcategory:  json['subcategory']  != null ? SubcategoryInfo.fromJson(json['subcategory'])   : null,
      unit:         json['unit']         != null ? UnitInfo.fromJson(json['unit'])                 : null,
      customerPrices: json['customerPrices'] != null
          ? (json['customerPrices'] as List)
          .map((e) => CustomerPriceInfo.fromJson(e))
          .toList()
          : null,
      isBom: json['is_bom'] ?? false,
      bomComponents: json['bom_components'] != null
          ? (json['bom_components'] as List)
          .map((e) => BomComponent.fromJson(e))
          .toList()
          : null,
      bomTotalCost: json['bom_total_cost'] != null
          ? double.tryParse(json['bom_total_cost'].toString())
          : null,
    );
  }

  ProductModel copyWith({
    int? id,
    String? itemName,
    String? description,
    double? costPrice,
    double? salePrice,
    int? supplierId,
    int? categoryId,
    int? subcategoryId,
    int? unitId,
    String? barcode,
    int? minStock,
    int? physicalQty,
    int? availableQty,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? saleType,
    List<LengthCombination>? lengthCombinations,
    bool? hasMultipleLengths,
    SupplierInfo? supplier,
    CategoryInfo? category,
    SubcategoryInfo? subcategory,
    UnitInfo? unit,
    List<CustomerPriceInfo>? customerPrices,
  }) {
    return ProductModel(
      id:                  id                  ?? this.id,
      itemName:            itemName            ?? this.itemName,
      description:         description         ?? this.description,
      costPrice:           costPrice           ?? this.costPrice,
      salePrice:           salePrice           ?? this.salePrice,
      supplierId:          supplierId          ?? this.supplierId,
      categoryId:          categoryId          ?? this.categoryId,
      subcategoryId:       subcategoryId       ?? this.subcategoryId,
      unitId:              unitId              ?? this.unitId,
      barcode:             barcode             ?? this.barcode,
      minStock:            minStock            ?? this.minStock,
      physicalQty:         physicalQty         ?? this.physicalQty,
      availableQty:        availableQty        ?? this.availableQty,
      isActive:            isActive            ?? this.isActive,
      createdAt:           createdAt           ?? this.createdAt,
      updatedAt:           updatedAt           ?? this.updatedAt,
      saleType:            saleType            ?? this.saleType,
      lengthCombinations:  lengthCombinations  ?? this.lengthCombinations,
      hasMultipleLengths:  hasMultipleLengths  ?? this.hasMultipleLengths,
      supplier:            supplier            ?? this.supplier,
      category:            category            ?? this.category,
      subcategory:         subcategory         ?? this.subcategory,
      unit:                unit                ?? this.unit,
      customerPrices:      customerPrices      ?? this.customerPrices,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_name':            itemName,
      'description':          description,
      'cost_price':           costPrice,
      'sale_price':           salePrice,
      'supplier_id':          supplierId,
      'category_id':          categoryId,
      'subcategory_id':       subcategoryId,
      'unit_id':              unitId,
      'barcode':              barcode,
      'min_stock':            minStock,
      'physical_qty':         physicalQty,
      'sale_type':            saleType,
      'length_combinations':  lengthCombinations?.map((c) => c.toJson()).toList(),
      'has_multiple_lengths': hasMultipleLengths,
      'is_bom': isBom,
      'bom_components': bomComponents?.map((c) => c.toJson()).toList(),
      'bom_total_cost': bomTotalCost,
    };
  }
}


class BomComponent {
  final String id;
  final int productId;
  final String productName;
  final double quantity;
  final String unit;
  final double costPerUnit;
  final double totalCost;
  final String? notes;

  BomComponent({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.costPerUnit,
    required this.totalCost,
    this.notes,
  });

  factory BomComponent.fromJson(Map<String, dynamic> json) {
    return BomComponent(
      id: json['id']?.toString() ?? '',
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      unit: json['unit'] ?? 'Pcs',
      costPerUnit: double.tryParse(json['cost_per_unit']?.toString() ?? '0') ?? 0,
      totalCost: double.tryParse(json['total_cost']?.toString() ?? '0') ?? 0,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'unit': unit,
    'cost_per_unit': costPerUnit,
    'total_cost': totalCost,
    'notes': notes,
  };
}


// ─────────────────────────────────────────────
// LengthCombination — mirrors LengthBodyCombination from the screen
// ─────────────────────────────────────────────

class LengthCombination {
  final String id;
  final String length;
  final String lengthDecimal;

  const LengthCombination({
    required this.id,
    required this.length,
    required this.lengthDecimal,
  });

  factory LengthCombination.fromJson(Map<String, dynamic> json) {
    return LengthCombination(
      id:            json['id']?.toString()            ?? '',
      length:        json['length']?.toString()        ?? '',
      lengthDecimal: json['lengthDecimal']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id':            id,
    'length':        length,
    'lengthDecimal': lengthDecimal,
  };
}

// ─────────────────────────────────────────────
// Supporting info classes (unchanged)
// ─────────────────────────────────────────────

class SupplierInfo {
  final int id;
  final String name;
  final String? contact;

  SupplierInfo({required this.id, required this.name, this.contact});

  factory SupplierInfo.fromJson(Map<String, dynamic> json) => SupplierInfo(
    id:      json['id'],
    name:    json['name'],
    contact: json['contact'],
  );
}

class CategoryInfo {
  final int id;
  final String name;

  CategoryInfo({required this.id, required this.name});

  factory CategoryInfo.fromJson(Map<String, dynamic> json) =>
      CategoryInfo(id: json['id'], name: json['name']);
}

class SubcategoryInfo {
  final int id;
  final String name;

  SubcategoryInfo({required this.id, required this.name});

  factory SubcategoryInfo.fromJson(Map<String, dynamic> json) =>
      SubcategoryInfo(id: json['id'], name: json['name']);
}

class UnitInfo {
  final int id;
  final String name;
  final String symbol;

  UnitInfo({required this.id, required this.name, required this.symbol});

  factory UnitInfo.fromJson(Map<String, dynamic> json) =>
      UnitInfo(id: json['id'], name: json['name'], symbol: json['symbol']);
}

class CustomerPriceInfo {
  final int id;
  final int productId;
  final int customerId;
  final double price;
  final bool isActive;
  final CustomerInfo? customer;

  CustomerPriceInfo({
    required this.id,
    required this.productId,
    required this.customerId,
    required this.price,
    required this.isActive,
    this.customer,
  });

  factory CustomerPriceInfo.fromJson(Map<String, dynamic> json) =>
      CustomerPriceInfo(
        id:         json['id'],
        productId:  json['product_id'],
        customerId: json['customer_id'],
        price:      double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
        isActive:   json['is_active'] ?? true,
        customer:   json['customer'] != null
            ? CustomerInfo.fromJson(json['customer'])
            : null,
      );
}

class CustomerInfo {
  final int id;
  final String name;
  final String customerType;

  CustomerInfo({
    required this.id,
    required this.name,
    required this.customerType,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) => CustomerInfo(
    id:           json['id'],
    name:         json['name'],
    customerType: json['customer_type'],
  );
}