// providers/employee_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/advance_expense.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../config/api_config.dart';

class EmployeeProvider with ChangeNotifier {
  // ── Employee state ─────────────────────────────────────────────────────────
  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  bool _isLoading = false;
  String _error = '';

  List<Employee> get employees => _filteredEmployees;
  bool get isLoading => _isLoading;
  String get error => _error;

  // ── Attendance state ───────────────────────────────────────────────────────
  Map<String, AttendanceStatus> _attendanceMap = {};    // date -> status
  List<AttendanceRecord> _attendanceRecords = [];
  bool _attendanceLoading = false;

  Map<String, AttendanceStatus> get attendanceMap => _attendanceMap;
  List<AttendanceRecord> get attendanceRecords => _attendanceRecords;
  bool get attendanceLoading => _attendanceLoading;

  // ── Salary state ───────────────────────────────────────────────────────────
  SalaryCalculation? _salaryCalculation;
  List<SalaryPayment> _salaryHistory = [];
  bool _salaryLoading = false;

  SalaryCalculation? get salaryCalculation => _salaryCalculation;
  List<SalaryPayment> get salaryHistory => _salaryHistory;
  bool get salaryLoading => _salaryLoading;

  List<AdvancePayment> _advances = [];
  LedgerSummary? _advanceSummary;
  bool _advanceLoading = false;

  List<AdvancePayment> get advances        => _advances;
  LedgerSummary?       get advanceSummary  => _advanceSummary;
  bool                 get advanceLoading  => _advanceLoading;

  List<EmployeeExpense> _empExpenses = [];
  LedgerSummary? _expenseSummary;
  bool _empExpenseLoading = false;

  List<EmployeeExpense> get empExpenses       => _empExpenses;
  LedgerSummary?        get expenseSummary    => _expenseSummary;
  bool                  get empExpenseLoading => _empExpenseLoading;

  // ══════════════════════════════════════════════════════════════════════════
  //  EMPLOYEES
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> loadEmployees() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/employees'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(res.body);
      if (data['success']) {
        _employees = (data['data'] as List)
            .map((e) => Employee.fromJson(e))
            .toList();
        _filteredEmployees = List.from(_employees);
      } else {
        _error = data['message'] ?? 'Failed to load';
      }
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> payload) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/employees'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      final data = json.decode(res.body);
      if (data['success']) {
        _employees.insert(0, Employee.fromJson(data['data']));
        _filteredEmployees = List.from(_employees);
        notifyListeners();
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateEmployee(String id, Map<String, dynamic> payload) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/employees/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      final data = json.decode(res.body);
      if (data['success']) {
        final idx = _employees.indexWhere((e) => e.id == id);
        if (idx != -1) {
          _employees[idx] = Employee.fromJson(data['data']);
          _filteredEmployees = List.from(_employees);
          notifyListeners();
        }
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteEmployee(String id) async {
    try {
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/employees/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(res.body);
      if (data['success']) {
        _employees.removeWhere((e) => e.id == id);
        _filteredEmployees = List.from(_employees);
        notifyListeners();
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  void searchEmployees(String query) {
    if (query.isEmpty) {
      _filteredEmployees = List.from(_employees);
    } else {
      _filteredEmployees = _employees.where((e) =>
      e.name.toLowerCase().contains(query.toLowerCase()) ||
          e.phone.contains(query)
      ).toList();
    }
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ATTENDANCE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> loadAttendanceForEmployee(String employeeId, int month, int year) async {
    _attendanceLoading = true;
    notifyListeners();

    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/attendance/employee/$employeeId?month=$month&year=$year'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(res.body);
      if (data['success']) {
        _attendanceRecords = (data['data'] as List)
            .map((r) => AttendanceRecord.fromJson(r))
            .toList();

        // Build a date->status map for quick lookup in the calendar
        _attendanceMap = {};
        for (final rec in _attendanceRecords) {
          final key = rec.date.toIso8601String().split('T')[0];
          _attendanceMap[key] = rec.status;
        }
      }
    } catch (_) {}

    _attendanceLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> markAttendance(
      String employeeId, DateTime date, AttendanceStatus status, {String? notes})
  async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/attendance'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'employee_id': employeeId,
          'date': dateStr,
          'status': status.name,
          'notes': notes,
        }),
      );
      final data = json.decode(res.body);
      if (data['success']) {
        // Update local map immediately
        _attendanceMap[dateStr] = status;
        notifyListeners();
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> bulkMarkAttendance(
      String date, List<Map<String, dynamic>> records)
  async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/attendance/bulk'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'date': date, 'records': records}),
      );
      final data = json.decode(res.body);
      if (data['success']) {
        for (final rec in records) {
          _attendanceMap[date] = AttendanceStatus.values.firstWhere(
                  (e) => e.name == rec['status'], orElse: () => AttendanceStatus.Present);
        }
        notifyListeners();
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SALARY
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> calculateSalary(String employeeId, String fromDate, String toDate) async {
    _salaryLoading = true;
    _salaryCalculation = null;
    notifyListeners();

    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/salary/calculate?employee_id=$employeeId&from_date=$fromDate&to_date=$toDate'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(res.body);
      if (data['success']) {
        _salaryCalculation = SalaryCalculation.fromJson(data['data']);
      }
    } catch (_) {}

    _salaryLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> saveSalaryPayment(Map<String, dynamic> payload) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/salary'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      final data = json.decode(res.body);
      if (data['success']) {
        await loadSalaryHistory(payload['employee_id'].toString());
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ✅ ADD THIS METHOD - Delete salary payment
  Future<Map<String, dynamic>> deleteSalaryPayment(String paymentId, String employeeId) async {
    try {
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/salary/$paymentId'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(res.body);
      if (data['success']) {
        // Refresh salary history after deletion
        await loadSalaryHistory(employeeId);
        notifyListeners();
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<void> loadSalaryHistory(String employeeId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/salary/employee/$employeeId'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(res.body);
      if (data['success']) {
        _salaryHistory = (data['data'] as List)
            .map((p) => SalaryPayment.fromJson(p))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  void clearSalaryCalculation() {
    _salaryCalculation = null;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ADVANCE PAYMENTS state
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> loadAdvances(String employeeId, {String? status}) async {
    _advanceLoading = true;
    notifyListeners();
    try {
      final params = status != null ? '?status=$status' : '';
      final res  = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/advances/employee/$employeeId$params'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(res.body);
      if (data['success']) {
        _advances = (data['data'] as List)
            .map((a) => AdvancePayment.fromJson(a))
            .toList();
        _advanceSummary = LedgerSummary.fromAdvanceJson(data['summary']);
      }
    } catch (_) {}
    _advanceLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> createAdvance(Map<String, dynamic> payload) async {
    try {
      final res  = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/advances'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      final data = json.decode(res.body);
      if (data['success']) {
        await loadAdvances(payload['employee_id'].toString());
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateAdvance(String id, Map<String, dynamic> payload, String employeeId) async {
    try {
      final res  = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/advances/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      final data = json.decode(res.body);
      if (data['success']) await loadAdvances(employeeId);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteAdvance(String id, String employeeId) async {
    try {
      final res  = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/advances/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(res.body);
      if (data['success']) await loadAdvances(employeeId);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  EMPLOYEE EXPENSES state
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> loadEmpExpenses(String employeeId, {String? status, String? category}) async {
    _empExpenseLoading = true;
    notifyListeners();
    try {
      final q = <String>[];
      if (status   != null) q.add('status=$status');
      if (category != null) q.add('category=$category');
      final params = q.isNotEmpty ? '?${q.join('&')}' : '';
      final res    = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/emp-expenses/employee/$employeeId$params'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(res.body);
      if (data['success']) {
        _empExpenses   = (data['data'] as List)
            .map((e) => EmployeeExpense.fromJson(e))
            .toList();
        _expenseSummary = LedgerSummary.fromExpenseJson(data['summary']);
      }
    } catch (_) {}
    _empExpenseLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> createEmpExpense(Map<String, dynamic> payload) async {
    try {
      final res  = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/emp-expenses'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      final data = json.decode(res.body);
      if (data['success']) await loadEmpExpenses(payload['employee_id'].toString());
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateEmpExpense(String id, Map<String, dynamic> payload, String employeeId) async {
    try {
      final res  = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/emp-expenses/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      final data = json.decode(res.body);
      if (data['success']) await loadEmpExpenses(employeeId);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteEmpExpense(String id, String employeeId) async {
    try {
      final res  = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/emp-expenses/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(res.body);
      if (data['success']) await loadEmpExpenses(employeeId);
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}