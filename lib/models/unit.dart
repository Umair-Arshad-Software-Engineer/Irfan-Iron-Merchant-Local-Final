class Unit {
  final String id;
  final String name;
  final String symbol;
  final String type;
  final bool isActive;
  final double conversionFactor;
  final String? baseUnitId;
  final Unit? baseUnit;
  final List<Unit>? derivedUnits;
  final DateTime createdAt;
  final DateTime updatedAt;

  Unit({
    required this.id,
    required this.name,
    required this.symbol,
    required this.type,
    required this.isActive,
    required this.conversionFactor,
    this.baseUnitId,
    this.baseUnit,
    this.derivedUnits,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['id'].toString(),
      name: json['name'],
      symbol: json['symbol'],
      type: json['type'],
      isActive: json['is_active'] ?? true,
      conversionFactor: json['conversion_factor']?.toDouble() ?? 1.0,
      baseUnitId: json['base_unit_id']?.toString(),
      baseUnit: json['baseUnit'] != null ? Unit.fromJson(json['baseUnit']) : null,
      derivedUnits: json['derivedUnits'] != null
          ? (json['derivedUnits'] as List)
          .map((unit) => Unit.fromJson(unit))
          .toList()
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'type': type,
      'is_active': isActive,
      'conversion_factor': conversionFactor,
      'base_unit_id': baseUnitId,
      'baseUnit': baseUnit?.toJson(),
      'derivedUnits': derivedUnits?.map((unit) => unit.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get displayName => '$name ($symbol)';

  String get typeDisplay {
    switch (type) {
      case 'weight': return 'Weight';
      case 'volume': return 'Volume';
      case 'count': return 'Count';
      case 'length': return 'Length';
      case 'area': return 'Area';
      case 'custom': return 'Custom';
      default: return type;
    }
  }
}

class UnitType {
  final String value;
  final String label;

  const UnitType(this.value, this.label);

  static const weight = UnitType('weight', 'Weight');
  static const volume = UnitType('volume', 'Volume');
  static const count = UnitType('count', 'Count');
  static const length = UnitType('length', 'Length');
  static const area = UnitType('area', 'Area');
  static const custom = UnitType('custom', 'Custom');

  static const List<UnitType> all = [weight, volume, count, length, area, custom];

  static UnitType fromValue(String value) {
    return all.firstWhere((type) => type.value == value, orElse: () => custom);
  }
}

class UnitConversion {
  final String fromUnit;
  final String toUnit;
  final double originalValue;
  final double convertedValue;
  final String symbol;

  UnitConversion({
    required this.fromUnit,
    required this.toUnit,
    required this.originalValue,
    required this.convertedValue,
    required this.symbol,
  });

  factory UnitConversion.fromJson(Map<String, dynamic> json) {
    return UnitConversion(
      fromUnit: json['from_unit'],
      toUnit: json['to_unit'],
      originalValue: json['original_value'].toDouble(),
      convertedValue: json['converted_value'].toDouble(),
      symbol: json['symbol'],
    );
  }
}



extension UnitExtensions on Unit {
  String get typeDisplayUrdu {
    switch (type) {
      case 'weight': return 'وزن';
      case 'volume': return 'حجم';
      case 'count': return 'تعداد';
      case 'length': return 'لمبائی';
      case 'area': return 'رقبہ';
      case 'custom': return 'کسٹم';
      default: return type;
    }
  }
}

extension UnitTypeExtensions on UnitType {
  String get labelUrdu {
    switch (value) {
      case 'weight': return 'وزن';
      case 'volume': return 'حجم';
      case 'count': return 'تعداد';
      case 'length': return 'لمبائی';
      case 'area': return 'رقبہ';
      case 'custom': return 'کسٹم';
      default: return label;
    }
  }
}