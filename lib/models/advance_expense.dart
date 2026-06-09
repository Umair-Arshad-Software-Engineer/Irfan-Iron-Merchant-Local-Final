// models/advance_expense.dart

enum AdvanceStatus { pending, recovered }

class AdvancePayment {
  final String id;
  final String employeeId;
  final double amount;
  final DateTime date;
  final String? description;
  final AdvanceStatus status;
  final String? salaryPaymentId;
  final DateTime createdAt;

  AdvancePayment({
    required this.id,
    required this.employeeId,
    required this.amount,
    required this.date,
    this.description,
    required this.status,
    this.salaryPaymentId,
    required this.createdAt,
  });

  factory AdvancePayment.fromJson(Map<String, dynamic> json) => AdvancePayment(
    id: json['id'].toString(),
    employeeId: json['employee_id'].toString(),
    amount: double.parse(json['amount'].toString()),
    date: DateTime.parse(json['date']),
    description: json['description'],
    status: json['status'] == 'recovered'
        ? AdvanceStatus.recovered
        : AdvanceStatus.pending,
    salaryPaymentId: json['salary_payment_id']?.toString(),
    createdAt: DateTime.parse(json['createdAt']),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

enum ExpenseCategory { Travel, Food, Medical, Uniform, Fine, Other }
enum ExpenseStatus   { pending, recovered }

class EmployeeExpense {
  final String id;
  final String employeeId;
  final double amount;
  final DateTime date;
  final ExpenseCategory category;
  final String? description;
  final ExpenseStatus status;
  final String? salaryPaymentId;
  final DateTime createdAt;

  EmployeeExpense({
    required this.id,
    required this.employeeId,
    required this.amount,
    required this.date,
    required this.category,
    this.description,
    required this.status,
    this.salaryPaymentId,
    required this.createdAt,
  });

  factory EmployeeExpense.fromJson(Map<String, dynamic> json) => EmployeeExpense(
    id: json['id'].toString(),
    employeeId: json['employee_id'].toString(),
    amount: double.parse(json['amount'].toString()),
    date: DateTime.parse(json['date']),
    category: ExpenseCategory.values.firstWhere(
          (e) => e.name == json['category'],
      orElse: () => ExpenseCategory.Other,
    ),
    description: json['description'],
    status: json['status'] == 'recovered'
        ? ExpenseStatus.recovered
        : ExpenseStatus.pending,
    salaryPaymentId: json['salary_payment_id']?.toString(),
    createdAt: DateTime.parse(json['createdAt']),
  );

  String get categoryLabel => category.name;
}

// ─────────────────────────────────────────────────────────────────────────────
// Ledger summary returned alongside the list
// ─────────────────────────────────────────────────────────────────────────────

class LedgerSummary {
  final double totalAmount;
  final double totalRecovered;
  final double pendingBalance;

  LedgerSummary({
    required this.totalAmount,
    required this.totalRecovered,
    required this.pendingBalance,
  });

  factory LedgerSummary.fromAdvanceJson(Map<String, dynamic> json) => LedgerSummary(
    totalAmount:     double.parse(json['total_advanced'].toString()),
    totalRecovered:  double.parse(json['total_recovered'].toString()),
    pendingBalance:  double.parse(json['pending_balance'].toString()),
  );

  factory LedgerSummary.fromExpenseJson(Map<String, dynamic> json) => LedgerSummary(
    totalAmount:     double.parse(json['total_expensed'].toString()),
    totalRecovered:  double.parse(json['total_recovered'].toString()),
    pendingBalance:  double.parse(json['pending_balance'].toString()),
  );
}