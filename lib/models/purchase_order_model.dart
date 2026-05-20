import 'package:flutter/material.dart';

// Helper function to safely parse doubles
double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

// Helper function to safely parse ints
int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

class PurchaseOrderModel {
  final int id;
  final String poNumber;
  final int supplierId;
  final DateTime orderDate;
  final DateTime? expectedDeliveryDate;
  final DateTime? deliveryDate;
  final String status;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double shippingCost;
  final double totalAmount;
  final String? notes;
  final String? termsConditions;
  final String? paymentTerms;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations
  final SupplierInfo? supplier;
  final List<PurchaseOrderItemModel>? items;
  final List<PurchaseReceiptModel>? receipts;

  PurchaseOrderModel({
    required this.id,
    required this.poNumber,
    required this.supplierId,
    required this.orderDate,
    this.expectedDeliveryDate,
    this.deliveryDate,
    required this.status,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.shippingCost,
    required this.totalAmount,
    this.notes,
    this.termsConditions,
    this.paymentTerms,
    required this.createdAt,
    required this.updatedAt,
    this.supplier,
    this.items,
    this.receipts,
  });

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderModel(
      id: _toInt(json['id']),
      poNumber: json['po_number'] ?? '',
      supplierId: _toInt(json['supplier_id']),
      orderDate: json['order_date'] != null
          ? DateTime.parse(json['order_date'])
          : DateTime.now(),
      expectedDeliveryDate: json['expected_delivery_date'] != null
          ? DateTime.parse(json['expected_delivery_date'])
          : null,
      deliveryDate: json['delivery_date'] != null
          ? DateTime.parse(json['delivery_date'])
          : null,
      status: json['status'] ?? 'draft',
      subtotal: _toDouble(json['subtotal']),
      taxAmount: _toDouble(json['tax_amount']),
      discountAmount: _toDouble(json['discount_amount']),
      shippingCost: _toDouble(json['shipping_cost']),
      totalAmount: _toDouble(json['total_amount']),
      notes: json['notes'],
      termsConditions: json['terms_conditions'],
      paymentTerms: json['payment_terms'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      supplier: json['supplier'] != null
          ? SupplierInfo.fromJson(json['supplier'])
          : null,
      items: json['items'] != null
          ? (json['items'] as List)
          .map((e) => PurchaseOrderItemModel.fromJson(e))
          .toList()
          : null,
      receipts: json['receipts'] != null
          ? (json['receipts'] as List)
          .map((e) => PurchaseReceiptModel.fromJson(e))
          .toList()
          : null,
    );
  }

  String get statusText {
    // If any item is over-received, show that first regardless of backend status
    if (hasOverReceivedItems) return 'Over Received';
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'ordered':
        return 'Ordered';
      case 'partial':
        return 'Partially Received';
      case 'received':
        return 'Received';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color get statusColor {
    // Mirror the over-received label with a red colour
    if (hasOverReceivedItems) return Colors.red;
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'ordered':
        return Colors.blue;
      case 'partial':
        return Colors.orange;
      case 'received':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// True if ANY item in this PO has been received more than ordered.
  bool get hasOverReceivedItems =>
      items?.any((i) => i.isOverReceived) ?? false;
}

class PurchaseOrderItemModel {
  final int id;
  final int purchaseOrderId;
  final int productId;
  final int quantityOrdered;
  final int quantityReceived;
  final double unitCost;
  final double lineTotal;
  final double discountPercent;
  final double taxPercent;
  final String? notes;

  // Relations
  final ProductInfo? product;
  final List<PurchaseReceiptItemModel>? receiptItems;

  PurchaseOrderItemModel({
    required this.id,
    required this.purchaseOrderId,
    required this.productId,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.unitCost,
    required this.lineTotal,
    required this.discountPercent,
    required this.taxPercent,
    this.notes,
    this.product,
    this.receiptItems,
  });

  factory PurchaseOrderItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItemModel(
      id: _toInt(json['id']),
      purchaseOrderId: _toInt(json['purchase_order_id']),
      productId: _toInt(json['product_id']),
      quantityOrdered: _toInt(json['quantity_ordered']),
      quantityReceived: _toInt(json['quantity_received']),
      unitCost: _toDouble(json['unit_cost']),
      lineTotal: _toDouble(json['line_total']),
      discountPercent: _toDouble(json['discount_percent']),
      taxPercent: _toDouble(json['tax_percent']),
      notes: json['notes'],
      product: json['product'] != null
          ? ProductInfo.fromJson(json['product'])
          : null,
      receiptItems: json['receiptItems'] != null
          ? (json['receiptItems'] as List)
          .map((e) => PurchaseReceiptItemModel.fromJson(e))
          .toList()
          : null,
    );
  }

  int get remainingQuantity => quantityOrdered - quantityReceived;
  bool get isFullyReceived => quantityReceived >= quantityOrdered && !isOverReceived;

  /// True when more units were received than were ordered.
  bool get isOverReceived => quantityReceived > quantityOrdered;

  /// How many units were received beyond the ordered amount (0 if not over-received).
  int get overReceivedQuantity =>
      isOverReceived ? quantityReceived - quantityOrdered : 0;
}

class PurchaseReceiptModel {
  final int id;
  final String receiptNumber;
  final int purchaseOrderId;
  final DateTime receiptDate;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double totalAmount;

  // Relations
  final PurchaseOrderModel? purchaseOrder;
  final List<PurchaseReceiptItemModel>? items;

  PurchaseReceiptModel({
    required this.id,
    required this.receiptNumber,
    required this.purchaseOrderId,
    required this.receiptDate,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.totalAmount,
    this.purchaseOrder,
    this.items,
  });

  factory PurchaseReceiptModel.fromJson(Map<String, dynamic> json) {
    return PurchaseReceiptModel(
      id: _toInt(json['id']),
      receiptNumber: json['receipt_number'] ?? '',
      purchaseOrderId: _toInt(json['purchase_order_id']),
      receiptDate: json['receipt_date'] != null
          ? DateTime.parse(json['receipt_date'])
          : DateTime.now(),
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      totalAmount: _toDouble(json['total_amount']),
      purchaseOrder: json['purchaseOrder'] != null
          ? PurchaseOrderModel.fromJson(json['purchaseOrder'])
          : null,
      items: json['items'] != null
          ? (json['items'] as List)
          .map((e) => PurchaseReceiptItemModel.fromJson(e))
          .toList()
          : null,
    );
  }
}

class PurchaseReceiptItemModel {
  final int id;
  final int purchaseReceiptId;
  final int purchaseOrderItemId;
  final int productId;
  final int quantityReceived;
  final double unitCost;
  final String? batchNumber;
  final DateTime? expiryDate;
  final String? notes;

  // Relations
  final ProductInfo? product;

  PurchaseReceiptItemModel({
    required this.id,
    required this.purchaseReceiptId,
    required this.purchaseOrderItemId,
    required this.productId,
    required this.quantityReceived,
    required this.unitCost,
    this.batchNumber,
    this.expiryDate,
    this.notes,
    this.product,
  });

  factory PurchaseReceiptItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseReceiptItemModel(
      id: _toInt(json['id']),
      purchaseReceiptId: _toInt(json['purchase_receipt_id']),
      purchaseOrderItemId: _toInt(json['purchase_order_item_id']),
      productId: _toInt(json['product_id']),
      quantityReceived: _toInt(json['quantity_received']),
      unitCost: _toDouble(json['unit_cost']),
      batchNumber: json['batch_number'],
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'])
          : null,
      notes: json['notes'],
      product: json['product'] != null
          ? ProductInfo.fromJson(json['product'])
          : null,
    );
  }
}

class SupplierInfo {
  final int id;
  final String name;
  final String? contact;
  final String? email;
  final String? address;
  final String? paymentTerms;
  final String? taxId;

  SupplierInfo({
    required this.id,
    required this.name,
    this.contact,
    this.email,
    this.address,
    this.paymentTerms,
    this.taxId,
  });

  factory SupplierInfo.fromJson(Map<String, dynamic> json) {
    return SupplierInfo(
      id: _toInt(json['id']),
      name: json['name'] ?? '',
      contact: json['contact'],
      email: json['email'],
      address: json['address'],
      paymentTerms: json['payment_terms'],
      taxId: json['tax_id'],
    );
  }
}

class ProductInfo {
  final int id;
  final String itemName;
  final String? barcode;
  final double? costPrice;
  final double? salePrice;
  final UnitInfo? unit;

  ProductInfo({
    required this.id,
    required this.itemName,
    this.barcode,
    this.costPrice,
    this.salePrice,
    this.unit,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      id: _toInt(json['id']),
      itemName: json['item_name'] ?? '',
      barcode: json['barcode'],
      costPrice:
      json['cost_price'] != null ? _toDouble(json['cost_price']) : null,
      salePrice:
      json['sale_price'] != null ? _toDouble(json['sale_price']) : null,
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
      id: _toInt(json['id']),
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
    );
  }
}