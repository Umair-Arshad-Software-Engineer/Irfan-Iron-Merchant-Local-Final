// screens/salary_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../providers/employee_provider.dart';

class SalaryScreen extends StatefulWidget {
  final Employee employee;
  const SalaryScreen({super.key, required this.employee});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate   = DateTime.now();

  // ── Deduction selection state ────────────────────────────────────────────
  // key = record id (as String), value = amount to deduct (partial support)
  final Map<String, double> _selectedAdvances = {};
  final Map<String, double> _selectedExpenses = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EmployeeProvider>(context, listen: false)
          .loadSalaryHistory(widget.employee.id);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => isFrom ? _fromDate = picked : _toDate = picked);
  }

  void _setFullMonth() {
    final now = DateTime.now();
    setState(() {
      _fromDate = DateTime(now.year, now.month, 1);
      _toDate   = DateTime(now.year, now.month + 1, 0);
    });
  }

  void _setLastMonth() {
    final now = DateTime.now();
    setState(() {
      _fromDate = DateTime(now.year, now.month - 1, 1);
      _toDate   = DateTime(now.year, now.month, 0);
    });
  }

  Future<void> _calculate() async {
    // Clear previous selections when recalculating
    setState(() {
      _selectedAdvances.clear();
      _selectedExpenses.clear();
    });
    await Provider.of<EmployeeProvider>(context, listen: false)
        .calculateSalary(widget.employee.id,
        _fromDate.toIso8601String().split('T')[0],
        _toDate.toIso8601String().split('T')[0]);
  }

  // ── Computed deduction totals ────────────────────────────────────────────
  double get _totalSelectedAdvance =>
      _selectedAdvances.values.fold(0, (s, v) => s + v);

  double get _totalSelectedExpense =>
      _selectedExpenses.values.fold(0, (s, v) => s + v);

  double get _totalSelectedDeductions =>
      _totalSelectedAdvance + _totalSelectedExpense;

  // ── Save payment ─────────────────────────────────────────────────────────
  Future<void> _savePayment(SalaryCalculation calc) async {
    final netAfterDeductions = calc.calculatedSalary - _totalSelectedDeductions;
    final paidCtrl  = TextEditingController(
        text: netAfterDeductions.clamp(0, double.infinity).toStringAsFixed(0));
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Confirm Payment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
              const SizedBox(height: 16),
              _calcRow('Period',      '${_fmtDate(_fromDate)} – ${_fmtDate(_toDate)}'),
              _calcRow('Present',     '${calc.presentDays} days'),
              _calcRow('Calculated',  'Rs. ${calc.calculatedSalary.toStringAsFixed(0)}'),
              if (_totalSelectedAdvance > 0)
                _calcRow('Advance Deduction', '- Rs. ${_totalSelectedAdvance.toStringAsFixed(0)}',
                    const Color(0xFFEF4444)),
              if (_totalSelectedExpense > 0)
                _calcRow('Expense Deduction', '- Rs. ${_totalSelectedExpense.toStringAsFixed(0)}',
                    const Color(0xFFEF4444)),
              if (_totalSelectedDeductions > 0) ...[
                const Divider(height: 16),
                _calcRow('Net Payable',
                    'Rs. ${netAfterDeductions.clamp(0, double.infinity).toStringAsFixed(0)}',
                    const Color(0xFF10B981)),
              ],
              const Divider(height: 24),
              const Text('Paid Amount',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              TextFormField(
                controller: paidCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: 'Rs. ',
                  filled: true, fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Notes (optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              TextFormField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. June salary',
                  filled: true, fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Payment'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<EmployeeProvider>(context, listen: false);

      // Build lists of fully-recovered IDs vs partial
      // For simplicity: any selected advance/expense ID goes to advance_ids/expense_ids
      // The backend marks them recovered. Partial amounts are tracked via deduction fields.
      final advanceIds = _selectedAdvances.keys.toList();
      final expenseIds = _selectedExpenses.keys.toList();

      final res = await provider.saveSalaryPayment({
        'employee_id':        calc.employeeId,
        'from_date':          calc.fromDate,
        'to_date':            calc.toDate,
        'total_days':         calc.totalDays,
        'present_days':       calc.presentDays,
        'absent_days':        calc.absentDays,
        'half_days':          calc.halfDays,
        'leave_days':         calc.leaveDays,
        'base_salary':        calc.baseSalary,
        'calculated_salary':  calc.calculatedSalary,
        'advance_deduction':  _totalSelectedAdvance,
        'expense_deduction':  _totalSelectedExpense,
        'paid_amount':        double.tryParse(paidCtrl.text) ?? netAfterDeductions,
        'advance_ids':        advanceIds,
        'expense_ids':        expenseIds,
        'notes':              notesCtrl.text.trim(),
        'payment_date':       DateTime.now().toIso8601String().split('T')[0],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['success'] ? 'Payment saved!' : (res['message'] ?? 'Error')),
          backgroundColor: res['success'] ? const Color(0xFF10B981) : Colors.red,
        ));
        if (res['success']) {
          provider.clearSalaryCalculation();
          setState(() {
            _selectedAdvances.clear();
            _selectedExpenses.clear();
          });
          _tabs.animateTo(1);
        }
      }
    }
  }

  // ── Show partial deduction dialog ────────────────────────────────────────
  Future<void> _showPartialDialog({
    required String id,
    required double fullAmount,
    required bool isAdvance,
  }) async {
    final ctrl = TextEditingController(
        text: (isAdvance
            ? (_selectedAdvances[id] ?? fullAmount)
            : (_selectedExpenses[id] ?? fullAmount))
            .toStringAsFixed(0));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Deduct ${isAdvance ? 'Advance' : 'Expense'}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Full amount: Rs. ${fullAmount.toStringAsFixed(0)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 12),
          TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Amount to deduct',
              prefixText: 'Rs. ',
              filled: true, fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? fullAmount;
              final clamped = val.clamp(0.0, fullAmount);
              setState(() {
                if (isAdvance) {
                  if (clamped > 0) _selectedAdvances[id] = clamped;
                  else             _selectedAdvances.remove(id);
                } else {
                  if (clamped > 0) _selectedExpenses[id] = clamped;
                  else             _selectedExpenses.remove(id);
                }
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, provider, _) {
        final calc = provider.salaryCalculation;

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.employee.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
              Text('Salary • ${widget.employee.salaryType.name}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ]),
            bottom: TabBar(
              controller: _tabs,
              labelColor: const Color(0xFF7C3AED),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF7C3AED),
              tabs: const [Tab(text: 'Calculate'), Tab(text: 'History')],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _buildCalculateTab(provider, calc),
              _buildHistoryTab(provider),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 1: Calculate ──────────────────────────────────────────────────────
  Widget _buildCalculateTab(EmployeeProvider provider, SalaryCalculation? calc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [

        // Employee banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6366F1)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: Center(
                child: Text(widget.employee.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.employee.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                    'Base: Rs. ${widget.employee.salary.toStringAsFixed(0)} / ${widget.employee.salaryType.name}',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Quick presets
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Quick Select',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _presetBtn('This Month', Icons.calendar_month, () {
                  _setFullMonth();
                  _calculate();
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _presetBtn('Last Month', Icons.calendar_today, () {
                  _setLastMonth();
                  _calculate();
                }),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // Custom range
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Custom Range',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _dateBtn('From', _fmtDate(_fromDate), () => _pickDate(true))),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: Colors.grey)),
              Expanded(child: _dateBtn('To', _fmtDate(_toDate), () => _pickDate(false))),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.salaryLoading ? null : _calculate,
                icon: provider.salaryLoading
                    ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.calculate),
                label: Text(provider.salaryLoading ? 'Calculating...' : 'Calculate Salary'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),

        // ── Result ──────────────────────────────────────────────────────
        if (calc != null) ...[
          const SizedBox(height: 16),

          // Attendance breakdown
          _buildBreakdownCard(calc),
          const SizedBox(height: 16),

          // Advances section
          if (calc.pendingAdvances.isNotEmpty) ...[
            _buildDeductionSection(
              title: 'Pending Advances',
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF6366F1),
              items: calc.pendingAdvances,
              selected: _selectedAdvances,
              isAdvance: true,
            ),
            const SizedBox(height: 16),
          ],

          // Expenses section
          if (calc.pendingExpenses.isNotEmpty) ...[
            _buildDeductionSection(
              title: 'Pending Expenses',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFFEF4444),
              items: calc.pendingExpenses,
              selected: _selectedExpenses,
              isAdvance: false,
            ),
            const SizedBox(height: 16),
          ],

          // Final summary + save
          _buildFinalSummary(calc),
        ],
      ]),
    );
  }

  // ── Attendance breakdown card ─────────────────────────────────────────────
  Widget _buildBreakdownCard(SalaryCalculation calc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Salary Breakdown',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
          _badge('Preview', const Color(0xFF10B981)),
        ]),
        const SizedBox(height: 16),
        _resultRow('Period', '${calc.fromDate} → ${calc.toDate}'),
        _resultRow('Total Days', '${calc.totalDays}'),
        const Divider(height: 20),
        _resultRow('✅ Present',  '${calc.presentDays} days', const Color(0xFF10B981)),
        _resultRow('❌ Absent',   '${calc.absentDays} days',  const Color(0xFFEF4444)),
        _resultRow('⏱ Half Day', '${calc.halfDays} days',    const Color(0xFFF59E0B)),
        _resultRow('🏖 Leave',   '${calc.leaveDays} days',   const Color(0xFF8B5CF6)),
        const Divider(height: 20),
        _resultRow('Base Salary', 'Rs. ${calc.baseSalary.toStringAsFixed(0)}'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Calculated Salary',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('Rs. ${calc.calculatedSalary.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
          ]),
        ),
      ]),
    );
  }

  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is num) return amount.toDouble();
    if (amount is String) {
      return double.tryParse(amount) ?? 0.0;
    }
    return 0.0;
  }

  // ── Deduction section (advances or expenses) ──────────────────────────────
  Widget _buildDeductionSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
    required Map<String, double> selected,
    required bool isAdvance,
  }) {
    final totalSelected = selected.values.fold(0.0, (s, v) => s + v);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
          ),
          if (totalSelected > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('- Rs. ${totalSelected.toStringAsFixed(0)}',
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ]),
        const SizedBox(height: 12),

        // Select All / Deselect All row
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (selected.length == items.length) {
                  selected.clear();
                } else {
                  for (final item in items) {
                    final id = item['id'].toString();
                    selected[id] = _parseAmount(item['amount']);
                  }
                }
              });
            },
            child: Text(
              selected.length == items.length ? 'Deselect All' : 'Select All',
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline),
            ),
          ),
        ]),
        const SizedBox(height: 8),

        // Items
        ...items.map((item) {
          final id         = item['id'].toString();
          final double fullAmount = _parseAmount(item['amount']);
          final date       = item['date'] as String? ?? '';
          final desc       = item['description'] as String? ?? '';
          final category   = item['category'] as String?;
          final isChecked  = selected.containsKey(id);
          final deductAmt  = selected[id] ?? fullAmount;
          final isPartial  = isChecked && deductAmt < fullAmount;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isChecked ? color.withOpacity(0.05) : const Color(0xFFF9F9FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isChecked ? color.withOpacity(0.3) : const Color(0xFFEEEEF5)),
            ),
            child: Row(children: [
              // Checkbox
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isChecked) selected.remove(id);
                    else           selected[id] = fullAmount;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: isChecked ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: isChecked ? color : Colors.grey[400]!, width: 2),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (category != null) ...[
                      _badge(category, color),
                      const SizedBox(width: 6),
                    ],
                    Text(date,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ]),
                  const SizedBox(height: 2),
                  Text('Rs. ${fullAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                  if (desc.isNotEmpty)
                    Text(desc,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ]),
              ),

              // Partial / full deduction indicator + edit
              if (isChecked) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showPartialDialog(
                      id: id, fullAmount: fullAmount, isAdvance: isAdvance),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPartial
                            ? const Color(0xFFF59E0B).withOpacity(0.1)
                            : color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          isPartial
                              ? 'Rs. ${deductAmt.toStringAsFixed(0)}'
                              : 'Full',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isPartial ? const Color(0xFFF59E0B) : color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit,
                            size: 11,
                            color: isPartial ? const Color(0xFFF59E0B) : color),
                      ]),
                    ),
                    if (isPartial)
                      Text('of ${fullAmount.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                  ]),
                ),
              ],
            ]),
          );
        }),
      ]),
    );
  }

  // ── Final summary card ────────────────────────────────────────────────────
  Widget _buildFinalSummary(SalaryCalculation calc) {
    final net = (calc.calculatedSalary - _totalSelectedDeductions).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Payment Summary',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
        const SizedBox(height: 16),

        _resultRow('Calculated Salary', 'Rs. ${calc.calculatedSalary.toStringAsFixed(0)}'),

        if (_totalSelectedAdvance > 0)
          _resultRow('Advance Deduction',
              '- Rs. ${_totalSelectedAdvance.toStringAsFixed(0)}',
              const Color(0xFF6366F1)),

        if (_totalSelectedExpense > 0)
          _resultRow('Expense Deduction',
              '- Rs. ${_totalSelectedExpense.toStringAsFixed(0)}',
              const Color(0xFFEF4444)),

        if (_totalSelectedDeductions > 0) const Divider(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6366F1)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Net Payable',
                style: TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            Text('Rs. ${net.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _savePayment(calc),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

// ── Tab 2: History ────────────────────────────────────────────────────────
  Widget _buildHistoryTab(EmployeeProvider provider) {
    if (provider.salaryHistory.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No payments yet', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: provider.salaryHistory.length,
      itemBuilder: (ctx, i) {
        final p = provider.salaryHistory[i];

        // Option 1: Swipe to delete (recommended)
        return Dismissible(
          key: Key(p.id.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white, size: 28),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Delete Payment'),
                content: Text(
                  'Delete salary for period ${p.fromDate} → ${p.toDate}?\n\nThis will also revert any advances/expenses marked as recovered.',
                  style: const TextStyle(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            final provider = Provider.of<EmployeeProvider>(context, listen: false);
            final result = await provider.deleteSalaryPayment(p.id.toString(), widget.employee.id);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['success'] ? 'Payment deleted!' : (result['message'] ?? 'Failed to delete')),
                  backgroundColor: result['success'] ? const Color(0xFF10B981) : Colors.red,
                ),
              );
              if (!result['success']) {
                // Refresh to restore the item if deletion failed
                await provider.loadSalaryHistory(widget.employee.id);
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0F0F5)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${p.fromDate} → ${p.toDate}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                Row(
                  children: [
                    Text('Rs. ${p.paidAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF10B981))),
                    const SizedBox(width: 12),
                    // Delete button (optional, as alternative to swipe)
                    GestureDetector(
                      onTap: () => _deletePayment({
                        'id': p.id,
                        'from_date': p.fromDate,
                        'to_date': p.toDate,
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      ),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                _historyChip('${p.presentDays}P', const Color(0xFF10B981)),
                _historyChip('${p.absentDays}A',  const Color(0xFFEF4444)),
                _historyChip('${p.halfDays}H',    const Color(0xFFF59E0B)),
                if (p.leaveDays > 0)
                  _historyChip('${p.leaveDays}L', const Color(0xFF8B5CF6)),
                _historyChip('${p.totalDays} days', Colors.grey),
              ]),
              // Show deductions if any
              if ((p.advanceDeduction ?? 0) > 0 || (p.expenseDeduction ?? 0) > 0) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  if ((p.advanceDeduction ?? 0) > 0)
                    _historyChip(
                        'Adv: -Rs. ${p.advanceDeduction!.toStringAsFixed(0)}',
                        const Color(0xFF6366F1)),
                  if ((p.expenseDeduction ?? 0) > 0)
                    _historyChip(
                        'Exp: -Rs. ${p.expenseDeduction!.toStringAsFixed(0)}',
                        const Color(0xFFEF4444)),
                ]),
              ],
              if (p.notes != null && p.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(p.notes!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ]),
          ),
        );

        // Option 2: Just the delete button without swipe (simpler)
        // Remove the Dismissible wrapper and just use the delete button inside the Row
      },
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _calcRow(String label, String value, [Color? valueColor]) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF2D3142))),
    ]),
  );

  Widget _resultRow(String label, String value, [Color? valueColor]) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF2D3142))),
    ]),
  );

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );

  Widget _historyChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );

  Widget _presetBtn(String label, IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: const Color(0xFF7C3AED)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF7C3AED))),
      ]),
    ),
  );

  // In salary_screen.dart, update the _deletePayment method:

  Future<void> _deletePayment(Map<String, dynamic> payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Payment'),
        content: Text(
          'Are you sure you want to delete salary payment for period\n'
              '${payment['from_date']} → ${payment['to_date']}?\n\n'
              'This will also revert any advances/expenses marked as recovered.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<EmployeeProvider>(context, listen: false);
      final result = await provider.deleteSalaryPayment(
          payment['id'].toString(),
          widget.employee.id
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['success'] ? 'Payment deleted successfully!' : (result['message'] ?? 'Failed to delete payment')),
            backgroundColor: result['success'] ? const Color(0xFF10B981) : Colors.red,
          ),
        );
      }
    }
  }

  Widget _dateBtn(String label, String value, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
        const SizedBox(height: 2),
        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF7C3AED)),
      ]),
    ),
  );
}