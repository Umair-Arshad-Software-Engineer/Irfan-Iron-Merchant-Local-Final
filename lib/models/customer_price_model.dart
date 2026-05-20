// lib/models/customer_price_model.dart

class CustomerPriceModel {
  final int id;
  final int customerId;
  final int productId;
  final double price;
  final bool isActive;
  final CustomerSummary? customer;
  final ProductSummary? product;

  CustomerPriceModel({
    required this.id,
    required this.customerId,
    required this.productId,
    required this.price,
    required this.isActive,
    this.customer,
    this.product,
  });

  factory CustomerPriceModel.fromJson(Map<String, dynamic> json) {
    return CustomerPriceModel(
      id: json['id'],
      customerId: json['customer_id'],
      productId: json['product_id'],
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      isActive: json['is_active'] ?? true,
      customer: json['customer'] != null ? CustomerSummary.fromJson(json['customer']) : null,
      product: json['product'] != null ? ProductSummary.fromJson(json['product']) : null,
    );
  }

  CustomerPriceModel copyWith({
    int? id,
    int? customerId,
    int? productId,
    double? price,
    bool? isActive,
    CustomerSummary? customer,
    ProductSummary? product,
  }) {
    return CustomerPriceModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      productId: productId ?? this.productId,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      customer: customer ?? this.customer,
      product: product ?? this.product,
    );
  }
}

class CustomerSummary {
  final int id;
  final String name;
  final String? customerType;
  final String? contact;

  CustomerSummary({required this.id, required this.name, this.customerType, this.contact});

  factory CustomerSummary.fromJson(Map<String, dynamic> json) {
    return CustomerSummary(
      id: json['id'],
      name: json['name'] ?? '',
      customerType: json['customer_type'],
      contact: json['contact'],
    );
  }
}

class ProductSummary {
  final int id;
  final String itemName;
  final double salePrice;
  final double costPrice;
  final String? barcode;
  final UnitSummary? unit;

  ProductSummary({
    required this.id,
    required this.itemName,
    required this.salePrice,
    required this.costPrice,
    this.barcode,
    this.unit,
  });

  factory ProductSummary.fromJson(Map<String, dynamic> json) {
    return ProductSummary(
      id: json['id'],
      itemName: json['item_name'] ?? '',
      salePrice: double.tryParse(json['sale_price']?.toString() ?? '0') ?? 0.0,
      costPrice: double.tryParse(json['cost_price']?.toString() ?? '0') ?? 0.0,
      barcode: json['barcode'],
      unit: json['unit'] != null ? UnitSummary.fromJson(json['unit']) : null,
    );
  }
}

class UnitSummary {
  final int id;
  final String name;
  final String symbol;

  UnitSummary({required this.id, required this.name, required this.symbol});

  factory UnitSummary.fromJson(Map<String, dynamic> json) {
    return UnitSummary(
      id: json['id'],
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
    );
  }
}