// lib/screens/suppliers/supplier_balance_report_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../config/api_config.dart';
import '../../models/supplier.dart';
import '../../providers/auth_provider.dart';
import 'supplier_ledger_screen.dart';
import 'supplier_payments_screen.dart';
import 'supplier_payment_dialog.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class SupplierBalanceSummary {
  final int id;
  final String name;
  final String contact;
  final String? address;
  final bool isActive;
  final double totalCredit;  // total payable (purchases)
  final double totalDebit;   // total paid
  final double balance;      // outstanding = credit - debit

  SupplierBalanceSummary({
    required this.id, required this.name, required this.contact,
    this.address, required this.isActive,
    required this.totalCredit, required this.totalDebit, required this.balance,
  });

  factory SupplierBalanceSummary.fromJson(Map<String, dynamic> j) {
    return SupplierBalanceSummary(
      id:          j['id'] as int,
      name:        j['name'] as String,
      contact:     j['contact'] as String? ?? '',
      address:     j['address'] as String?,
      isActive:    j['is_active'] == true || j['is_active'] == 1,
      totalCredit: double.tryParse(j['total_credit']?.toString() ?? '0') ?? 0,
      totalDebit:  double.tryParse(j['total_debit']?.toString()  ?? '0') ?? 0,
      balance:     double.tryParse(j['balance']?.toString()      ?? '0') ?? 0,
    );
  }

  Supplier toSupplier() => Supplier(
    id: id,
    name: name,
    contact: contact,
    address: address,
    isActive: isActive,
    discountPercent: 0,        // ← add this
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SupplierBalanceReportScreen extends StatefulWidget {
  const SupplierBalanceReportScreen({super.key});

  @override
  State<SupplierBalanceReportScreen> createState() =>
      _SupplierBalanceReportScreenState();
}

class _SupplierBalanceReportScreenState
    extends State<SupplierBalanceReportScreen>
    with SingleTickerProviderStateMixin {

  List<SupplierBalanceSummary> _all      = [];
  List<SupplierBalanceSummary> _filtered = [];
  bool   _isLoading = true;
  String? _error;

  // Filters
  String _search      = '';
  String _sortBy      = 'balance_desc'; // balance_desc | balance_asc | name_asc | name_desc | paid_desc
  String _balanceFilter = 'all';         // all | outstanding | overpaid | settled
  bool   _activeOnly  = false;

  final _searchCtrl = TextEditingController();
  final _cf         = NumberFormat('#,##0.00');
  final _cf0        = NumberFormat('#,##0');

  late AnimationController _animCtrl;

  // Sort options
  static const _sortOptions = [
    {'value': 'balance_desc', 'label': 'Highest Balance'},
    {'value': 'balance_asc',  'label': 'Lowest Balance'},
    {'value': 'paid_desc',    'label': 'Most Paid'},
    {'value': 'name_asc',     'label': 'Name A–Z'},
    {'value': 'name_desc',    'label': 'Name Z–A'},
  ];

  static const _balanceFilters = [
    {'value': 'all',         'label': 'All'},
    {'value': 'outstanding', 'label': 'Outstanding'},
    {'value': 'settled',     'label': 'Settled'},
    {'value': 'overpaid',    'label': 'Overpaid'},
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fetch();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String? _getToken() {
    try { return Provider.of<AuthProvider>(context, listen: false).user?.token; }
    catch (_) { return null; }
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/suppliers/balances'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final list = (data['data'] as List)
            .map((e) => SupplierBalanceSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        setState(() { _all = list; _isLoading = false; });
        _applyFilters();
        _animCtrl.forward(from: 0);
      } else {
        setState(() { _error = data['message'] ?? 'Failed to load'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _applyFilters() {
    var list = List<SupplierBalanceSummary>.from(_all);

    // Active filter
    if (_activeOnly) list = list.where((s) => s.isActive).toList();

    // Search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((s) =>
      s.name.toLowerCase().contains(q) ||
          s.contact.toLowerCase().contains(q) ||
          (s.address?.toLowerCase().contains(q) ?? false)).toList();
    }

    // Balance filter
    switch (_balanceFilter) {
      case 'outstanding': list = list.where((s) => s.balance > 0.01).toList();  break;
      case 'settled':     list = list.where((s) => s.balance.abs() <= 0.01).toList(); break;
      case 'overpaid':    list = list.where((s) => s.balance < -0.01).toList(); break;
    }

    // Sort
    switch (_sortBy) {
      case 'balance_desc': list.sort((a, b) => b.balance.compareTo(a.balance));    break;
      case 'balance_asc':  list.sort((a, b) => a.balance.compareTo(b.balance));    break;
      case 'paid_desc':    list.sort((a, b) => b.totalDebit.compareTo(a.totalDebit)); break;
      case 'name_asc':     list.sort((a, b) => a.name.compareTo(b.name));          break;
      case 'name_desc':    list.sort((a, b) => b.name.compareTo(a.name));          break;
    }

    setState(() => _filtered = list);
  }

  // ── Aggregate totals ──────────────────────────────────────────────────────
  double get _grandCredit  => _filtered.fold(0.0, (s, e) => s + e.totalCredit);
  double get _grandDebit   => _filtered.fold(0.0, (s, e) => s + e.totalDebit);
  double get _grandBalance => _filtered.fold(0.0, (s, e) => s + e.balance);
  int    get _countOutstanding => _filtered.where((s) => s.balance > 0.01).length;
  int    get _countSettled     => _filtered.where((s) => s.balance.abs() <= 0.01).length;
  int    get _countOverpaid    => _filtered.where((s) => s.balance < -0.01).length;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(children: [
        _buildHeader(),
        _buildSummaryStrip(),
        _buildToolbar(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF3730A3), Color(0xFF4F46E5)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(Icons.assessment_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Supplier Balance Report',
                style: TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.bold, letterSpacing: -0.3)),
            Text('${_all.length} suppliers • as of ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
          ])),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            onPressed: _fetch,
          ),
        ]),

        const SizedBox(height: 20),

        // 3 KPI cards
        Row(children: [
          _kpiCard(label: 'Total Payable',  value: _grandCredit,
              icon: Icons.arrow_circle_up_outlined, color: const Color(0xFFEF4444)),
          const SizedBox(width: 12),
          _kpiCard(label: 'Total Paid',     value: _grandDebit,
              icon: Icons.arrow_circle_down_outlined, color: const Color(0xFF10B981)),
          const SizedBox(width: 12),
          _kpiCard(label: 'Net Outstanding', value: _grandBalance,
              icon: Icons.account_balance_outlined, color: const Color(0xFFF59E0B),
              highlight: true),
        ]),
      ]),
    );
  }

  Widget _kpiCard({required String label, required double value,
    required IconData icon, required Color color, bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlight
              ? Colors.white.withOpacity(0.18)
              : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(highlight ? 0.35 : 0.15),
              width: highlight ? 1.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Expanded(child: Text(label, style: TextStyle(fontSize: 10,
                color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          Text('Rs ${_cf0.format(value)}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                  color: highlight ? Colors.white : Colors.white.withOpacity(0.95)),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  // ─── Summary strip (count badges) ─────────────────────────────────────────

  Widget _buildSummaryStrip() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        _countBadge(label: 'Showing', value: '${_filtered.length}',
            color: const Color(0xFF6366F1)),
        _vDivider(),
        _countBadge(label: 'Outstanding', value: '$_countOutstanding',
            color: const Color(0xFFEF4444)),
        _vDivider(),
        _countBadge(label: 'Settled', value: '$_countSettled',
            color: const Color(0xFF10B981)),
        _vDivider(),
        _countBadge(label: 'Overpaid', value: '$_countOverpaid',
            color: const Color(0xFF8B5CF6)),
        const Spacer(),
        // Active toggle
        GestureDetector(
          onTap: () { setState(() => _activeOnly = !_activeOnly); _applyFilters(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _activeOnly
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _activeOnly ? const Color(0xFF10B981) : const Color(0xFFE5E5EA)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified_outlined, size: 12,
                  color: _activeOnly ? const Color(0xFF10B981) : Colors.grey),
              const SizedBox(width: 4),
              Text('Active Only', style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _activeOnly ? const Color(0xFF10B981) : Colors.grey[600])),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _countBadge({required String label, required String value, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 28,
      color: const Color(0xFFE5E5EA), margin: const EdgeInsets.symmetric(horizontal: 4));

  // ─── Toolbar: search + sort + balance filter ───────────────────────────────

  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(children: [
        const Divider(height: 1, color: Color(0xFFF0F0F5)),
        const SizedBox(height: 12),
        Row(children: [
          // Search
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(10)),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) { _search = v; _applyFilters(); },
                decoration: InputDecoration(
                  hintText: 'Search supplier…',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 18),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(icon: Icon(Icons.clear, color: Colors.grey[400], size: 16),
                      onPressed: () { _searchCtrl.clear(); _search = ''; _applyFilters(); })
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Sort dropdown
          _toolbarDropdown(
            icon: Icons.sort_rounded,
            value: _sortBy,
            items: _sortOptions,
            onChanged: (v) { _sortBy = v!; _applyFilters(); },
            tooltip: 'Sort',
          ),
        ]),
        const SizedBox(height: 10),
        // Balance filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _balanceFilters.map((f) {
              final sel   = _balanceFilter == f['value'];
              final color = _chipColor(f['value']!);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () { setState(() => _balanceFilter = f['value']!); _applyFilters(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? color.withOpacity(0.1) : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? color : const Color(0xFFE5E5EA),
                          width: sel ? 1.5 : 1),
                    ),
                    child: Text(f['label']!, style: TextStyle(
                        fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        color: sel ? color : const Color(0xFF8E8E93))),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Color _chipColor(String filter) {
    switch (filter) {
      case 'outstanding': return const Color(0xFFEF4444);
      case 'settled':     return const Color(0xFF10B981);
      case 'overpaid':    return const Color(0xFF8B5CF6);
      default:            return const Color(0xFF6366F1);
    }
  }

  Widget _toolbarDropdown({
    required IconData icon, required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged, required String tooltip,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E5EA))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[500]),
          style: const TextStyle(fontSize: 12, color: Color(0xFF1C1C1E)),
          isDense: true,
          items: items.map((i) => DropdownMenuItem(
              value: i['value'],
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 13, color: const Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Text(i['label']!, style: const TextStyle(fontSize: 12)),
              ]))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _fetch, icon: const Icon(Icons.refresh),
            label: const Text('Retry'), style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white)),
      ]));
    }
    if (_filtered.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.08),
                shape: BoxShape.circle),
            child: const Icon(Icons.people_outline, size: 52, color: Color(0xFF6366F1))),
        const SizedBox(height: 16),
        const Text('No suppliers found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E))),
        const SizedBox(height: 6),
        Text(_search.isNotEmpty ? 'Try a different search term' : 'Adjust your filters',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ]));
    }

    return Column(children: [
      // Table header
      _buildTableHeader(),
      // Rows
      Expanded(
        child: RefreshIndicator(
          onRefresh: _fetch, color: const Color(0xFF6366F1),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final s = _filtered[i];
              return FadeTransition(
                opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
                  parent: _animCtrl,
                  curve: Interval(
                      (i / _filtered.length.clamp(1, 9999)) * 0.5,
                      (i / _filtered.length.clamp(1, 9999)) * 0.5 + 0.5,
                      curve: Curves.easeOut),
                )),
                child: _SupplierRow(
                  summary: s, index: i, cf: _cf,
                  onTap: () => _showSupplierActions(s),
                ),
              );
            },
          ),
        ),
      ),
      // Grand total footer
      _buildFooter(),
    ]);
  }

  Widget _buildTableHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(children: [
        const Expanded(flex: 1, child: Text('#', style: _hStyle)),
        const Expanded(flex: 5, child: Text('SUPPLIER', style: _hStyle)),
        const Expanded(flex: 3, child: Text('PAYABLE', textAlign: TextAlign.right, style: _hStyle)),
        const Expanded(flex: 3, child: Text('PAID', textAlign: TextAlign.right, style: _hStyle)),
        const Expanded(flex: 3, child: Text('BALANCE', textAlign: TextAlign.right, style: _hStyle)),
        const Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.center, style: _hStyle)),
        const SizedBox(width: 36),
      ]),
    );
  }

  static const _hStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
      color: Colors.white70, letterSpacing: 0.8);

  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF3730A3)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(children: [
        const Expanded(flex: 1, child: SizedBox()),
        Expanded(flex: 5, child: Text(
            'TOTAL  (${_filtered.length} suppliers)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: Colors.white70))),
        Expanded(flex: 3, child: Text('Rs ${_cf.format(_grandCredit)}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: Color(0xFFFC8181)))),
        Expanded(flex: 3, child: Text('Rs ${_cf.format(_grandDebit)}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: Color(0xFF6EE7B7)))),
        Expanded(flex: 3, child: Text('Rs ${_cf.format(_grandBalance)}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                color: _grandBalance > 0 ? const Color(0xFFFBBF24) : const Color(0xFF6EE7B7)))),
        Expanded(flex: 2, child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Text('NET', style: const TextStyle(fontSize: 10,
              fontWeight: FontWeight.bold, color: Colors.white)),
        ))),
        const SizedBox(width: 36),
      ]),
    );
  }

  // ─── Actions bottom sheet ──────────────────────────────────────────────────

  void _showSupplierActions(SupplierBalanceSummary s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierActionSheet(
        summary: s, cf: _cf,
        onViewLedger: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => SupplierLedgerScreen(supplier: s.toSupplier())));
        },
        onViewPayments: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => SupplierPaymentsScreen(supplier: s.toSupplier())));
        },
        onPayNow: () async {
          Navigator.pop(context);
          final result = await showDialog<bool>(
            context: context,
            builder: (_) => SupplierPaymentDialog(supplier: s.toSupplier()),
          );
          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Payment recorded'), backgroundColor: Color(0xFF10B981)));
            _fetch();
          }
        },
      ),
    );
  }
}

// ── Supplier row widget ───────────────────────────────────────────────────────

class _SupplierRow extends StatelessWidget {
  final SupplierBalanceSummary summary;
  final int index;
  final NumberFormat cf;
  final VoidCallback onTap;

  const _SupplierRow({
    required this.summary, required this.index,
    required this.cf, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bal         = summary.balance;
    final isOutstanding = bal > 0.01;
    final isOverpaid    = bal < -0.01;
    final isSettled     = !isOutstanding && !isOverpaid;

    final balColor = isOutstanding
        ? const Color(0xFFEF4444)
        : isOverpaid ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);

    final statusLabel = isOutstanding ? 'DUE'
        : isOverpaid ? 'OVERPAID' : 'SETTLED';
    final statusColor = balColor;

    // Avatar letter color
    final avatarColors = [
      const Color(0xFF6366F1), const Color(0xFF10B981), const Color(0xFF3B82F6),
      const Color(0xFFF59E0B), const Color(0xFF8B5CF6), const Color(0xFFEF4444),
    ];
    final avatarColor = avatarColors[index % avatarColors.length];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 1),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFC),
        border: const Border(bottom: BorderSide(color: Color(0xFFF0F0F5))),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: [
            // Index
            Expanded(flex: 1, child: Text('${index + 1}',
                style: TextStyle(fontSize: 11, color: Colors.grey[400],
                    fontWeight: FontWeight.w500))),

            // Supplier info
            Expanded(flex: 5, child: Row(children: [
              // Avatar
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: avatarColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: avatarColor.withOpacity(0.25))),
                child: Center(child: Text(
                    summary.name.isNotEmpty ? summary.name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: avatarColor))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(summary.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E)), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.phone_outlined, size: 10, color: Colors.grey[400]),
                  const SizedBox(width: 3),
                  Flexible(child: Text(summary.contact,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis)),
                  if (!summary.isActive) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('INACTIVE', style: TextStyle(fontSize: 9,
                          fontWeight: FontWeight.bold, color: Colors.grey[500])),
                    ),
                  ],
                ]),
              ])),
            ])),

            // Payable
            Expanded(flex: 3, child: Text('Rs ${cf.format(summary.totalCredit)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w500))),

            // Paid
            Expanded(flex: 3, child: Text('Rs ${cf.format(summary.totalDebit)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, color: Color(0xFF10B981),
                    fontWeight: FontWeight.w500))),

            // Balance
            Expanded(flex: 3, child: Text(
                '${bal < 0 ? '-' : ''}Rs ${cf.format(bal.abs())}',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: balColor))),

            // Status badge
            Expanded(flex: 2, child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.3))),
              child: Text(statusLabel,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                      color: statusColor, letterSpacing: 0.3),
                  overflow: TextOverflow.ellipsis),
            ))),

            // Chevron
            SizedBox(width: 36, child: Icon(Icons.chevron_right,
                size: 18, color: Colors.grey[300])),
          ]),
        ),
      ),
    );
  }
}

// ── Action sheet ──────────────────────────────────────────────────────────────

class _SupplierActionSheet extends StatelessWidget {
  final SupplierBalanceSummary summary;
  final NumberFormat cf;
  final VoidCallback onViewLedger;
  final VoidCallback onViewPayments;
  final VoidCallback onPayNow;

  const _SupplierActionSheet({
    required this.summary, required this.cf,
    required this.onViewLedger, required this.onViewPayments,
    required this.onPayNow,
  });

  @override
  Widget build(BuildContext context) {
    final bal           = summary.balance;
    final isOutstanding = bal > 0.01;
    final isOverpaid    = bal < -0.01;

    final balColor = isOutstanding ? const Color(0xFFEF4444)
        : isOverpaid ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);

    final paymentPercent = summary.totalCredit > 0
        ? (summary.totalDebit / summary.totalCredit).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(2))),

        // Supplier header
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(
                summary.name.isNotEmpty ? summary.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(summary.name,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1C1E))),
            Text(summary.contact, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ])),
          // Balance chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: balColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: balColor.withOpacity(0.3))),
            child: Column(children: [
              Text(isOutstanding ? 'OWING' : isOverpaid ? 'CREDIT' : 'CLEAR',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: balColor,
                      letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text('Rs ${cf.format(bal.abs())}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: balColor)),
            ]),
          ),
        ]),

        const SizedBox(height: 20),

        // Payment progress bar
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Payment Progress',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
            Text('${(paymentPercent * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1))),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: paymentPercent,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E5EA),
              valueColor: AlwaysStoppedAnimation<Color>(
                  paymentPercent >= 1.0 ? const Color(0xFF10B981) : const Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Paid: Rs ${cf.format(summary.totalDebit)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            Text('Total: Rs ${cf.format(summary.totalCredit)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),
        ]),

        const SizedBox(height: 20),

        // 3-column stats
        Row(children: [
          _sheetStat('Total Payable', 'Rs ${cf.format(summary.totalCredit)}',
              const Color(0xFFEF4444), Icons.arrow_upward_rounded),
          const SizedBox(width: 10),
          _sheetStat('Total Paid', 'Rs ${cf.format(summary.totalDebit)}',
              const Color(0xFF10B981), Icons.arrow_downward_rounded),
          const SizedBox(width: 10),
          _sheetStat('Net Balance', 'Rs ${cf.format(bal.abs())}',
              balColor, Icons.account_balance_outlined),
        ]),

        const SizedBox(height: 20),
        const Divider(color: Color(0xFFF0F0F5)),
        const SizedBox(height: 12),

        // Action buttons
        if (isOutstanding)
          _actionBtn(
            icon: Icons.payments_outlined, label: 'Pay Now',
            sub: 'Record payment to ${summary.name}',
            color: const Color(0xFF10B981), onTap: onPayNow,
          ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _smallActionBtn(
              icon: Icons.account_balance_wallet_outlined,
              label: 'View Ledger', color: const Color(0xFF6366F1),
              onTap: onViewLedger)),
          const SizedBox(width: 10),
          Expanded(child: _smallActionBtn(
              icon: Icons.history_outlined,
              label: 'Payments', color: const Color(0xFF3B82F6),
              onTap: onViewPayments)),
        ]),
      ]),
    );
  }

  Widget _sheetStat(String label, String value, Color color, IconData icon) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(child: Text(label, style: TextStyle(fontSize: 10,
              color: color.withOpacity(0.8), fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis),
      ]),
    ));
  }

  Widget _actionBtn({required IconData icon, required String label,
    required String sub, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.bold)),
            Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11)),
          ])),
          const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
        ]),
      ),
    );
  }

  Widget _smallActionBtn({required IconData icon, required String label,
    required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}