// screens/salary_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../providers/employee_provider.dart';
import '../providers/lanprovider.dart';

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
    final lang = Provider.of<LanguageProvider>(context, listen: false);
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
              Text(
                lang.isEnglish ? 'Confirm Payment' : 'ادائیگی کی تصدیق کریں',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
              ),
              const SizedBox(height: 16),
              _calcRow(lang.isEnglish ? 'Period' : 'مدت', '${_fmtDate(_fromDate)} – ${_fmtDate(_toDate)}'),
              _calcRow(lang.isEnglish ? 'Present' : 'حاضر', '${calc.presentDays} ${lang.isEnglish ? 'days' : 'دن'}'),
              _calcRow(lang.isEnglish ? 'Calculated' : 'حساب شدہ', 'Rs. ${calc.calculatedSalary.toStringAsFixed(0)}'),
              if (_totalSelectedAdvance > 0)
                _calcRow(lang.isEnglish ? 'Advance Deduction' : 'ادوانس کٹوتی', '- Rs. ${_totalSelectedAdvance.toStringAsFixed(0)}',
                    const Color(0xFFEF4444)),
              if (_totalSelectedExpense > 0)
                _calcRow(lang.isEnglish ? 'Expense Deduction' : 'خرچ کٹوتی', '- Rs. ${_totalSelectedExpense.toStringAsFixed(0)}',
                    const Color(0xFFEF4444)),
              if (_totalSelectedDeductions > 0) ...[
                const Divider(height: 16),
                _calcRow(lang.isEnglish ? 'Net Payable' : 'قابل ادائیگی',
                    'Rs. ${netAfterDeductions.clamp(0, double.infinity).toStringAsFixed(0)}',
                    const Color(0xFF10B981)),
              ],
              const Divider(height: 24),
              Text(
                lang.isEnglish ? 'Paid Amount' : 'ادا شدہ رقم',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
              ),
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
              Text(
                lang.isEnglish ? 'Notes (optional)' : 'نوٹس (اختیاری)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: lang.isEnglish ? 'e.g. June salary' : 'مثال: جون کی تنخواہ',
                  filled: true, fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(lang.isEnglish ? 'Cancel' : 'منسوخ کریں')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(lang.isEnglish ? 'Save Payment' : 'ادائیگی محفوظ کریں'),
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
          content: Text(res['success']
              ? (lang.isEnglish ? 'Payment saved!' : 'ادائیگی محفوظ ہو گئی!')
              : (res['message'] ?? (lang.isEnglish ? 'Error' : 'خرابی'))),
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
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final ctrl = TextEditingController(
        text: (isAdvance
            ? (_selectedAdvances[id] ?? fullAmount)
            : (_selectedExpenses[id] ?? fullAmount))
            .toStringAsFixed(0));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
            lang.isEnglish
                ? 'Deduct ${isAdvance ? 'Advance' : 'Expense'}'
                : '${isAdvance ? 'ادوانس' : 'خرچ'} کاٹیں'
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            lang.isEnglish
                ? 'Full amount: Rs. ${fullAmount.toStringAsFixed(0)}'
                : 'مکمل رقم: روپے ${fullAmount.toStringAsFixed(0)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: lang.isEnglish ? 'Amount to deduct' : 'کٹوتی کی رقم',
              prefixText: 'Rs. ',
              filled: true, fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.isEnglish ? 'Cancel' : 'منسوخ کریں')),
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
            child: Text(lang.isEnglish ? 'Apply' : 'لاگو کریں'),
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
    final lang = Provider.of<LanguageProvider>(context);
    final salaryTypeLabel = lang.isEnglish
        ? widget.employee.salaryType.name
        : (widget.employee.salaryType == SalaryType.Daily ? 'روزانہ'
        : widget.employee.salaryType == SalaryType.Monthly ? 'ماہانہ'
        : 'معاہدہ');

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
              Text(
                '${lang.isEnglish ? 'Salary' : 'تنخواہ'} • $salaryTypeLabel',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ]),
            bottom: TabBar(
              controller: _tabs,
              labelColor: const Color(0xFF7C3AED),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF7C3AED),
              tabs: [
                Tab(text: lang.isEnglish ? 'Calculate' : 'حساب کریں'),
                Tab(text: lang.isEnglish ? 'History' : 'تاریخ'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _buildCalculateTab(provider, calc, lang),
              _buildHistoryTab(provider, lang),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 1: Calculate ──────────────────────────────────────────────────────
  Widget _buildCalculateTab(EmployeeProvider provider, SalaryCalculation? calc, LanguageProvider lang) {
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
                    '${lang.isEnglish ? 'Base' : 'بنیادی'}: Rs. ${widget.employee.salary.toStringAsFixed(0)} / ${
                        lang.isEnglish
                            ? widget.employee.salaryType.name
                            : (widget.employee.salaryType == SalaryType.Daily ? 'روزانہ'
                            : widget.employee.salaryType == SalaryType.Monthly ? 'ماہانہ'
                            : 'معاہدہ')
                    }',
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
            Text(
              lang.isEnglish ? 'Quick Select' : 'فوری انتخاب',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _presetBtn(
                  lang.isEnglish ? 'This Month' : 'اس ماہ',
                  Icons.calendar_month,
                      () {
                    _setFullMonth();
                    _calculate();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _presetBtn(
                  lang.isEnglish ? 'Last Month' : 'پچھلا ماہ',
                  Icons.calendar_today,
                      () {
                    _setLastMonth();
                    _calculate();
                  },
                ),
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
            Text(
              lang.isEnglish ? 'Custom Range' : 'اپنی مرضی کی حد',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _dateBtn(
                  lang.isEnglish ? 'From' : 'سے',
                  _fmtDate(_fromDate),
                      () => _pickDate(true),
                  lang
              )),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: Colors.grey)),
              Expanded(child: _dateBtn(
                  lang.isEnglish ? 'To' : 'تک',
                  _fmtDate(_toDate),
                      () => _pickDate(false),
                  lang
              )),
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
                label: Text(provider.salaryLoading
                    ? (lang.isEnglish ? 'Calculating...' : 'حساب ہو رہا ہے...')
                    : (lang.isEnglish ? 'Calculate Salary' : 'تنخواہ کا حساب لگائیں')
                ),
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
          _buildBreakdownCard(calc, lang),
          const SizedBox(height: 16),

          // Advances section
          if (calc.pendingAdvances.isNotEmpty) ...[
            _buildDeductionSection(
              title: lang.isEnglish ? 'Pending Advances' : 'زیر التواء ادوانسز',
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF6366F1),
              items: calc.pendingAdvances,
              selected: _selectedAdvances,
              isAdvance: true,
              lang: lang,
            ),
            const SizedBox(height: 16),
          ],

          // Expenses section
          if (calc.pendingExpenses.isNotEmpty) ...[
            _buildDeductionSection(
              title: lang.isEnglish ? 'Pending Expenses' : 'زیر التواء اخراجات',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFFEF4444),
              items: calc.pendingExpenses,
              selected: _selectedExpenses,
              isAdvance: false,
              lang: lang,
            ),
            const SizedBox(height: 16),
          ],

          // Final summary + save
          _buildFinalSummary(calc, lang),
        ],
      ]),
    );
  }

  // ── Attendance breakdown card ─────────────────────────────────────────────
  Widget _buildBreakdownCard(SalaryCalculation calc, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            lang.isEnglish ? 'Salary Breakdown' : 'تنخواہ کی تفصیل',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
          ),
          _badge(lang.isEnglish ? 'Preview' : 'پیش نظارہ', const Color(0xFF10B981)),
        ]),
        const SizedBox(height: 16),
        _resultRow(lang.isEnglish ? 'Period' : 'مدت', '${calc.fromDate} → ${calc.toDate}'),
        _resultRow(lang.isEnglish ? 'Total Days' : 'کل دن', '${calc.totalDays}'),
        const Divider(height: 20),
        _resultRow('✅ ${lang.isEnglish ? 'Present' : 'حاضر'}',  '${calc.presentDays} ${lang.isEnglish ? 'days' : 'دن'}', const Color(0xFF10B981)),
        _resultRow('❌ ${lang.isEnglish ? 'Absent' : 'غائب'}',   '${calc.absentDays} ${lang.isEnglish ? 'days' : 'دن'}',  const Color(0xFFEF4444)),
        _resultRow('⏱ ${lang.isEnglish ? 'Half Day' : 'نصف دن'}', '${calc.halfDays} ${lang.isEnglish ? 'days' : 'دن'}',    const Color(0xFFF59E0B)),
        _resultRow('🏖 ${lang.isEnglish ? 'Leave' : 'چھٹی'}',   '${calc.leaveDays} ${lang.isEnglish ? 'days' : 'دن'}',   const Color(0xFF8B5CF6)),
        const Divider(height: 20),
        _resultRow(lang.isEnglish ? 'Base Salary' : 'بنیادی تنخواہ', 'Rs. ${calc.baseSalary.toStringAsFixed(0)}'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              lang.isEnglish ? 'Calculated Salary' : 'حساب شدہ تنخواہ',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
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
    required LanguageProvider lang,
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
              selected.length == items.length
                  ? (lang.isEnglish ? 'Deselect All' : 'سب ہٹائیں')
                  : (lang.isEnglish ? 'Select All' : 'سب منتخب کریں'),
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

          // Translate category if needed
          String? displayCategory = category;
          if (category != null && !lang.isEnglish) {
            final catMap = {
              'Travel': 'سفر',
              'Food': 'کھانا',
              'Medical': 'طبی',
              'Uniform': 'یونیفارم',
              'Fine': 'جرمانہ',
              'Other': 'دیگر',
            };
            displayCategory = catMap[category] ?? category;
          }

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
                    if (displayCategory != null) ...[
                      _badge(displayCategory, color),
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
                              : (lang.isEnglish ? 'Full' : 'مکمل'),
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
                      Text(
                        lang.isEnglish
                            ? 'of ${fullAmount.toStringAsFixed(0)}'
                            : 'از ${fullAmount.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                      ),
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
  Widget _buildFinalSummary(SalaryCalculation calc, LanguageProvider lang) {
    final net = (calc.calculatedSalary - _totalSelectedDeductions).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          lang.isEnglish ? 'Payment Summary' : 'ادائیگی کا خلاصہ',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
        ),
        const SizedBox(height: 16),

        _resultRow(lang.isEnglish ? 'Calculated Salary' : 'حساب شدہ تنخواہ', 'Rs. ${calc.calculatedSalary.toStringAsFixed(0)}'),

        if (_totalSelectedAdvance > 0)
          _resultRow(lang.isEnglish ? 'Advance Deduction' : 'ادوانس کٹوتی',
              '- Rs. ${_totalSelectedAdvance.toStringAsFixed(0)}',
              const Color(0xFF6366F1)),

        if (_totalSelectedExpense > 0)
          _resultRow(lang.isEnglish ? 'Expense Deduction' : 'خرچ کٹوتی',
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
            Text(
              lang.isEnglish ? 'Net Payable' : 'قابل ادائیگی',
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
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
            label: Text(lang.isEnglish ? 'Save Payment' : 'ادائیگی محفوظ کریں'),
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
  Widget _buildHistoryTab(EmployeeProvider provider, LanguageProvider lang) {
    if (provider.salaryHistory.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            lang.isEnglish ? 'No payments yet' : 'ابھی تک کوئی ادائیگی نہیں',
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: provider.salaryHistory.length,
      itemBuilder: (ctx, i) {
        final p = provider.salaryHistory[i];

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
                title: Text(lang.isEnglish ? 'Delete Payment' : 'ادائیگی حذف کریں'),
                content: Text(
                  lang.isEnglish
                      ? 'Delete salary for period ${p.fromDate} → ${p.toDate}?\n\nThis will also revert any advances/expenses marked as recovered.'
                      : 'مدت ${p.fromDate} → ${p.toDate} کی تنخواہ حذف کریں؟\n\nاس سے واپس شدہ کے طور پر نشان زد کردہ کسی بھی ادوانس/اخراجات کو بھی بحال کر دیا جائے گا۔',
                  style: const TextStyle(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(lang.isEnglish ? 'Cancel' : 'منسوخ کریں'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(lang.isEnglish ? 'Delete' : 'حذف کریں'),
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
                  content: Text(result['success']
                      ? (lang.isEnglish ? 'Payment deleted!' : 'ادائیگی حذف ہو گئی!')
                      : (result['message'] ?? (lang.isEnglish ? 'Failed to delete' : 'حذف کرنے میں ناکام'))),
                  backgroundColor: result['success'] ? const Color(0xFF10B981) : Colors.red,
                ),
              );
              if (!result['success']) {
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
                    GestureDetector(
                      onTap: () => _deletePayment({
                        'id': p.id,
                        'from_date': p.fromDate,
                        'to_date': p.toDate,
                      }, lang),
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
                _historyChip('${p.totalDays} ${lang.isEnglish ? 'days' : 'دن'}', Colors.grey),
              ]),
              if ((p.advanceDeduction ?? 0) > 0 || (p.expenseDeduction ?? 0) > 0) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  if ((p.advanceDeduction ?? 0) > 0)
                    _historyChip(
                        '${lang.isEnglish ? 'Adv' : 'ادوانس'}: -Rs. ${p.advanceDeduction!.toStringAsFixed(0)}',
                        const Color(0xFF6366F1)),
                  if ((p.expenseDeduction ?? 0) > 0)
                    _historyChip(
                        '${lang.isEnglish ? 'Exp' : 'خرچ'}: -Rs. ${p.expenseDeduction!.toStringAsFixed(0)}',
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

  Future<void> _deletePayment(Map<String, dynamic> payment, LanguageProvider lang) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lang.isEnglish ? 'Delete Payment' : 'ادائیگی حذف کریں'),
        content: Text(
          lang.isEnglish
              ? 'Are you sure you want to delete salary payment for period\n'
              '${payment['from_date']} → ${payment['to_date']}?\n\n'
              'This will also revert any advances/expenses marked as recovered.'
              : 'کیا آپ واقعی مدت ${payment['from_date']} → ${payment['to_date']} کی تنخواہ کی ادائیگی حذف کرنا چاہتے ہیں؟\n\nاس سے واپس شدہ کے طور پر نشان زد کردہ کسی بھی ادوانس/اخراجات کو بھی بحال کر دیا جائے گا۔',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(lang.isEnglish ? 'Delete' : 'حذف کریں'),
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
            content: Text(result['success']
                ? (lang.isEnglish ? 'Payment deleted successfully!' : 'ادائیگی کامیابی سے حذف ہو گئی!')
                : (result['message'] ?? (lang.isEnglish ? 'Failed to delete payment' : 'ادائیگی حذف کرنے میں ناکام'))),
            backgroundColor: result['success'] ? const Color(0xFF10B981) : Colors.red,
          ),
        );
      }
    }
  }

  Widget _dateBtn(String label, String value, VoidCallback onTap, LanguageProvider lang) => InkWell(
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