// models/employee.dart

enum SalaryType { Daily, Monthly, Contract }

class Employee {
  final String id;
  final String name;
  final String fatherName;
  final String phone;
  final String address;
  final double salary;
  final SalaryType salaryType;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Employee({
    required this.id,
    required this.name,
    required this.fatherName,
    required this.phone,
    required this.address,
    required this.salary,
    required this.salaryType,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'].toString(),
      name: json['name'],
      fatherName: json['father_name'],
      phone: json['phone'],
      address: json['address'] ?? '',
      salary: double.parse(json['salary'].toString()),
      salaryType: SalaryType.values.firstWhere(
            (e) => e.name == json['salary_type'],
        orElse: () => SalaryType.Monthly,
      ),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'father_name': fatherName,
    'phone': phone,
    'address': address,
    'salary': salary,
    'salary_type': salaryType.name,
    'is_active': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}