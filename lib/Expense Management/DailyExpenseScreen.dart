// lib/screens/expenses/daily_expense_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../models/supplier.dart';
import '../components/bankpicker.dart';
import '../providers/lanprovider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────
class ExpenseSession {
  final int id;
  final String sessionDate;
  double openingBalance;
  double totalExpenses;
  double totalSupplierPayments;
  double closingBalance;
  final bool isClosed;
  final List<ExpenseEntry> entries;

  ExpenseSession({
    required this.id,
    required this.sessionDate,
    required this.openingBalance,
    required this.totalExpenses,
    required this.totalSupplierPayments,
    required this.closingBalance,
    required this.isClosed,
    required this.entries,
  });

  factory ExpenseSession.fromJson(Map<String, dynamic> j) => ExpenseSession(
    id: j['id'],
    sessionDate: j['session_date'] ?? '',
    openingBalance: double.tryParse(j['opening_balance'].toString()) ?? 0,
    totalExpenses: double.tryParse(j['total_expenses'].toString()) ?? 0,
    totalSupplierPayments:
    double.tryParse(j['total_supplier_payments'].toString()) ?? 0,
    closingBalance: double.tryParse(j['closing_balance'].toString()) ?? 0,
    isClosed: j['is_closed'] == true,
    entries: (j['entries'] as List<dynamic>? ?? [])
        .map((e) => ExpenseEntry.fromJson(e))
        .toList(),
  );
}

class ExpenseEntry {
  final int id;
  final String entryType; // 'expense' | 'supplier_payment' | 'bill_payment'
  final String? category;
  final String description;
  final double amount;
  final String paymentMethod;
  final String? bankName;
  final String? chequeNumber;
  final String? referenceNumber;
  final String? supplierName;
  final DateTime entryTime;

  ExpenseEntry({
    required this.id,
    required this.entryType,
    this.category,
    required this.description,
    required this.amount,
    required this.paymentMethod,
    this.bankName,
    this.chequeNumber,
    this.referenceNumber,
    this.supplierName,
    required this.entryTime,
  });

  factory ExpenseEntry.fromJson(Map<String, dynamic> j) => ExpenseEntry(
    id: j['id'],
    entryType: j['entry_type'] ?? 'expense',
    category: j['category'],
    description: j['description'] ?? '',
    amount: double.tryParse(j['amount'].toString()) ?? 0,
    paymentMethod: j['payment_method'] ?? 'cash',
    bankName: j['bank_name'],
    chequeNumber: j['cheque_number'],
    referenceNumber: j['reference_number'],
    supplierName: j['supplier']?['name'],
    entryTime: DateTime.tryParse(j['entry_time'] ?? '') ?? DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class DailyExpenseScreen extends StatefulWidget {
  const DailyExpenseScreen({super.key});

  @override
  State<DailyExpenseScreen> createState() => _DailyExpenseScreenState();
}

class _DailyExpenseScreenState extends State<DailyExpenseScreen>
    with SingleTickerProviderStateMixin {
  ExpenseSession? _session;
  bool _isLoading = true;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final _df = DateFormat('MMM dd, yyyy');
  final _tf = DateFormat('hh:mm a');

  static const _primaryColor = Color(0xFF6366F1);
  static const _successColor = Color(0xFF10B981);
  static const _dangerColor = Color(0xFFEF4444);
  static const _warningColor = Color(0xFFF59E0B);
  static const _supplierColor = Color(0xFF8B5CF6);

  List<String> _getCategories(LanguageProvider lp) => [
    lp.isEnglish ? 'Fuel' : 'ایندھن',
    lp.isEnglish ? 'Food & Drinks' : 'کھانا اور مشروبات',
    lp.isEnglish ? 'Utilities' : 'یوٹیلیٹیز',
    lp.isEnglish ? 'Transport' : 'ٹرانسپورٹ',
    lp.isEnglish ? 'Stationery' : 'اسٹیشنری',
    lp.isEnglish ? 'Repairs' : 'مرمت',
    lp.isEnglish ? 'Salary' : 'تنخواہ',
    lp.isEnglish ? 'Miscellaneous' : 'متفرق',
  ];

  List<Map<String, dynamic>> _getMethods(LanguageProvider lp) => [
    {'value': 'cash', 'label': lp.isEnglish ? 'Cash' : 'نقد', 'icon': Icons.payments_outlined},
    {'value': 'bank', 'label': lp.isEnglish ? 'Bank' : 'بینک', 'icon': Icons.account_balance_outlined},
    {'value': 'cheque', 'label': lp.isEnglish ? 'Cheque' : 'چیک', 'icon': Icons.receipt_long_outlined},
    {'value': 'slip', 'label': lp.isEnglish ? 'Slip' : 'سلیپ', 'icon': Icons.receipt_outlined},
  ];

  static const _methodColors = {
    'cash': Color(0xFF10B981),
    'bank': Color(0xFF3B82F6),
    'cheque': Color(0xFFF59E0B),
    'slip': Color(0xFF8B5CF6),
  };

  List<Map<String, dynamic>> _getBillTypes(LanguageProvider lp) => [
    {'type': 'electricity', 'name': lp.isEnglish ? 'Electricity Bill' : 'بجلی کا بل', 'icon': Icons.bolt, 'color': const Color(0xFFF59E0B)},
    {'type': 'gas', 'name': lp.isEnglish ? 'Gas Bill' : 'گیس کا بل', 'icon': Icons.local_fire_department, 'color': const Color(0xFFEF4444)},
    {'type': 'telephone', 'name': lp.isEnglish ? 'Telephone Bill' : 'ٹیلیفون کا بل', 'icon': Icons.phone, 'color': const Color(0xFF3B82F6)},
    {'type': 'water', 'name': lp.isEnglish ? 'Water Bill' : 'پانی کا بل', 'icon': Icons.water_drop, 'color': const Color(0xFF10B981)},
    {'type': 'internet', 'name': lp.isEnglish ? 'Internet Bill' : 'انٹرنیٹ کا بل', 'icon': Icons.wifi, 'color': const Color(0xFF8B5CF6)},
    {'type': 'tv', 'name': lp.isEnglish ? 'TV Cable Bill' : 'ٹی وی کیبل کا بل', 'icon': Icons.tv, 'color': const Color(0xFFEC4899)},
    {'type': 'other', 'name': lp.isEnglish ? 'Other Bill' : 'دیگر بل', 'icon': Icons.receipt, 'color': const Color(0xFF6B7280)},
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadTodaySession();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String? _getToken() {
    try {
      return Provider.of<AuthProvider>(context, listen: false).user?.token;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
  };

  Future<void> _loadTodaySession() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/expense-sessions/today'),
        headers: _headers,
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        setState(() {
          _session = ExpenseSession.fromJson(data['data']);
          _error = null;
        });
        _animCtrl.forward(from: 0);
      } else {
        setState(() => _error = data['message'] ?? 'Failed to load session');
      }
    } catch (e) {
      setState(() => _error = 'Connection error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOpeningBalance(double newBalance) async {
    if (_session == null) return;
    try {
      final res = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/expense-sessions/${_session!.id}/opening-balance'),
        headers: _headers,
        body: json.encode({'opening_balance': newBalance}),
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        await _loadTodaySession();
      } else {
        _showError(data['message'] ?? 'Failed to update balance');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _deleteEntry(int entryId) async {
    if (_session == null) return;
    try {
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/expense-sessions/${_session!.id}/entries/$entryId'),
        headers: _headers,
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        await _loadTodaySession();
        if (mounted) {
          final lp = Provider.of<LanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lp.isEnglish ? 'Entry deleted' : 'اندراج حذف ہوگیا'),
            backgroundColor: Colors.green,
          ));
        }
      } else {
        _showError(data['message'] ?? 'Failed to delete');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  Future<void> _showOpeningBalanceDialog() async {
    if (_session == null) return;
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final ctrl = TextEditingController(text: _session!.openingBalance.toStringAsFixed(2));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, color: _primaryColor, size: 20),
          ),
          const SizedBox(width: 10),
          Text(lp.isEnglish ? 'Set Opening Balance' : 'ابتدائی بیلنس مقرر کریں',
              style: const TextStyle(fontSize: 16)),
        ]),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
          ],
          style: TextStyle(fontFamily: lp.fontFamily),
          decoration: InputDecoration(
            prefixText: 'Rs ',
            hintText: '0.00',
            filled: true,
            fillColor: const Color(0xFFF5F5F7),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primaryColor, width: 1.5)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lp.isEnglish ? 'Cancel' : 'منسوخ کریں')),
          ElevatedButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text);
              if (v == null || v < 0) return;
              Navigator.pop(ctx);
              await _updateOpeningBalance(v);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(lp.isEnglish ? 'Save' : 'محفوظ کریں',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddExpenseDialog() async {
    if (_session == null) return;
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AddExpenseDialog(
        sessionId: _session!.id,
        availableBalance: _session!.closingBalance,
        headers: _headers,
        isClosed: _session!.isClosed,
        languageProvider: lp,
        getToken: _getToken,
        methodColors: _methodColors,
        methods: _getMethods(lp),
        categories: _getCategories(lp),
      ),
    );
    if (result == true) await _loadTodaySession();
  }

  Future<void> _showSupplierPaymentDialog() async {
    if (_session == null) return;
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _SupplierPaymentFromSessionDialog(
        sessionId: _session!.id,
        availableBalance: _session!.closingBalance,
        headers: _headers,
        isClosed: _session!.isClosed,
        getToken: _getToken,
        languageProvider: lp,
        methodColors: _methodColors,
        methods: _getMethods(lp),
      ),
    );
    if (result == true) await _loadTodaySession();
  }

  Future<void> _showBillPaymentDialog() async {
    if (_session == null) return;
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _BillPaymentFromSessionDialog(
        sessionId: _session!.id,
        availableBalance: _session!.closingBalance,
        headers: _headers,
        isClosed: _session!.isClosed,
        getToken: _getToken,
        languageProvider: lp,
        methodColors: _methodColors,
        methods: _getMethods(lp),
        billTypes: _getBillTypes(lp),
      ),
    );
    if (result == true) await _loadTodaySession();
  }

  Future<void> _confirmDeleteEntry(ExpenseEntry entry) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lp.isEnglish ? 'Delete Entry?' : 'اندراج حذف کریں؟',
            style: const TextStyle(fontSize: 16)),
        content: Text(
          lp.isEnglish
              ? 'Delete "${entry.description}" (Rs ${entry.amount.toStringAsFixed(2)})?${entry.entryType == 'supplier_payment' ? '\n\nThis will also reverse the supplier ledger entry.' : ''}'
              : '"${entry.description}" (Rs ${entry.amount.toStringAsFixed(2)}) حذف کریں؟${entry.entryType == 'supplier_payment' ? '\n\nاس سے سپلائر لیجر اندراج بھی ریورس ہو جائے گا۔' : ''}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lp.isEnglish ? 'Cancel' : 'منسوخ کریں')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _dangerColor),
            child: Text(lp.isEnglish ? 'Delete' : 'حذف کریں',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteEntry(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F8FC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(languageProvider.isEnglish ? 'Daily Expenses' : 'روزانہ کے اخراجات',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E))),
                if (_session != null)
                  Text(
                    _df.format(DateTime.parse(_session!.sessionDate)),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_outlined, color: Color(0xFF8E8E93)),
                onPressed: _loadTodaySession,
                tooltip: languageProvider.isEnglish ? 'Refresh' : 'تازہ کریں',
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: _isLoading
              ? _buildLoading(languageProvider)
              : _error != null
              ? _buildError(languageProvider)
              : FadeTransition(opacity: _fadeAnim, child: _buildBody(languageProvider)),
          bottomNavigationBar: _session != null && !_session!.isClosed
              ? _buildBottomBar(languageProvider)
              : null,
        );
      },
    );
  }

  Widget _buildLoading(LanguageProvider lp) => const Center(
    child: CircularProgressIndicator(color: _primaryColor),
  );

  Widget _buildError(LanguageProvider lp) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: _dangerColor),
        const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontFamily: lp.fontFamily)),
        const SizedBox(height: 16),
        ElevatedButton(
            onPressed: _loadTodaySession,
            child: Text(lp.isEnglish ? 'Retry' : 'دوبارہ کوشش کریں')),
      ],
    ),
  );

  Widget _buildBody(LanguageProvider lp) {
    final s = _session!;
    return RefreshIndicator(
      onRefresh: _loadTodaySession,
      color: _primaryColor,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSessionCard(s, lp)),
          SliverToBoxAdapter(child: _buildStatsRow(s, lp)),
          if (s.entries.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState(lp))
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text(lp.isEnglish ? 'Entries' : 'اندراجات',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${s.entries.length}',
                          style: const TextStyle(fontSize: 11, color: _primaryColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildEntryTile(s.entries[i], s.isClosed, lp),
                childCount: s.entries.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSessionCard(ExpenseSession s, LanguageProvider lp) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(lp.isEnglish ? 'Cash Balance' : 'نقدی بیلنس',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              if (!s.isClosed)
                GestureDetector(
                  onTap: _showOpeningBalanceDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(lp.isEnglish ? 'Edit' : 'ترمیم کریں',
                            style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(lp.isEnglish ? 'Closed' : 'بند شدہ',
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Rs ${s.closingBalance.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 32,
                  fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('${lp.isEnglish ? 'Opening' : 'ابتدائی'}: Rs ${s.openingBalance.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ExpenseSession s, LanguageProvider lp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _statCard(lp.isEnglish ? 'Expenses' : 'اخراجات',
                'Rs ${s.totalExpenses.toStringAsFixed(2)}', Icons.receipt_long_outlined, _dangerColor, lp),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(lp.isEnglish ? 'Supplier Paid' : 'سپلائر کو ادا کیا',
                'Rs ${s.totalSupplierPayments.toStringAsFixed(2)}', Icons.person_outline, _supplierColor, lp),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(lp.isEnglish ? 'Entries' : 'اندراجات',
                '${s.entries.length}', Icons.list_alt_outlined, _primaryColor, lp),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color, fontFamily: lp.fontFamily)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider lp) => Padding(
    padding: const EdgeInsets.all(48),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _primaryColor.withOpacity(0.07), shape: BoxShape.circle),
          child: const Icon(Icons.receipt_long_outlined, size: 40, color: _primaryColor),
        ),
        const SizedBox(height: 16),
        Text(lp.isEnglish ? 'No entries yet' : 'ابھی تک کوئی اندراج نہیں',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E))),
        const SizedBox(height: 6),
        Text(
          lp.isEnglish ? 'Add expenses or supplier payments\nusing the buttons below' : 'نیچے دیے گئے بٹنوں کا استعمال کرتے ہوئے\nاخراجات یا سپلائر کی ادائیگیاں شامل کریں',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
        ),
      ],
    ),
  );

  Widget _buildEntryTile(ExpenseEntry entry, bool isClosed, LanguageProvider lp) {
    final isSupplier = entry.entryType == 'supplier_payment';
    final isBill = entry.entryType == 'bill_payment';
    final color = isSupplier ? _supplierColor : (isBill ? _warningColor : _dangerColor);
    final methodColor = _methodColors[entry.paymentMethod] ?? const Color(0xFF8E8E93);

    return Dismissible(
      key: Key('entry_${entry.id}'),
      direction: isClosed ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: _dangerColor, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _confirmDeleteEntry(entry);
        return false;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(
                isSupplier ? Icons.person_outlined : (isBill ? Icons.receipt_outlined : Icons.receipt_long_outlined),
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isSupplier ? (entry.supplierName ?? entry.description) : entry.description,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Rs ${entry.amount.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: methodColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          entry.paymentMethod.toUpperCase(),
                          style: TextStyle(fontSize: 9, color: methodColor, fontWeight: FontWeight.bold,
                              fontFamily: lp.fontFamily),
                        ),
                      ),
                      if (entry.bankName != null) ...[
                        const SizedBox(width: 6),
                        Text(entry.bankName!, style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
                      ],
                      if (entry.category != null) ...[
                        const SizedBox(width: 6),
                        Text('• ${entry.category!}', style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
                      ],
                      const Spacer(),
                      Text(_tf.format(entry.entryTime.toLocal()),
                          style: const TextStyle(fontSize: 10, color: Color(0xFFC7C7CC))),
                    ],
                  ),
                  if ((isSupplier || isBill) && entry.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(entry.description,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (!isClosed)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFC7C7CC)),
                onPressed: () => _confirmDeleteEntry(entry),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _actionBtn(lp.isEnglish ? 'Add Expense' : 'خرچ شامل کریں',
                Icons.add_circle_outline, _dangerColor, _showAddExpenseDialog, lp),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionBtn(lp.isEnglish ? 'Pay Supplier' : 'سپلائر کو ادائیگی کریں',
                Icons.person_add_outlined, _supplierColor, _showSupplierPaymentDialog, lp),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionBtn(lp.isEnglish ? 'Pay Bill' : 'بل ادا کریں',
                Icons.receipt_outlined, const Color(0xFFF59E0B), _showBillPaymentDialog, lp),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap, LanguageProvider lp) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD EXPENSE DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _AddExpenseDialog extends StatefulWidget {
  final int sessionId;
  final double availableBalance;
  final Map<String, String> headers;
  final bool isClosed;
  final LanguageProvider languageProvider;
  final String? Function() getToken;
  final Map<String, Color> methodColors;
  final List<Map<String, dynamic>> methods;
  final List<String> categories;

  const _AddExpenseDialog({
    required this.sessionId,
    required this.availableBalance,
    required this.headers,
    required this.isClosed,
    required this.languageProvider,
    required this.getToken,
    required this.methodColors,
    required this.methods,
    required this.categories,
  });

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _chequeNumCtrl = TextEditingController();

  String _paymentMethod = 'cash';
  int? _selectedBankId;
  String? _selectedBankName;
  String? _selectedBankIcon;
  String? _category;
  DateTime? _chequeDate;
  bool _isLoading = false;

  final _df = DateFormat('MMM dd, yyyy');

  Color get _activeColor => widget.methodColors[_paymentMethod] ?? const Color(0xFF10B981);

  Future<void> _submit() async {
    final lp = widget.languageProvider;
    if (!_formKey.currentState!.validate()) return;
    if ((_paymentMethod == 'bank' || _paymentMethod == 'cheque') && _selectedBankName == null) {
      _err(lp.isEnglish ? 'Please select a bank' : 'براہ کرم بینک منتخب کریں');
      return;
    }
    if (_paymentMethod == 'cheque') {
      if (_chequeNumCtrl.text.trim().isEmpty) {
        _err(lp.isEnglish ? 'Please enter cheque number' : 'براہ کرم چیک نمبر درج کریں');
        return;
      }
      if (_chequeDate == null) {
        _err(lp.isEnglish ? 'Please select cheque date' : 'براہ کرم چیک کی تاریخ منتخب کریں');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final amount = double.parse(_amountCtrl.text.trim());

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/expense-sessions/${widget.sessionId}/expenses'),
        headers: widget.headers,
        body: json.encode({
          'category': _category,
          'description': _descCtrl.text.trim(),
          'amount': amount,
          'payment_method': _paymentMethod,
          'bank_id': _selectedBankId,
          'bank_name': _selectedBankName,
          'cheque_number': _paymentMethod == 'cheque' ? _chequeNumCtrl.text.trim() : null,
          'cheque_date': _chequeDate != null ? DateFormat('yyyy-MM-dd').format(_chequeDate!) : null,
          'reference_number': _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        }),
      );

      final data = json.decode(res.body);
      if (res.statusCode == 201 && data['success'] == true) {
        if (mounted) Navigator.pop(context, true);
      } else {
        _err(data['message'] ?? (lp.isEnglish ? 'Failed to add expense' : 'خرچ شامل کرنے میں ناکامی'));
      }
    } catch (e) {
      _err('${lp.isEnglish ? 'Error' : 'خرابی'}: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  Future<void> _openBankPicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DbBankSheet(
        accentColor: _activeColor,
        token: widget.getToken(),
        languageProvider: widget.languageProvider,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedBankId = result['id'] as int;
        _selectedBankName = result['name'] as String;
        _selectedBankIcon = result['icon_path'] as String? ?? '';
      });
    }
  }

  Future<void> _pickChequeDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _chequeDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: _activeColor)),
        child: child!,
      ),
    );
    if (p != null) setState(() => _chequeDate = p);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    _chequeNumCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = widget.languageProvider;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.15))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: Color(0xFFEF4444), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lp.isEnglish ? 'Add Expense' : 'خرچ شامل کریں',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('${lp.isEnglish ? 'Available' : 'دستیاب'}: Rs ${widget.availableBalance.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _lbl(lp.isEnglish ? 'Category (optional)' : 'زمرہ (اختیاری)', lp),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: _inp(hint: lp.isEnglish ? 'Select category' : 'زمرہ منتخب کریں', lp: lp),
                      items: widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(fontFamily: lp.fontFamily)))).toList(),
                      onChanged: (v) => setState(() => _category = v),
                    ),
                    const SizedBox(height: 16),
                    _lbl(lp.isEnglish ? 'Description *' : 'تفصیل *', lp),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      style: TextStyle(fontFamily: lp.fontFamily),
                      decoration: _inp(hint: lp.isEnglish ? 'e.g. Fuel for delivery van' : 'مثال: ڈیلیوری وین کے لیے ایندھن', lp: lp),
                      validator: (v) => (v == null || v.isEmpty) ? (lp.isEnglish ? 'Required' : 'ضروری') : null,
                    ),
                    const SizedBox(height: 16),
                    _lbl(lp.isEnglish ? 'Amount *' : 'رقم *', lp),
                    const SizedBox(height: 6),
                    _buildAmountField(lp),
                    const SizedBox(height: 16),
                    _lbl(lp.isEnglish ? 'Payment Method *' : 'ادائیگی کا طریقہ *', lp),
                    const SizedBox(height: 8),
                    _buildMethodSelector(lp),
                    const SizedBox(height: 16),
                    if (_paymentMethod == 'bank' || _paymentMethod == 'cheque') ...[
                      _lbl(lp.isEnglish ? 'Bank *' : 'بینک *', lp),
                      const SizedBox(height: 6),
                      _buildBankTile(lp),
                      const SizedBox(height: 16),
                    ],
                    if (_paymentMethod == 'cheque') ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _lbl(lp.isEnglish ? 'Cheque No. *' : 'چیک نمبر *', lp),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _chequeNumCtrl,
                                  style: TextStyle(fontFamily: lp.fontFamily),
                                  decoration: _inp(hint: '001234', lp: lp),
                                  validator: (v) => (_paymentMethod == 'cheque' && (v == null || v.isEmpty)) ? (lp.isEnglish ? 'Required' : 'ضروری') : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _lbl(lp.isEnglish ? 'Cheque Date *' : 'چیک کی تاریخ *', lp),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: _pickChequeDate,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: _chequeDate != null ? _activeColor.withOpacity(0.05) : const Color(0xFFF5F5F7),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _chequeDate != null ? _activeColor.withOpacity(0.3) : const Color(0xFFE5E5EA)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today_outlined, size: 14,
                                            color: _chequeDate != null ? _activeColor : Colors.grey[400]),
                                        const SizedBox(width: 6),
                                        Text(
                                          _chequeDate != null ? _df.format(_chequeDate!) : (lp.isEnglish ? 'Pick date' : 'تاریخ منتخب کریں'),
                                          style: TextStyle(fontSize: 12,
                                              color: _chequeDate != null ? const Color(0xFF1C1C1E) : const Color(0xFFC7C7CC),
                                              fontFamily: lp.fontFamily),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    _lbl(lp.isEnglish ? 'Reference # (optional)' : 'حوالہ نمبر (اختیاری)', lp),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _refCtrl,
                      style: TextStyle(fontFamily: lp.fontFamily),
                      decoration: _inp(hint: 'TXN-001', lp: lp),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text(lp.isEnglish ? 'Add Expense' : 'خرچ شامل کریں',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField(LanguageProvider lp) => Container(
    decoration: BoxDecoration(
      color: _activeColor.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _activeColor.withOpacity(0.3), width: 1.5),
    ),
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('Rs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _activeColor)),
        ),
        Container(width: 1, height: 36, color: _activeColor.withOpacity(0.2)),
        Expanded(
          child: TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: Color(0xFFC7C7CC), fontSize: 20, fontWeight: FontWeight.bold),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return lp.isEnglish ? 'Amount required' : 'رقم ضروری ہے';
              if ((double.tryParse(v) ?? 0) <= 0) return lp.isEnglish ? 'Invalid amount' : 'غلط رقم';
              return null;
            },
          ),
        ),
      ],
    ),
  );

  Widget _buildMethodSelector(LanguageProvider lp) => Row(
    children: widget.methods.map((m) {
      final val = m['value'] as String;
      final selected = _paymentMethod == val;
      final col = widget.methodColors[val]!;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _paymentMethod = val;
            _selectedBankId = null;
            _selectedBankName = null;
            _selectedBankIcon = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? col.withOpacity(0.1) : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? col : const Color(0xFFE5E5EA), width: selected ? 2 : 1),
            ),
            child: Column(children: [
              Icon(m['icon'] as IconData, size: 20, color: selected ? col : const Color(0xFF8E8E93)),
              const SizedBox(height: 4),
              Text(m['label'] as String,
                  style: TextStyle(fontSize: 10,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? col : const Color(0xFF8E8E93),
                      fontFamily: lp.fontFamily)),
            ]),
          ),
        ),
      );
    }).toList(),
  );

  Widget _buildBankTile(LanguageProvider lp) {
    final hasBank = _selectedBankName != null;
    return GestureDetector(
      onTap: _openBankPicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: hasBank ? _activeColor.withOpacity(0.05) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasBank ? _activeColor.withOpacity(0.4) : const Color(0xFFE5E5EA)),
        ),
        child: Row(
          children: [
            if (hasBank) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(_selectedBankIcon ?? '', width: 28, height: 28, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.account_balance, size: 24, color: _activeColor)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_selectedBankName!,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: lp.fontFamily))),
              Icon(Icons.check_circle_rounded, color: _activeColor, size: 18),
            ] else ...[
              Icon(Icons.account_balance_outlined, size: 18, color: Colors.grey[400]),
              const SizedBox(width: 10),
              Expanded(child: Text(lp.isEnglish ? 'Select bank' : 'بینک منتخب کریں',
                  style: TextStyle(fontSize: 13, color: const Color(0xFFC7C7CC), fontFamily: lp.fontFamily))),
              Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey[400]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lbl(String t, LanguageProvider lp) => Text(t,
      style: TextStyle(fontSize: 12, color: const Color(0xFF8E8E93), fontWeight: FontWeight.w600, fontFamily: lp.fontFamily));

  InputDecoration _inp({required String hint, required LanguageProvider lp}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 13),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    filled: true,
    fillColor: const Color(0xFFF5F5F7),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _activeColor, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPLIER PAYMENT FROM SESSION DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _SupplierPaymentFromSessionDialog extends StatefulWidget {
  final int sessionId;
  final double availableBalance;
  final Map<String, String> headers;
  final bool isClosed;
  final String? Function() getToken;
  final LanguageProvider languageProvider;
  final Map<String, Color> methodColors;
  final List<Map<String, dynamic>> methods;

  const _SupplierPaymentFromSessionDialog({
    required this.sessionId,
    required this.availableBalance,
    required this.headers,
    required this.isClosed,
    required this.getToken,
    required this.languageProvider,
    required this.methodColors,
    required this.methods,
  });

  @override
  State<_SupplierPaymentFromSessionDialog> createState() =>
      _SupplierPaymentFromSessionDialogState();
}

class _SupplierPaymentFromSessionDialogState
    extends State<_SupplierPaymentFromSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _chequeNumCtrl = TextEditingController();
  final _supplierSearchCtrl = TextEditingController();

  Supplier? _selectedSupplier;
  List<Supplier> _suppliers = [];
  bool _loadingSuppliers = false;

  String _paymentMethod = 'cash';
  int? _selectedBankId;
  String? _selectedBankName;
  String? _selectedBankIcon;
  DateTime? _chequeDate;
  bool _isLoading = false;
  bool _showSupplierSearch = false;

  final _df = DateFormat('MMM dd, yyyy');
  static const _supplierColor = Color(0xFF8B5CF6);

  Color get _activeColor => widget.methodColors[_paymentMethod] ?? const Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    _chequeNumCtrl.dispose();
    _supplierSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSuppliers() async {
    setState(() => _loadingSuppliers = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/suppliers/active'),
        headers: widget.headers,
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        final list = (data['data'] as List<dynamic>? ?? data as List<dynamic>? ?? [])
            .map((s) => Supplier.fromJson(s))
            .toList();
        setState(() => _suppliers = list);
      }
    } catch (_) {}
    setState(() => _loadingSuppliers = false);
  }

  List<Supplier> get _filteredSuppliers {
    final q = _supplierSearchCtrl.text.toLowerCase();
    if (q.isEmpty) return _suppliers;
    return _suppliers.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _submit() async {
    final lp = widget.languageProvider;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplier == null) {
      _err(lp.isEnglish ? 'Please select a supplier' : 'براہ کرم سپلائر منتخب کریں');
      return;
    }
    if ((_paymentMethod == 'bank' || _paymentMethod == 'cheque') && _selectedBankName == null) {
      _err(lp.isEnglish ? 'Please select a bank' : 'براہ کرم بینک منتخب کریں');
      return;
    }
    if (_paymentMethod == 'cheque') {
      if (_chequeNumCtrl.text.trim().isEmpty) {
        _err(lp.isEnglish ? 'Please enter cheque number' : 'براہ کرم چیک نمبر درج کریں');
        return;
      }
      if (_chequeDate == null) {
        _err(lp.isEnglish ? 'Please select cheque date' : 'براہ کرم چیک کی تاریخ منتخب کریں');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final amount = double.parse(_amountCtrl.text.trim());

      int? chequeId;
      if (_paymentMethod == 'cheque') {
        final chequeRes = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/cheques'),
          headers: widget.headers,
          body: json.encode({
            'bank_id': _selectedBankId,
            'cheque_number': _chequeNumCtrl.text.trim(),
            'cheque_type': 'issued',
            'amount': amount,
            'payee_payer_name': _selectedSupplier!.name,
            'description': _descCtrl.text.trim().isEmpty ? 'Payment to ${_selectedSupplier!.name}' : _descCtrl.text.trim(),
            'issue_date': DateFormat('yyyy-MM-dd').format(_chequeDate ?? DateTime.now()),
            'due_date': _chequeDate != null ? DateFormat('yyyy-MM-dd').format(_chequeDate!) : null,
          }),
        );
        final chequeData = json.decode(chequeRes.body);
        if (chequeRes.statusCode == 201 && chequeData['success'] == true) {
          chequeId = chequeData['data']['id'];
        } else {
          _err(chequeData['message'] ?? (lp.isEnglish ? 'Failed to create cheque' : 'چیک بنانے میں ناکامی'));
          setState(() => _isLoading = false);
          return;
        }
      }

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/expense-sessions/${widget.sessionId}/supplier-payments'),
        headers: widget.headers,
        body: json.encode({
          'supplier_id': _selectedSupplier!.id,
          'amount': amount,
          'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'payment_method': _paymentMethod,
          'bank_id': _selectedBankId,
          'bank_name': _selectedBankName,
          'cheque_number': _paymentMethod == 'cheque' ? _chequeNumCtrl.text.trim() : null,
          'cheque_id': chequeId,
          'cheque_date': _chequeDate != null ? DateFormat('yyyy-MM-dd').format(_chequeDate!) : null,
          'reference_number': _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        }),
      );

      final data = json.decode(res.body);
      if (res.statusCode == 201 && data['success'] == true) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lp.isEnglish
                ? 'Payment of Rs ${amount.toStringAsFixed(2)} to ${_selectedSupplier!.name} recorded'
                : '${_selectedSupplier!.name} کو Rs ${amount.toStringAsFixed(2)} کی ادائیگی ریکارڈ ہوگئی'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ));
        }
      } else {
        if (chequeId != null) {
          await http.delete(
            Uri.parse('${ApiConfig.baseUrl}/cheques/$chequeId'),
            headers: widget.headers,
          );
        }
        _err(data['message'] ?? (lp.isEnglish ? 'Failed to record payment' : 'ادائیگی ریکارڈ کرنے میں ناکامی'));
      }
    } catch (e) {
      _err('${lp.isEnglish ? 'Error' : 'خرابی'}: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  Future<void> _openBankPicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DbBankSheet(
        accentColor: _activeColor,
        token: widget.getToken(),
        languageProvider: widget.languageProvider,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedBankId = result['id'] as int;
        _selectedBankName = result['name'] as String;
        _selectedBankIcon = result['icon_path'] as String? ?? '';
      });
    }
  }

  Future<void> _pickChequeDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _chequeDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: _activeColor)),
        child: child!,
      ),
    );
    if (p != null) setState(() => _chequeDate = p);
  }

  @override
  Widget build(BuildContext context) {
    final lp = widget.languageProvider;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              decoration: BoxDecoration(
                color: _supplierColor.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: _supplierColor.withOpacity(0.15))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _supplierColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_outlined, color: _supplierColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lp.isEnglish ? 'Pay Supplier' : 'سپلائر کو ادائیگی کریں',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('${lp.isEnglish ? 'Cash available' : 'دستیاب نقدی'}: Rs ${widget.availableBalance.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _lbl(lp.isEnglish ? 'Supplier *' : 'سپلائر *', lp),
                    const SizedBox(height: 6),
                    _buildSupplierSelector(lp),
                    const SizedBox(height: 16),
                    _lbl(lp.isEnglish ? 'Amount *' : 'رقم *', lp),
                    const SizedBox(height: 6),
                    _buildAmountField(lp),
                    const SizedBox(height: 16),
                    _lbl(lp.isEnglish ? 'Payment Method *' : 'ادائیگی کا طریقہ *', lp),
                    const SizedBox(height: 8),
                    _buildMethodSelector(lp),
                    const SizedBox(height: 16),
                    if (_paymentMethod == 'bank' || _paymentMethod == 'cheque') ...[
                      _lbl(lp.isEnglish ? 'Bank *' : 'بینک *', lp),
                      const SizedBox(height: 6),
                      _buildBankTile(lp),
                      const SizedBox(height: 16),
                    ],
                    if (_paymentMethod == 'cheque') ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _lbl(lp.isEnglish ? 'Cheque No. *' : 'چیک نمبر *', lp),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _chequeNumCtrl,
                                  style: TextStyle(fontFamily: lp.fontFamily),
                                  decoration: _inp(hint: '001234', lp: lp),
                                  validator: (v) => (_paymentMethod == 'cheque' && (v == null || v.isEmpty)) ? (lp.isEnglish ? 'Required' : 'ضروری') : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _lbl(lp.isEnglish ? 'Cheque Date *' : 'چیک کی تاریخ *', lp),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: _pickChequeDate,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: _chequeDate != null ? _activeColor.withOpacity(0.05) : const Color(0xFFF5F5F7),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _chequeDate != null ? _activeColor.withOpacity(0.3) : const Color(0xFFE5E5EA)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today_outlined, size: 14,
                                            color: _chequeDate != null ? _activeColor : Colors.grey[400]),
                                        const SizedBox(width: 6),
                                        Text(
                                          _chequeDate != null ? _df.format(_chequeDate!) : (lp.isEnglish ? 'Pick date' : 'تاریخ منتخب کریں'),
                                          style: TextStyle(fontSize: 12,
                                              color: _chequeDate != null ? const Color(0xFF1C1C1E) : const Color(0xFFC7C7CC),
                                              fontFamily: lp.fontFamily),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 14, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lp.isEnglish
                                    ? 'Cheque recorded as "pending". Update to "cleared" when cashed.'
                                    : 'چیک "زیر التواء" کے طور پر ریکارڈ کیا گیا۔ کیش ہونے پر "کلیئر شدہ" میں تبدیل کریں۔',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _lbl(lp.isEnglish ? 'Description (optional)' : 'تفصیل (اختیاری)', lp),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      style: TextStyle(fontFamily: lp.fontFamily),
                      decoration: _inp(hint: lp.isEnglish ? 'e.g. Monthly payment for goods received' : 'مثال: موصولہ سامان کی ماہانہ ادائیگی', lp: lp),
                    ),
                    const SizedBox(height: 16),
                    _lbl(lp.isEnglish ? 'Reference # (optional)' : 'حوالہ نمبر (اختیاری)', lp),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _refCtrl,
                      style: TextStyle(fontFamily: lp.fontFamily),
                      decoration: _inp(hint: 'TXN-001', lp: lp),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _supplierColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text(lp.isEnglish ? 'Confirm Payment' : 'ادائیگی کی تصدیق کریں',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierSelector(LanguageProvider lp) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showSupplierSearch = !_showSupplierSearch),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: _selectedSupplier != null ? _supplierColor.withOpacity(0.05) : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _selectedSupplier != null ? _supplierColor.withOpacity(0.4) : const Color(0xFFE5E5EA)),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outlined, size: 18,
                    color: _selectedSupplier != null ? _supplierColor : Colors.grey[400]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedSupplier?.name ?? (lp.isEnglish ? 'Select supplier' : 'سپلائر منتخب کریں'),
                    style: TextStyle(
                        fontSize: 13,
                        color: _selectedSupplier != null ? const Color(0xFF1C1C1E) : const Color(0xFFC7C7CC),
                        fontWeight: _selectedSupplier != null ? FontWeight.w500 : FontWeight.normal,
                        fontFamily: lp.fontFamily),
                  ),
                ),
                Icon(_showSupplierSearch ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
        if (_showSupplierSearch) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _supplierSearchCtrl,
            style: TextStyle(fontFamily: lp.fontFamily),
            decoration: InputDecoration(
              hintText: lp.isEnglish ? 'Search suppliers...' : 'سپلائرز تلاش کریں...',
              hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF5F5F7),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E5EA)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: _loadingSuppliers
                ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                : ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredSuppliers.length,
              itemBuilder: (ctx, i) {
                final s = _filteredSuppliers[i];
                return ListTile(
                  dense: true,
                  title: Text(s.name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(s.contact, style: const TextStyle(fontSize: 11)),
                  leading: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: _supplierColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Center(child: Text(s.name[0].toUpperCase(),
                        style: const TextStyle(color: _supplierColor, fontWeight: FontWeight.bold, fontSize: 13))),
                  ),
                  onTap: () => setState(() {
                    _selectedSupplier = s;
                    _showSupplierSearch = false;
                    _supplierSearchCtrl.clear();
                  }),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAmountField(LanguageProvider lp) => Container(
    decoration: BoxDecoration(
      color: _activeColor.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _activeColor.withOpacity(0.3), width: 1.5),
    ),
    child: Row(
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('Rs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _activeColor))),
        Container(width: 1, height: 36, color: _activeColor.withOpacity(0.2)),
        Expanded(
          child: TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: Color(0xFFC7C7CC), fontSize: 20, fontWeight: FontWeight.bold),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return lp.isEnglish ? 'Amount required' : 'رقم ضروری ہے';
              if ((double.tryParse(v) ?? 0) <= 0) return lp.isEnglish ? 'Invalid amount' : 'غلط رقم';
              return null;
            },
          ),
        ),
      ],
    ),
  );

  Widget _buildMethodSelector(LanguageProvider lp) => Row(
    children: widget.methods.map((m) {
      final val = m['value'] as String;
      final selected = _paymentMethod == val;
      final col = widget.methodColors[val]!;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _paymentMethod = val;
            _selectedBankId = null;
            _selectedBankName = null;
            _selectedBankIcon = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? col.withOpacity(0.1) : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? col : const Color(0xFFE5E5EA), width: selected ? 2 : 1),
            ),
            child: Column(children: [
              Icon(m['icon'] as IconData, size: 20, color: selected ? col : const Color(0xFF8E8E93)),
              const SizedBox(height: 4),
              Text(m['label'] as String,
                  style: TextStyle(fontSize: 10,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? col : const Color(0xFF8E8E93),
                      fontFamily: lp.fontFamily)),
            ]),
          ),
        ),
      );
    }).toList(),
  );

  Widget _buildBankTile(LanguageProvider lp) {
    final hasBank = _selectedBankName != null;
    return GestureDetector(
      onTap: _openBankPicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: hasBank ? _activeColor.withOpacity(0.05) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasBank ? _activeColor.withOpacity(0.4) : const Color(0xFFE5E5EA)),
        ),
        child: Row(
          children: [
            if (hasBank) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(_selectedBankIcon ?? '', width: 28, height: 28, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.account_balance, size: 24, color: _activeColor)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_selectedBankName!,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: lp.fontFamily))),
              Icon(Icons.check_circle_rounded, color: _activeColor, size: 18),
            ] else ...[
              Icon(Icons.account_balance_outlined, size: 18, color: Colors.grey[400]),
              const SizedBox(width: 10),
              Expanded(child: Text(lp.isEnglish ? 'Select bank' : 'بینک منتخب کریں',
                  style: TextStyle(fontSize: 13, color: const Color(0xFFC7C7CC), fontFamily: lp.fontFamily))),
              Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey[400]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lbl(String t, LanguageProvider lp) => Text(t,
      style: TextStyle(fontSize: 12, color: const Color(0xFF8E8E93), fontWeight: FontWeight.w600, fontFamily: lp.fontFamily));

  InputDecoration _inp({required String hint, required LanguageProvider lp}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 13),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    filled: true,
    fillColor: const Color(0xFFF5F5F7),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _activeColor, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BILL PAYMENT DIALOG FOR DAILY EXPENSE SESSION
// ─────────────────────────────────────────────────────────────────────────────
class _BillPaymentFromSessionDialog extends StatefulWidget {
  final int sessionId;
  final double availableBalance;
  final Map<String, String> headers;
  final bool isClosed;
  final String? Function() getToken;
  final LanguageProvider languageProvider;
  final Map<String, Color> methodColors;
  final List<Map<String, dynamic>> methods;
  final List<Map<String, dynamic>> billTypes;

  const _BillPaymentFromSessionDialog({
    required this.sessionId,
    required this.availableBalance,
    required this.headers,
    required this.isClosed,
    required this.getToken,
    required this.languageProvider,
    required this.methodColors,
    required this.methods,
    required this.billTypes,
  });

  @override
  State<_BillPaymentFromSessionDialog> createState() =>
      _BillPaymentFromSessionDialogState();
}

class _BillPaymentFromSessionDialogState
    extends State<_BillPaymentFromSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _chequeNumCtrl = TextEditingController();
  final _billNumberCtrl = TextEditingController();
  final _consumerNumberCtrl = TextEditingController();

  String _billType = 'electricity';
  String _paymentMethod = 'cash';
  int? _selectedBankId;
  String? _selectedBankName;
  String? _selectedBankIcon;
  DateTime? _chequeDate;
  Uint8List? _billImageBytes;
  bool _isLoading = false;

  final _df = DateFormat('MMM dd, yyyy');

  Color get _activeColor => widget.methodColors[_paymentMethod] ?? const Color(0xFF10B981);
  Color get _billTypeColor => widget.billTypes.firstWhere((b) => b['type'] == _billType)['color'] as Color;

  Future<void> _pickBillImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() => _billImageBytes = bytes);
      final lp = widget.languageProvider;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lp.isEnglish ? 'Bill image uploaded' : 'بل کی تصویر اپ لوڈ ہوگئی'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _submit() async {
    final lp = widget.languageProvider;
    if (!_formKey.currentState!.validate()) return;
    if ((_paymentMethod == 'bank' || _paymentMethod == 'cheque') && _selectedBankName == null) {
      _err(lp.isEnglish ? 'Please select a bank' : 'براہ کرم بینک منتخب کریں');
      return;
    }
    if (_paymentMethod == 'cheque') {
      if (_chequeNumCtrl.text.trim().isEmpty) {
        _err(lp.isEnglish ? 'Please enter cheque number' : 'براہ کرم چیک نمبر درج کریں');
        return;
      }
      if (_chequeDate == null) {
        _err(lp.isEnglish ? 'Please select cheque date' : 'براہ کرم چیک کی تاریخ منتخب کریں');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final amount = double.parse(_amountCtrl.text.trim());
      final selectedBillType = widget.billTypes.firstWhere((b) => b['type'] == _billType);

      String description = _descCtrl.text.trim();
      if (description.isEmpty) {
        description = '${selectedBillType['name']} ${lp.isEnglish ? 'Payment' : 'ادائیگی'}';
        if (_billNumberCtrl.text.trim().isNotEmpty) {
          description += ' - ${lp.isEnglish ? 'Bill #' : 'بل نمبر'}${_billNumberCtrl.text.trim()}';
        }
      }

      int? chequeId;
      if (_paymentMethod == 'cheque') {
        final chequeRes = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/cheques'),
          headers: widget.headers,
          body: json.encode({
            'bank_id': _selectedBankId,
            'cheque_number': _chequeNumCtrl.text.trim(),
            'cheque_type': 'issued',
            'amount': amount,
            'payee_payer_name': selectedBillType['name'],
            'description': description,
            'issue_date': DateFormat('yyyy-MM-dd').format(_chequeDate ?? DateTime.now()),
            'due_date': _chequeDate != null ? DateFormat('yyyy-MM-dd').format(_chequeDate!) : null,
          }),
        );
        final chequeData = json.decode(chequeRes.body);
        if (chequeRes.statusCode == 201 && chequeData['success'] == true) {
          chequeId = chequeData['data']['id'];
        } else {
          _err(chequeData['message'] ?? (lp.isEnglish ? 'Failed to create cheque' : 'چیک بنانے میں ناکامی'));
          setState(() => _isLoading = false);
          return;
        }
      }

      final requestBody = {
        'bill_type': _billType,
        'bill_name': selectedBillType['name'],
        'bill_number': _billNumberCtrl.text.trim().isEmpty ? null : _billNumberCtrl.text.trim(),
        'consumer_number': _consumerNumberCtrl.text.trim().isEmpty ? null : _consumerNumberCtrl.text.trim(),
        'description': description,
        'amount': amount,
        'payment_method': _paymentMethod,
        'bank_id': _selectedBankId,
        'bank_name': _selectedBankName,
        'cheque_number': _paymentMethod == 'cheque' ? _chequeNumCtrl.text.trim() : null,
        'cheque_id': chequeId,
        'cheque_date': _chequeDate != null ? DateFormat('yyyy-MM-dd').format(_chequeDate!) : null,
        'reference_number': _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      };

      if (_billImageBytes != null) {
        requestBody['bill_image'] = base64Encode(_billImageBytes!);
      }

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/expense-sessions/${widget.sessionId}/bill-payments'),
        headers: widget.headers,
        body: json.encode(requestBody),
      );

      final data = json.decode(res.body);
      if (res.statusCode == 201 && data['success'] == true) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${selectedBillType['name']} ${lp.isEnglish ? 'of Rs' : 'کی Rs'} ${amount.toStringAsFixed(2)} ${lp.isEnglish ? 'paid' : 'ادا ہوگئی'}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ));
        }
      } else {
        if (chequeId != null) {
          await http.delete(
            Uri.parse('${ApiConfig.baseUrl}/cheques/$chequeId'),
            headers: widget.headers,
          );
        }
        _err(data['message'] ?? (lp.isEnglish ? 'Failed to record bill payment' : 'بل کی ادائیگی ریکارڈ کرنے میں ناکامی'));
      }
    } catch (e) {
      _err('${lp.isEnglish ? 'Error' : 'خرابی'}: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  Future<void> _openBankPicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DbBankSheet(
        accentColor: _activeColor,
        token: widget.getToken(),
        languageProvider: widget.languageProvider,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedBankId = result['id'] as int;
        _selectedBankName = result['name'] as String;
        _selectedBankIcon = result['icon_path'] as String? ?? '';
      });
    }
  }

  Future<void> _pickChequeDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _chequeDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: _activeColor)),
        child: child!,
      ),
    );
    if (p != null) setState(() => _chequeDate = p);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    _chequeNumCtrl.dispose();
    _billNumberCtrl.dispose();
    _consumerNumberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = widget.languageProvider;
    final selectedBillType = widget.billTypes.firstWhere((b) => b['type'] == _billType);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              decoration: BoxDecoration(
                color: _billTypeColor.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: _billTypeColor.withOpacity(0.15))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _billTypeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(selectedBillType['icon'] as IconData, color: _billTypeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lp.isEnglish ? 'Pay Bill' : 'بل ادا کریں',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('${lp.isEnglish ? 'Cash available' : 'دستیاب نقدی'}: Rs ${widget.availableBalance.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _lbl(lp.isEnglish ? 'Bill Type *' : 'بل کی قسم *', lp),
                    const SizedBox(height: 8),
                    _buildBillTypeSelector(lp),
                    const SizedBox(height: 20),
                    _lbl(lp.isEnglish ? 'Bill Number (optional)' : 'بل نمبر (اختیاری)', lp),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _billNumberCtrl,
                      style: TextStyle(fontFamily: lp.fontFamily),
                      decoration: _inp(hint: lp.isEnglish ? 'e.g. 00123456' : 'مثال: 00123456', lp: lp),
                    ),
                    const SizedBox(height: 16),
                    _lbl(lp.isEnglish ? 'Consumer Number (optional)' : 'کنزیومر نمبر (اختیاری)', lp),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _consumerNumberCtrl,
                      style: TextStyle(fontFamily: lp.fontFamily),
                      decoration: _inp(hint: lp.isEnglish ? 'e.g. 123456789' : 'مثال: 123456789', lp: lp),
                    ),
                    const SizedBox(height: 16),
                    _lbl(lp.isEnglish ? 'Description (optional)' : 'تفصیل (اختیاری)', lp),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      style: TextStyle(fontFamily: lp.fontFamily),
                      decoration: _inp(hint: lp.isEnglish ? 'e.g. Monthly electricity bill payment' : 'مثال: ماہانہ بجلی کے بل کی ادائیگی', lp: lp),
                    ),
                    const SizedBox(height: 16),
                    _lbl(lp.isEnglish ? 'Amount *' : 'رقم *', lp),
                    const SizedBox(height: 6),
                    _buildAmountField(lp),
                    const SizedBox(height: 16),
                    _lbl(lp.isEnglish ? 'Payment Method *' : 'ادائیگی کا طریقہ *', lp),
                    const SizedBox(height: 8),
                    _buildMethodSelector(lp),
                    const SizedBox(height: 16),
                    if (_paymentMethod == 'bank' || _paymentMethod == 'cheque') ...[
                      _lbl(lp.isEnglish ? 'Bank *' : 'بینک *', lp),
                      const SizedBox(height: 6),
                      _buildBankTile(lp),
                      const SizedBox(height: 16),
                    ],
                    if (_paymentMethod == 'cheque') ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _lbl(lp.isEnglish ? 'Cheque No. *' : 'چیک نمبر *', lp),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _chequeNumCtrl,
                                  style: TextStyle(fontFamily: lp.fontFamily),
                                  decoration: _inp(hint: '001234', lp: lp),
                                  validator: (v) => (_paymentMethod == 'cheque' && (v == null || v.isEmpty)) ? (lp.isEnglish ? 'Required' : 'ضروری') : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _lbl(lp.isEnglish ? 'Cheque Date *' : 'چیک کی تاریخ *', lp),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: _pickChequeDate,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: _chequeDate != null ? _activeColor.withOpacity(0.05) : const Color(0xFFF5F5F7),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _chequeDate != null ? _activeColor.withOpacity(0.3) : const Color(0xFFE5E5EA)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today_outlined, size: 14,
                                            color: _chequeDate != null ? _activeColor : Colors.grey[400]),
                                        const SizedBox(width: 6),
                                        Text(
                                          _chequeDate != null ? _df.format(_chequeDate!) : (lp.isEnglish ? 'Pick date' : 'تاریخ منتخب کریں'),
                                          style: TextStyle(fontSize: 12,
                                              color: _chequeDate != null ? const Color(0xFF1C1C1E) : const Color(0xFFC7C7CC),
                                              fontFamily: lp.fontFamily),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    _lbl(lp.isEnglish ? 'Reference # (optional)' : 'حوالہ نمبر (اختیاری)', lp),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _refCtrl,
                      style: TextStyle(fontFamily: lp.fontFamily),
                      decoration: _inp(hint: 'TXN-001', lp: lp),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickBillImage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE5E5EA)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.upload_file, size: 20, color: _billTypeColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _billImageBytes != null
                                    ? (lp.isEnglish ? 'Bill image attached' : 'بل کی تصویر منسلک ہے')
                                    : (lp.isEnglish ? 'Upload bill image (optional)' : 'بل کی تصویر اپ لوڈ کریں (اختیاری)'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _billImageBytes != null ? _billTypeColor : const Color(0xFF8E8E93),
                                  fontFamily: lp.fontFamily,
                                ),
                              ),
                            ),
                            if (_billImageBytes != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => setState(() => _billImageBytes = null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _billTypeColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text(lp.isEnglish ? 'Pay Bill' : 'بل ادا کریں',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillTypeSelector(LanguageProvider lp) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: widget.billTypes.map((bill) {
        final isSelected = _billType == bill['type'];
        final color = bill['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() => _billType = bill['type'] as String),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? color : const Color(0xFFE5E5EA), width: isSelected ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(bill['icon'] as IconData, size: 16, color: isSelected ? Colors.white : color),
                const SizedBox(width: 6),
                Text(bill['name'] as String,
                    style: TextStyle(fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : color,
                        fontFamily: lp.fontFamily)),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _buildAmountField(LanguageProvider lp) => Container(
    decoration: BoxDecoration(
      color: _activeColor.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _activeColor.withOpacity(0.3), width: 1.5),
    ),
    child: Row(
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('Rs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _activeColor))),
        Container(width: 1, height: 36, color: _activeColor.withOpacity(0.2)),
        Expanded(
          child: TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: Color(0xFFC7C7CC), fontSize: 20, fontWeight: FontWeight.bold),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return lp.isEnglish ? 'Amount required' : 'رقم ضروری ہے';
              if ((double.tryParse(v) ?? 0) <= 0) return lp.isEnglish ? 'Invalid amount' : 'غلط رقم';
              return null;
            },
          ),
        ),
      ],
    ),
  );

  Widget _buildMethodSelector(LanguageProvider lp) => Row(
    children: widget.methods.map((m) {
      final val = m['value'] as String;
      final selected = _paymentMethod == val;
      final col = widget.methodColors[val]!;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _paymentMethod = val;
            _selectedBankId = null;
            _selectedBankName = null;
            _selectedBankIcon = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? col.withOpacity(0.1) : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? col : const Color(0xFFE5E5EA), width: selected ? 2 : 1),
            ),
            child: Column(children: [
              Icon(m['icon'] as IconData, size: 20, color: selected ? col : const Color(0xFF8E8E93)),
              const SizedBox(height: 4),
              Text(m['label'] as String,
                  style: TextStyle(fontSize: 10,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? col : const Color(0xFF8E8E93),
                      fontFamily: lp.fontFamily)),
            ]),
          ),
        ),
      );
    }).toList(),
  );

  Widget _buildBankTile(LanguageProvider lp) {
    final hasBank = _selectedBankName != null;
    return GestureDetector(
      onTap: _openBankPicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: hasBank ? _activeColor.withOpacity(0.05) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasBank ? _activeColor.withOpacity(0.4) : const Color(0xFFE5E5EA)),
        ),
        child: Row(
          children: [
            if (hasBank) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(_selectedBankIcon ?? '', width: 28, height: 28, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.account_balance, size: 24, color: _activeColor)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_selectedBankName!,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: lp.fontFamily))),
              Icon(Icons.check_circle_rounded, color: _activeColor, size: 18),
            ] else ...[
              Icon(Icons.account_balance_outlined, size: 18, color: Colors.grey[400]),
              const SizedBox(width: 10),
              Expanded(child: Text(lp.isEnglish ? 'Select bank' : 'بینک منتخب کریں',
                  style: TextStyle(fontSize: 13, color: const Color(0xFFC7C7CC), fontFamily: lp.fontFamily))),
              Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey[400]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lbl(String t, LanguageProvider lp) => Text(t,
      style: TextStyle(fontSize: 12, color: const Color(0xFF8E8E93), fontWeight: FontWeight.w600, fontFamily: lp.fontFamily));

  InputDecoration _inp({required String hint, required LanguageProvider lp}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 13),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    filled: true,
    fillColor: const Color(0xFFF5F5F7),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _activeColor, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
  );
}