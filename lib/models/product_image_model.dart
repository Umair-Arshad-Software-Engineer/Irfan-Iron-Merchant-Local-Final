// lib/models/product_image_model.dart
class ProductImage {
  final int id;
  final int productId;
  final String imageUrl;
  final bool isPrimary;
  final int sortOrder;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductImage({
    required this.id,
    required this.productId,
    required this.imageUrl,
    required this.isPrimary,
    required this.sortOrder,
    this.fileName,
    this.fileSize,
    this.mimeType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'],
      productId: json['product_id'],
      imageUrl: json['image_url'],
      isPrimary: json['is_primary'] ?? false,
      sortOrder: json['sort_order'] ?? 0,
      fileName: json['file_name'],
      fileSize: json['file_size'],
      mimeType: json['mime_type'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'image_url': imageUrl,
      'is_primary': isPrimary,
      'sort_order': sortOrder,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}