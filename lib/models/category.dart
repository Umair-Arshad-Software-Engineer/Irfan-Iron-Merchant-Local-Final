class Category {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  List<Subcategory>? subcategories;

  Category({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'].toString(),
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      subcategories: json['subcategories'] != null
          ? (json['subcategories'] as List)
          .map((sub) => Subcategory.fromJson(sub))
          .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'subcategories': subcategories?.map((sub) => sub.toJson()).toList(),
    };
  }
}

class Subcategory {
  final String id;
  final String name;
  final String categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subcategory({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      id: json['id'].toString(),
      name: json['name'],
      categoryId: json['category_id'].toString(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}