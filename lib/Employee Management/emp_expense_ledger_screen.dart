// screens/emp_expense_ledger_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../models/advance_expense.dart';
import '../providers/employee_provider.dart';

class EmpExpenseLedgerScreen extends StatefulWidget {
  final Employee employee;
  const EmpExpenseLedgerScreen({super.key, required this.employee});

  @override
  State<EmpExpenseLedgerScreen> createState() => _EmpExpenseLedgerScreenState();
}

class _EmpExpenseLedgerScreenState extends State<EmpExpenseLedgerScreen> {
  String _filter   = 'all';
  String? _catFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    Provider.of<EmployeeProvider>(context, listen: false).loadEmpExpenses(
      widget.employee.id,
      status:   _filter == 'all' ? null : _filter,
      category: _catFilter,
    );
  }

  // ── Category meta ────────────────────────────────────────────────────────
  static const _catColors = {
    'Travel':  Color(0xFF3B82F6),
    'Food':    Color(0xFF10B981),
    'Medical': Color(0xFFEF4444),
    'Uniform': Color(0xFF8B5CF6),
    'Fine':    Color(0xFFF59E0B),
    'Other':   Color(0xFF6B7280),
  };

  static const _catIcons = {
    'Travel':  Icons.directions_car_outlined,
    'Food':    Icons.restaurant_outlined,
    'Medical': Icons.medical_services_outlined,
    'Uniform': Icons.checkroom_outlined,
    'Fine':    Icons.gavel_outlined,
    'Other':   Icons.category_outlined,
  };

  Color _catColor(String cat)   => _catColors[cat] ?? const Color(0xFF6B7280);
  IconData _catIcon(String cat) => _catIcons[cat]  ?? Icons.category_outlined;

  // ── Add / Edit dialog ────────────────────────────────────────────────────
  void _showDialog({EmployeeExpense? existing}) {
    final amtCtrl  = TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime selectedDate = existing?.date ?? DateTime.now();
    String selectedCat    = existing?.category.name ?? 'Other';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF59E0B)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long_outlined, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Text(existing == null ? 'Add Expense' : 'Edit Expense',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                      ]),
                      const SizedBox(height: 20),

                      // Date
                      _label('Date'),
                      InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020), lastDate: DateTime.now(),
                            builder: (c, ch) => Theme(data: Theme.of(c).copyWith(
                                colorScheme: const ColorScheme.light(primary: Color(0xFFEF4444))), child: ch!),
                          );
                          if (d != null) setS(() => selectedDate = d);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.calendar_today, size: 16, color: Color(0xFFEF4444)),
                            const SizedBox(width: 8),
                            Text(_fmt(selectedDate),
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3142))),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Category chips
                      _label('Category'),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: ExpenseCategory.values.map((cat) {
                          final name     = cat.name;
                          final selected = selectedCat == name;
                          final color    = _catColor(name);
                          return GestureDetector(
                            onTap: () => setS(() => selectedCat = name),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: selected ? color : color.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: color.withOpacity(0.4)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(_catIcon(name), size: 14,
                                    color: selected ? Colors.white : color),
                                const SizedBox(width: 5),
                                Text(name, style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: selected ? Colors.white : color)),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Amount
                      _label('Amount (Rs.)'),
                      TextFormField(
                        controller: amtCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDec(Icons.currency_rupee),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Description
                      _label('Description (optional)'),
                      TextFormField(controller: descCtrl, maxLines: 2, decoration: _inputDec(Icons.notes_outlined)),
                      const SizedBox(height: 20),

                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final provider = Provider.of<EmployeeProvider>(context, listen: false);
                            final payload  = {
                              'employee_id': widget.employee.id,
                              'amount':      double.parse(amtCtrl.text.trim()),
                              'date':        selectedDate.toIso8601String().split('T')[0],
                              'category':    selectedCat,
                              'description': descCtrl.text.trim(),
                            };
                            Map<String, dynamic> res;
                            if (existing == null) {
                              res = await provider.createEmpExpense(payload);
                            } else {
                              res = await provider.updateEmpExpense(existing.id, payload, widget.employee.id);
                            }
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (!res['success']) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(res['message'] ?? 'Error'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(existing == null ? 'Add' : 'Update'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(EmployeeExpense exp) async {
    if (exp.status == ExpenseStatus.recovered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete a recovered expense'), backgroundColor: Colors.orange),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense'),
        content: Text('Delete ${exp.category.name} expense of Rs. ${exp.amount.toStringAsFixed(0)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await Provider.of<EmployeeProvider>(context, listen: false)
          .deleteEmpExpense(exp.id, widget.employee.id);
    }
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, provider, _) {
        final expenses = provider.empExpenses;
        final summary  = provider.expenseSummary;

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          appBar: AppBar(
            backgroundColor: Colors.white, elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.employee.name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
              const Text('Expense Ledger', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
            ]),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFFEF4444), size: 28),
                onPressed: () => _showDialog(),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: provider.empExpenseLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
            if (summary != null) _buildSummaryBanner(summary),

            // ── Filters ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status filter
                  Row(children: [
                    _filterChip('All',       'all'),
                    const SizedBox(width: 8),
                    _filterChip('Pending',   'pending'),
                    const SizedBox(width: 8),
                    _filterChip('Recovered', 'recovered'),
                  ]),
                  const SizedBox(height: 8),
                  // Category filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _catChip('All', null),
                      ...ExpenseCategory.values.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _catChip(c.name, c.name),
                      )),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: expenses.isEmpty
                  ? _empty()
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: expenses.length,
                itemBuilder: (_, i) => _buildRow(expenses[i], i, expenses.length),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildSummaryBanner(LedgerSummary s) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF59E0B)]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _bannerStat('Total',     s.totalAmount,    Colors.white),
        _vDivider(),
        _bannerStat('Recovered', s.totalRecovered, const Color(0xFFA5F3FC)),
        _vDivider(),
        _bannerStat('Pending',   s.pendingBalance, const Color(0xFFFDE68A)),
      ],
    ),
  );

  Widget _bannerStat(String label, double val, Color color) => Column(children: [
    Text('Rs. ${val.toStringAsFixed(0)}',
        style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: color.withOpacity(0.85), fontSize: 11)),
  ]);

  Widget _vDivider() => Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3));

  Widget _buildRow(EmployeeExpense exp, int index, int total) {
    final isPending   = exp.status == ExpenseStatus.pending;
    final statusColor = isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final catColor    = _catColor(exp.category.name);
    final isLast      = index == total - 1;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 20 : 0),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Timeline
          SizedBox(
            width: 40,
            child: Column(children: [
              if (index != 0)
                Expanded(child: Center(child: Container(width: 2, color: Colors.grey[200]))),
              Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: catColor, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: catColor.withOpacity(0.4), blurRadius: 4)],
                ),
              ),
              if (!isLast)
                Expanded(child: Center(child: Container(width: 2, color: Colors.grey[200]))),
            ]),
          ),

          // Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 8, bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0F0F5)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_catIcon(exp.category.name), size: 12, color: catColor),
                        const SizedBox(width: 4),
                        Text(exp.category.name,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: catColor)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(_fmt(exp.date), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(isPending ? 'Pending' : 'Recovered',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text('Rs. ${exp.amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                if (exp.description != null && exp.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(exp.description!, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
                if (isPending) ...[
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    _iconBtn(Icons.edit_outlined, const Color(0xFF6366F1), () => _showDialog(existing: exp)),
                    const SizedBox(width: 8),
                    _iconBtn(Icons.delete_outline, const Color(0xFFEF4444), () => _delete(exp)),
                  ]),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () { setState(() => _filter = value); _load(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEF4444) : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.grey[600],
        )),
      ),
    );
  }

  Widget _catChip(String label, String? value) {
    final selected = _catFilter == value;
    final color    = value != null ? _catColor(value) : const Color(0xFF6B7280);
    return GestureDetector(
      onTap: () { setState(() => _catFilter = value); _load(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : color,
        )),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 18),
    ),
  );

  Widget _empty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text('No expense records found', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: () => _showDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
  );

  InputDecoration _inputDec(IconData icon) => InputDecoration(
    prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
    filled: true, fillColor: const Color(0xFFF5F6FA),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}