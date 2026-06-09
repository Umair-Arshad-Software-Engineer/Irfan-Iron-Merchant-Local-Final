// models/attendance.dart

enum AttendanceStatus { Present, Absent, Half_Day, Leave }

class AttendanceRecord {
  final String id;
  final String employeeId;
  final DateTime date;
  final AttendanceStatus status;
  final String? notes;

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.status,
    this.notes,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id:         json['id'].toString(),
      employeeId: json['employee_id'].toString(),
      date:       DateTime.parse(json['date']),
      status:     AttendanceStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => AttendanceStatus.Present,
      ),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id':          id,
    'employee_id': employeeId,
    'date':        date.toIso8601String().split('T')[0],
    'status':      status.name,
    'notes':       notes,
  };

  String get statusLabel {
    switch (status) {
      case AttendanceStatus.Present:  return 'Present';
      case AttendanceStatus.Absent:   return 'Absent';
      case AttendanceStatus.Half_Day: return 'Half Day';
      case AttendanceStatus.Leave:    return 'Leave';
    }
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// SalaryCalculation
// ─────────────────────────────────────────────────────────────────────────────

class SalaryCalculation {
  final String employeeId;
  final String employeeName;
  final String salaryType;
  final double baseSalary;
  final String fromDate;
  final String toDate;
  final int    totalDays;
  final double presentDays;
  final int    absentDays;
  final int    halfDays;
  final int    leaveDays;
  final double calculatedSalary;

  // ── Deduction fields (populated by backend) ───────────────────────────────
  final double totalAdvance;
  final double totalExpense;
  final double totalDeductions;
  final double netSalary;
  final List<Map<String, dynamic>> pendingAdvances;
  final List<Map<String, dynamic>> pendingExpenses;

  SalaryCalculation({
    required this.employeeId,
    required this.employeeName,
    required this.salaryType,
    required this.baseSalary,
    required this.fromDate,
    required this.toDate,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.halfDays,
    required this.leaveDays,
    required this.calculatedSalary,
    this.totalAdvance    = 0,
    this.totalExpense    = 0,
    this.totalDeductions = 0,
    this.netSalary       = 0,
    this.pendingAdvances = const [],
    this.pendingExpenses = const [],
  });

  factory SalaryCalculation.fromJson(Map<String, dynamic> json) {
    return SalaryCalculation(
      employeeId:       json['employee_id'].toString(),
      employeeName:     json['employee_name'],
      salaryType:       json['salary_type'],
      baseSalary:       double.parse(json['base_salary'].toString()),
      fromDate:         json['from_date'],
      toDate:           json['to_date'],
      totalDays:        json['total_days'],
      presentDays:      double.parse(json['present_days'].toString()),
      absentDays:       json['absent_days'],
      halfDays:         json['half_days'],
      leaveDays:        json['leave_days'],
      calculatedSalary: double.parse(json['calculated_salary'].toString()),
      totalAdvance:     double.parse((json['total_advance']    ?? 0).toString()),
      totalExpense:     double.parse((json['total_expense']    ?? 0).toString()),
      totalDeductions:  double.parse((json['total_deductions'] ?? 0).toString()),
      netSalary:        double.parse((json['net_salary']       ?? 0).toString()),
      pendingAdvances:  List<Map<String, dynamic>>.from(json['pending_advances'] ?? []),
      pendingExpenses:  List<Map<String, dynamic>>.from(json['pending_expenses'] ?? []),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// SalaryPayment
// ─────────────────────────────────────────────────────────────────────────────

class SalaryPayment {
  final String  id;
  final String  employeeId;
  final String  employeeName;
  final String  fromDate;
  final String  toDate;
  final int     totalDays;
  final double  presentDays;
  final int     absentDays;
  final int     halfDays;
  final int     leaveDays;
  final double  baseSalary;
  final double  calculatedSalary;
  final double  paidAmount;
  final double? advanceDeduction;  // ← NEW
  final double? expenseDeduction;  // ← NEW
  final String? notes;
  final String? paymentDate;
  final DateTime createdAt;

  SalaryPayment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.fromDate,
    required this.toDate,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.halfDays,
    required this.leaveDays,
    required this.baseSalary,
    required this.calculatedSalary,
    required this.paidAmount,
    this.advanceDeduction,
    this.expenseDeduction,
    this.notes,
    this.paymentDate,
    required this.createdAt,
  });

  factory SalaryPayment.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'] as Map<String, dynamic>?;
    return SalaryPayment(
      id:               json['id'].toString(),
      employeeId:       json['employee_id'].toString(),
      employeeName:     emp?['name'] ?? '',
      fromDate:         json['from_date'],
      toDate:           json['to_date'],
      totalDays:        json['total_days'],
      presentDays:      double.parse(json['present_days'].toString()),
      absentDays:       json['absent_days'],
      halfDays:         json['half_days'],
      leaveDays:        json['leave_days'],
      baseSalary:       double.parse(json['base_salary'].toString()),
      calculatedSalary: double.parse(json['calculated_salary'].toString()),
      paidAmount:       double.parse(json['paid_amount'].toString()),
      advanceDeduction: json['advance_deduction'] != null   // ← NEW
          ? double.parse(json['advance_deduction'].toString())
          : null,
      expenseDeduction: json['expense_deduction'] != null   // ← NEW
          ? double.parse(json['expense_deduction'].toString())
          : null,
      notes:            json['notes'],
      paymentDate:      json['payment_date'],
      createdAt:        DateTime.parse(json['createdAt']),
    );
  }
}