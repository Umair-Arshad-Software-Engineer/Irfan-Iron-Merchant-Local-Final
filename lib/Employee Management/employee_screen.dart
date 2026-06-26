// screens/employee_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../providers/employee_provider.dart';
import '../providers/lanprovider.dart';
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
  final ScrollController _scrollController = ScrollController();

  // Responsive breakpoints
  static const double _mobileBreakpoint = 600;
  static const double _tabletBreakpoint = 900;

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
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width > _mobileBreakpoint ? 560 : double.infinity,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Padding(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width > _mobileBreakpoint ? 32 : 20),
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
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6366F1)]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              employee == null
                                  ? (lang.isEnglish ? 'Add Employee' : 'ملازم شامل کریں')
                                  : (lang.isEnglish ? 'Edit Employee' : 'ملازم میں ترمیم کریں'),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Name & Father Name - Responsive layout
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > _mobileBreakpoint) {
                            return Row(children: [
                              Expanded(child: _buildField(
                                  nameCtrl,
                                  lang.isEnglish ? 'Full Name' : 'مکمل نام',
                                  Icons.person_outline,
                                  required: true
                              )),
                              const SizedBox(width: 14),
                              Expanded(child: _buildField(
                                  fatherCtrl,
                                  lang.isEnglish ? 'Father Name' : 'والد کا نام',
                                  Icons.family_restroom,
                                  required: true
                              )),
                            ]);
                          }
                          return Column(children: [
                            _buildField(
                                nameCtrl,
                                lang.isEnglish ? 'Full Name' : 'مکمل نام',
                                Icons.person_outline,
                                required: true
                            ),
                            const SizedBox(height: 14),
                            _buildField(
                                fatherCtrl,
                                lang.isEnglish ? 'Father Name' : 'والد کا نام',
                                Icons.family_restroom,
                                required: true
                            ),
                          ]);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Phone
                      _buildField(
                          phoneCtrl,
                          lang.isEnglish ? 'Phone Number' : 'فون نمبر',
                          Icons.phone_outlined,
                          required: true,
                          keyboardType: TextInputType.phone
                      ),
                      const SizedBox(height: 14),

                      // Address
                      _buildField(
                          addressCtrl,
                          lang.isEnglish ? 'Address (optional)' : 'پتہ (اختیاری)',
                          Icons.location_on_outlined,
                          maxLines: 2
                      ),
                      const SizedBox(height: 14),

                      // Salary & Type row - Responsive
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > _mobileBreakpoint) {
                            return Row(children: [
                              Expanded(
                                child: _buildField(
                                  salaryCtrl,
                                  lang.isEnglish ? 'Salary (Rs.)' : 'تنخواہ (روپے)',
                                  Icons.payments_outlined,
                                  required: true,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return lang.isEnglish ? 'Required' : 'ضروری';
                                    if (double.tryParse(v) == null) return lang.isEnglish ? 'Invalid number' : 'غلط نمبر';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: _buildSalaryTypeDropdown(selectedType, setS, lang)),
                            ]);
                          }
                          return Column(children: [
                            _buildField(
                              salaryCtrl,
                              lang.isEnglish ? 'Salary (Rs.)' : 'تنخواہ (روپے)',
                              Icons.payments_outlined,
                              required: true,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return lang.isEnglish ? 'Required' : 'ضروری';
                                if (double.tryParse(v) == null) return lang.isEnglish ? 'Invalid number' : 'غلط نمبر';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildSalaryTypeDropdown(selectedType, setS, lang),
                          ]);
                        },
                      ),
                      const SizedBox(height: 28),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              lang.isEnglish ? 'Cancel' : 'منسوخ کریں',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;

                              final provider = Provider.of<EmployeeProvider>(context, listen: false);

                              final payload = {
                                'name': nameCtrl.text.trim(),
                                'father_name': fatherCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'address': addressCtrl.text.trim(),
                                'salary': double.parse(salaryCtrl.text.trim()),
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
                                  SnackBar(
                                    content: Text(res['message'] ?? (lang.isEnglish ? 'Error' : 'خرابی')),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 38),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              employee == null
                                  ? (lang.isEnglish ? 'Add Employee' : 'ملازم شامل کریں')
                                  : (lang.isEnglish ? 'Update' : 'اپ ڈیٹ کریں'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
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

  Widget _buildSalaryTypeDropdown(SalaryType selectedType, StateSetter setS, LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            lang.isEnglish ? 'Salary Type' : 'تنخواہ کی قسم',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))
        ),
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
              items: SalaryType.values.map((t) {
                String label = t.name;
                if (!lang.isEnglish) {
                  switch (t) {
                    case SalaryType.Daily: label = 'روزانہ'; break;
                    case SalaryType.Monthly: label = 'ماہانہ'; break;
                    case SalaryType.Contract: label = 'معاہدہ'; break;
                  }
                }
                return DropdownMenuItem(
                  value: t,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _typeColor(t),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (v) => setS(() => selectedType = v!),
            ),
          ),
        ),
      ],
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
    final lang = Provider.of<LanguageProvider>(context, listen: false);
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
            prefixIcon: Icon(icon, size: 20, color: Colors.grey[500]),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          validator: validator ?? (required
              ? (v) => (v == null || v.isEmpty)
              ? (lang.isEnglish ? 'Required' : 'ضروری')
              : null
              : null),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(Employee employee) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lang.isEnglish ? 'Delete Employee' : 'ملازم حذف کریں'),
        content: Text(
          lang.isEnglish
              ? 'Delete "${employee.name}"? This will also remove all attendance and salary records.'
              : '"${employee.name}" کو حذف کریں؟ اس سے تمام حاضری اور تنخواہ کے ریکارڈ بھی حذف ہو جائیں گے۔',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.isEnglish ? 'Cancel' : 'منسوخ کریں', style: const TextStyle(fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(lang.isEnglish ? 'Delete' : 'حذف کریں', style: const TextStyle(fontSize: 15)),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < _mobileBreakpoint;
    final isTablet = screenWidth >= _mobileBreakpoint && screenWidth < _tabletBreakpoint;
    final isDesktop = screenWidth >= _tabletBreakpoint;
    final lang = Provider.of<LanguageProvider>(context);

    return Consumer<EmployeeProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          body: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 48 : (isTablet ? 32 : 20),
                  vertical: isDesktop ? 32 : 24,
                ),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.isEnglish ? 'Employees' : 'ملازمین',
                              style: TextStyle(
                                fontSize: isDesktop ? 32 : (isTablet ? 28 : 24),
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2D3142),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lang.isEnglish
                                  ? '${provider.employees.length} employees'
                                  : '${provider.employees.length} ملازمین',
                              style: TextStyle(
                                fontSize: isDesktop ? 16 : 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showEmployeeDialog(),
                          icon: Icon(Icons.add, size: isDesktop ? 20 : 18),
                          label: Text(
                            isMobile
                                ? (lang.isEnglish ? 'Add' : 'شامل کریں')
                                : (lang.isEnglish ? 'Add Employee' : 'ملازم شامل کریں'),
                            style: TextStyle(
                              fontSize: isDesktop ? 15 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 28 : 20,
                              vertical: isDesktop ? 16 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    Container(
                      height: isDesktop ? 52 : 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: lang.isEnglish ? 'Search employees...' : 'ملازمین تلاش کریں...',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: isDesktop ? 15 : 14),
                          prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: isDesktop ? 22 : 20),
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
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 48 : (isTablet ? 32 : 20),
                  vertical: 12,
                ),
                color: Colors.white,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dailyCount = provider.employees.where((e) => e.salaryType == SalaryType.Daily).length;
                    final monthlyCount = provider.employees.where((e) => e.salaryType == SalaryType.Monthly).length;
                    final contractCount = provider.employees.where((e) => e.salaryType == SalaryType.Contract).length;

                    if (constraints.maxWidth < 500) {
                      // Mobile: Wrap stats in a row that can scroll
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _statChip(
                              Icons.people,
                              '${provider.employees.length}',
                              lang.isEnglish ? 'Total' : 'کل',
                              const Color(0xFF7C3AED)
                          ),
                          const SizedBox(width: 12),
                          _statChip(
                              Icons.calendar_today,
                              '$dailyCount',
                              lang.isEnglish ? 'Daily' : 'روزانہ',
                              const Color(0xFF10B981)
                          ),
                          const SizedBox(width: 12),
                          _statChip(
                              Icons.date_range,
                              '$monthlyCount',
                              lang.isEnglish ? 'Monthly' : 'ماہانہ',
                              const Color(0xFF3B82F6)
                          ),
                          const SizedBox(width: 12),
                          _statChip(
                              Icons.handshake_outlined,
                              '$contractCount',
                              lang.isEnglish ? 'Contract' : 'معاہدہ',
                              const Color(0xFFF59E0B)
                          ),
                        ]),
                      );
                    }
                    return Row(children: [
                      _statChip(
                          Icons.people,
                          '${provider.employees.length}',
                          lang.isEnglish ? 'Total' : 'کل',
                          const Color(0xFF7C3AED)
                      ),
                      const SizedBox(width: 12),
                      _statChip(
                          Icons.calendar_today,
                          '$dailyCount',
                          lang.isEnglish ? 'Daily' : 'روزانہ',
                          const Color(0xFF10B981)
                      ),
                      const SizedBox(width: 12),
                      _statChip(
                          Icons.date_range,
                          '$monthlyCount',
                          lang.isEnglish ? 'Monthly' : 'ماہانہ',
                          const Color(0xFF3B82F6)
                      ),
                      const SizedBox(width: 12),
                      _statChip(
                          Icons.handshake_outlined,
                          '$contractCount',
                          lang.isEnglish ? 'Contract' : 'معاہدہ',
                          const Color(0xFFF59E0B)
                      ),
                    ]);
                  },
                ),
              ),

              const Divider(height: 1),

              // ── Employee list ─────────────────────────────────────────────
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.employees.isEmpty
                    ? _buildEmptyState(lang)
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > _mobileBreakpoint;
                    return GridView.builder(
                      padding: EdgeInsets.all(isDesktop ? 32 : 20),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isWide ? (isDesktop ? 3 : 2) : 1,
                        crossAxisSpacing: isWide ? 16 : 0,
                        mainAxisSpacing: 16,
                        childAspectRatio: isWide ? 1.2 : 1.2,
                      ),
                      itemCount: provider.employees.length,
                      itemBuilder: (ctx, i) => _buildEmployeeCard(provider.employees[i], lang),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
    );
  }

  Widget _buildEmployeeCard(Employee emp, LanguageProvider lang) {
    final typeColor = _typeColor(emp.salaryType);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= _tabletBreakpoint;

    // Get localized salary type name
    String salaryTypeLabel = emp.salaryType.name;
    if (!lang.isEnglish) {
      switch (emp.salaryType) {
        case SalaryType.Daily: salaryTypeLabel = 'روزانہ'; break;
        case SalaryType.Monthly: salaryTypeLabel = 'ماہانہ'; break;
        case SalaryType.Contract: salaryTypeLabel = 'معاہدہ'; break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: isDesktop ? 56 : 50,
                  height: isDesktop ? 56 : 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [typeColor, typeColor.withOpacity(0.7)]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 22 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp.name,
                        style: TextStyle(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D3142),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lang.isEnglish ? 'S/O ${emp.fatherName}' : 'والد: ${emp.fatherName}',
                        style: TextStyle(fontSize: isDesktop ? 14 : 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.phone_outlined, size: isDesktop ? 15 : 13, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          emp.phone,
                          style: TextStyle(fontSize: isDesktop ? 14 : 13, color: Colors.grey[600]),
                        ),
                      ]),
                    ],
                  ),
                ),

                // Salary + type badge
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    'Rs. ${emp.salary.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      salaryTypeLabel,
                      style: TextStyle(
                        fontSize: isDesktop ? 13 : 12,
                        fontWeight: FontWeight.w600,
                        color: typeColor,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Action buttons - Responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                final attendanceLabel = lang.isEnglish ? 'Attendance' : 'حاضری';
                final salaryLabel = lang.isEnglish ? 'Salary' : 'تنخواہ';
                final editLabel = lang.isEnglish ? 'Edit' : 'ترمیم';
                final deleteLabel = lang.isEnglish ? 'Delete' : 'حذف';
                final advancesLabel = lang.isEnglish ? 'Advances' : 'ادوانسز';
                final expensesLabel = lang.isEnglish ? 'Expenses' : 'اخراجات';

                if (constraints.maxWidth < 350) {
                  // Very small screens - stack buttons in two rows
                  return Column(children: [
                    Row(children: [
                      _actionBtn(
                        icon: Icons.checklist_outlined,
                        label: attendanceLabel,
                        color: const Color(0xFF10B981),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AttendanceScreen(employee: emp),
                        )),
                      ),
                      const SizedBox(width: 8),
                      _actionBtn(
                        icon: Icons.payments_outlined,
                        label: salaryLabel,
                        color: const Color(0xFF3B82F6),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => SalaryScreen(employee: emp),
                        )),
                      ),
                      const SizedBox(width: 8),
                      _actionBtn(
                        icon: Icons.edit_outlined,
                        label: editLabel,
                        color: const Color(0xFF7C3AED),
                        onTap: () => _showEmployeeDialog(employee: emp),
                      ),
                      const SizedBox(width: 8),
                      _actionBtn(
                        icon: Icons.delete_outline,
                        label: deleteLabel,
                        color: const Color(0xFFEF4444),
                        onTap: () => _confirmDelete(emp),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _actionBtn(
                        icon: Icons.account_balance_wallet_outlined,
                        label: advancesLabel,
                        color: const Color(0xFF6366F1),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AdvanceLedgerScreen(employee: emp),
                        )),
                      ),
                      const SizedBox(width: 8),
                      _actionBtn(
                        icon: Icons.receipt_long_outlined,
                        label: expensesLabel,
                        color: const Color(0xFFF59E0B),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => EmpExpenseLedgerScreen(employee: emp),
                        )),
                      ),
                    ]),
                  ]);
                }
                // Normal layout - all buttons in one row
                return Row(children: [
                  _actionBtn(
                    icon: Icons.checklist_outlined,
                    label: attendanceLabel,
                    color: const Color(0xFF10B981),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AttendanceScreen(employee: emp),
                    )),
                  ),
                  const SizedBox(width: 8),
                  _actionBtn(
                    icon: Icons.payments_outlined,
                    label: salaryLabel,
                    color: const Color(0xFF3B82F6),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => SalaryScreen(employee: emp),
                    )),
                  ),
                  const SizedBox(width: 8),
                  _actionBtn(
                    icon: Icons.edit_outlined,
                    label: editLabel,
                    color: const Color(0xFF7C3AED),
                    onTap: () => _showEmployeeDialog(employee: emp),
                  ),
                  const SizedBox(width: 8),
                  _actionBtn(
                    icon: Icons.delete_outline,
                    label: deleteLabel,
                    color: const Color(0xFFEF4444),
                    onTap: () => _confirmDelete(emp),
                  ),
                  const SizedBox(width: 8),
                  _actionBtn(
                    icon: Icons.account_balance_wallet_outlined,
                    label: advancesLabel,
                    color: const Color(0xFF6366F1),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AdvanceLedgerScreen(employee: emp),
                    )),
                  ),
                  const SizedBox(width: 8),
                  _actionBtn(
                    icon: Icons.receipt_long_outlined,
                    label: expensesLabel,
                    color: const Color(0xFFF59E0B),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => EmpExpenseLedgerScreen(employee: emp),
                    )),
                  ),
                ]);
              },
            ),
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
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider lang) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text(
          lang.isEnglish ? 'No employees found' : 'کوئی ملازم نہیں ملا',
          style: TextStyle(fontSize: 18, color: Colors.grey[500])
      ),
      const SizedBox(height: 8),
      Text(
          lang.isEnglish ? 'Tap "+ Add Employee" to get started' : 'شروع کرنے کے لیے "+ ملازم شامل کریں" پر ٹیپ کریں',
          style: TextStyle(color: Colors.grey[400])
      ),
    ]),
  );

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}