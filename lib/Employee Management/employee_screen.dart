// screens/employee_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../providers/employee_provider.dart';
import 'advance_ledger_screen.dart';
import 'attendance_screen.dart';
import 'emp_expense_ledger_screen.dart';
import 'salary_screen.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EmployeeProvider>(context, listen: false).loadEmployees();
    });
  }

  // ── Salary-type chip colors ──────────────────────────────────────────────
  Color _typeColor(SalaryType t) {
    switch (t) {
      case SalaryType.Daily:    return const Color(0xFF10B981);
      case SalaryType.Monthly:  return const Color(0xFF3B82F6);
      case SalaryType.Contract: return const Color(0xFFF59E0B);
    }
  }

  // ── Add / Edit dialog ────────────────────────────────────────────────────
  void _showEmployeeDialog({Employee? employee}) {
    final nameCtrl      = TextEditingController(text: employee?.name ?? '');
    final fatherCtrl    = TextEditingController(text: employee?.fatherName ?? '');
    final phoneCtrl     = TextEditingController(text: employee?.phone ?? '');
    final addressCtrl   = TextEditingController(text: employee?.address ?? '');
    final salaryCtrl    = TextEditingController(text: employee?.salary.toString() ?? '');
    SalaryType selectedType = employee?.salaryType ?? SalaryType.Monthly;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
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
                      Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6366F1)]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            employee == null ? 'Add Employee' : 'Edit Employee',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Name & Father Name
                      Row(children: [
                        Expanded(child: _buildField(nameCtrl,   'Full Name',    Icons.person_outline,    required: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField(fatherCtrl, 'Father Name',  Icons.family_restroom,   required: true)),
                      ]),
                      const SizedBox(height: 12),

                      // Phone
                      _buildField(phoneCtrl, 'Phone Number', Icons.phone_outlined, required: true, keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),

                      // Address
                      _buildField(addressCtrl, 'Address (optional)', Icons.location_on_outlined, maxLines: 2),
                      const SizedBox(height: 12),

                      // Salary & Type row
                      Row(children: [
                        Expanded(
                          child: _buildField(
                            salaryCtrl, 'Salary (Rs.)', Icons.payments_outlined,
                            required: true, keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (double.tryParse(v) == null) return 'Invalid number';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Salary Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F6FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<SalaryType>(
                                    value: selectedType,
                                    isExpanded: true,
                                    items: SalaryType.values.map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t.name, style: TextStyle(color: _typeColor(t), fontWeight: FontWeight.w600)),
                                    )).toList(),
                                    onChanged: (v) => setS(() => selectedType = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // Actions
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final provider = Provider.of<EmployeeProvider>(context, listen: false);
                            final payload = {
                              'name':        nameCtrl.text.trim(),
                              'father_name': fatherCtrl.text.trim(),
                              'phone':       phoneCtrl.text.trim(),
                              'address':     addressCtrl.text.trim(),
                              'salary':      double.parse(salaryCtrl.text.trim()),
                              'salary_type': selectedType.name,
                            };
                            Map<String, dynamic> res;
                            if (employee == null) {
                              res = await provider.createEmployee(payload);
                            } else {
                              res = await provider.updateEmployee(employee.id, payload);
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
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(employee == null ? 'Add Employee' : 'Update'),
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

  Widget _buildField(
      TextEditingController ctrl,
      String label,
      IconData icon, {
        bool required = false,
        TextInputType keyboardType = TextInputType.text,
        int maxLines = 1,
        String? Function(String?)? validator,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.grey[500]),
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7C3AED)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: validator ?? (required
              ? (v) => (v == null || v.isEmpty) ? 'Required' : null
              : null),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Employee'),
        content: Text('Delete "${employee.name}"? This will also remove all attendance and salary records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await Provider.of<EmployeeProvider>(context, listen: false).deleteEmployee(employee.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          body: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Employees', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                          const SizedBox(height: 4),
                          Text('${provider.employees.length} employees', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                        ]),
                        ElevatedButton.icon(
                          onPressed: () => _showEmployeeDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Employee'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    Container(
                      height: 46,
                      decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search employees...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: provider.searchEmployees,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Stats row ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                color: Colors.white,
                child: Row(children: [
                  _statChip(Icons.people, '${provider.employees.length}', 'Total', const Color(0xFF7C3AED)),
                  const SizedBox(width: 12),
                  _statChip(Icons.calendar_today, '${provider.employees.where((e) => e.salaryType == SalaryType.Daily).length}', 'Daily', const Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  _statChip(Icons.date_range, '${provider.employees.where((e) => e.salaryType == SalaryType.Monthly).length}', 'Monthly', const Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  _statChip(Icons.handshake_outlined, '${provider.employees.where((e) => e.salaryType == SalaryType.Contract).length}', 'Contract', const Color(0xFFF59E0B)),
                ]),
              ),

              const Divider(height: 1),

              // ── Employee list ─────────────────────────────────────────────
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.employees.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: provider.employees.length,
                  itemBuilder: (ctx, i) => _buildEmployeeCard(provider.employees[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
          ]),
        ]),
      ),
    );
  }

  Widget _buildEmployeeCard(Employee emp) {
    final typeColor = _typeColor(emp.salaryType);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [typeColor, typeColor.withOpacity(0.7)]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(emp.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                    const SizedBox(height: 2),
                    Text('S/O ${emp.fatherName}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.phone_outlined, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(emp.phone, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ]),
                  ]),
                ),

                // Salary + type badge
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Rs. ${emp.salary.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: typeColor)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(emp.salaryType.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: typeColor)),
                  ),
                ]),
              ],
            ),
            //
            // const SizedBox(height: 12),
            // const Divider(height: 1),
            // const SizedBox(height: 12),
            //
            // // Action buttons
            // Row(children: [
            //   _actionBtn(
            //     icon: Icons.checklist_outlined,
            //     label: 'Attendance',
            //     color: const Color(0xFF10B981),
            //     onTap: () => Navigator.push(context, MaterialPageRoute(
            //       builder: (_) => AttendanceScreen(employee: emp),
            //     )),
            //   ),
            //   const SizedBox(width: 8),
            //   _actionBtn(
            //     icon: Icons.payments_outlined,
            //     label: 'Salary',
            //     color: const Color(0xFF3B82F6),
            //     onTap: () => Navigator.push(context, MaterialPageRoute(
            //       builder: (_) => SalaryScreen(employee: emp),
            //     )),
            //   ),
            //   const SizedBox(width: 8),
            //   _actionBtn(
            //     icon: Icons.edit_outlined,
            //     label: 'Edit',
            //     color: const Color(0xFF7C3AED),
            //     onTap: () => _showEmployeeDialog(employee: emp),
            //   ),
            //   const SizedBox(width: 8),
            //   _actionBtn(
            //     icon: Icons.delete_outline,
            //     label: 'Delete',
            //     color: const Color(0xFFEF4444),
            //     onTap: () => _confirmDelete(emp),
            //   ),
            // ]),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

// Row 1 — Attendance & Salary
            Row(children: [
              _actionBtn(
                icon: Icons.checklist_outlined,
                label: 'Attendance',
                color: const Color(0xFF10B981),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AttendanceScreen(employee: emp),
                )),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                icon: Icons.payments_outlined,
                label: 'Salary',
                color: const Color(0xFF3B82F6),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SalaryScreen(employee: emp),
                )),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: const Color(0xFF7C3AED),
                onTap: () => _showEmployeeDialog(employee: emp),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: const Color(0xFFEF4444),
                onTap: () => _confirmDelete(emp),
              ),
            ]),
            const SizedBox(height: 8),

            // Row 2 — Advance & Expense
            Row(children: [
              _actionBtn(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Advances',
                color: const Color(0xFF6366F1),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AdvanceLedgerScreen(employee: emp),
                )),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                icon: Icons.receipt_long_outlined,
                label: 'Expenses',
                color: const Color(0xFFF59E0B),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => EmpExpenseLedgerScreen(employee: emp),
                )),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text('No employees found', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
      const SizedBox(height: 8),
      Text('Tap "+ Add Employee" to get started', style: TextStyle(color: Colors.grey[400])),
    ]),
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}