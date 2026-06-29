// lib/screens/customers/customer_payments_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../config/api_config.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_ledger_provider.dart';
import '../providers/lanprovider.dart';
import '../services/CustomerPdfService.dart';
import 'customer_payment_dialog.dart';

// ── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg         = Color(0xFFF8FAFC);
  static const surface    = Colors.white;
  static const emerald    = Color(0xFF10B981);
  static const emeraldDk  = Color(0xFF059669);
  static const slate900   = Color(0xFF0F172A);
  static const slate700   = Color(0xFF334155);
  static const slate500   = Color(0xFF64748B);
  static const slate300   = Color(0xFFCBD5E1);
  static const slate100   = Color(0xFFF1F5F9);
  static const amber      = Color(0xFFF59E0B);
  static const violet     = Color(0xFF7C3AED);
  static const red        = Color(0xFFEF4444);
  static const blue       = Color(0xFF3B82F6);
  static const pink       = Color(0xFFEC4899);
  static const mint       = Color(0xFFECFDF5);
}

// ── Main Screen ───────────────────────────────────────────────────────────────
class CustomerPaymentsScreen extends StatefulWidget {
  final Customer customer;
  final LanguageProvider languageProvider;

  const CustomerPaymentsScreen({
    super.key,
    required this.customer,
    required this.languageProvider,
  });

  @override
  State<CustomerPaymentsScreen> createState() => _CustomerPaymentsScreenState();
}

class _CustomerPaymentsScreenState extends State<CustomerPaymentsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String? _error;
  double _totalPaid = 0;
  int? _expandedIndex;

  final _df  = DateFormat('MMM dd, yyyy');
  final _dtf = DateFormat('MMM dd, yyyy • hh:mm a');
  final _cf  = NumberFormat('#,##0.00');

  String _filterMethod = 'all';
  DateTimeRange? _dateRange;

  late AnimationController _animCtrl;

  // Method palette
  static const _methodDefs = {
    'all':    (_C.slate500,   Icons.list_alt_outlined,         'All',    'سب'),
    'cash':   (_C.emerald,    Icons.payments_outlined,          'Cash',   'نقد'),
    'bank':   (_C.blue,       Icons.account_balance_outlined,   'Bank',   'بینک'),
    'cheque': (_C.amber,      Icons.receipt_long_outlined,      'Cheque', 'چیک'),
    'card':   (_C.violet,     Icons.credit_card_outlined,       'Card',   'کارڈ'),
    'online': (_C.pink,       Icons.public_outlined,            'Online', 'آن لائن'),
  };

  Map<String, Map<String, dynamic>> _methodMeta(LanguageProvider lp) {
    return _methodDefs.map((key, v) => MapEntry(key, {
      'color': v.$1,
      'icon':  v.$2,
      'label': lp.isEnglish ? v.$3 : v.$4,
    }));
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fetchPayments();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String? _getToken() {
    try { return Provider.of<AuthProvider>(context, listen: false).user?.token; }
    catch (_) { return null; }
  }

  Future<void> _fetchPayments() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final params = <String, String>{};
      if (_filterMethod != 'all') params['payment_method'] = _filterMethod;
      if (_dateRange != null) {
        params['from'] = _dateRange!.start.toIso8601String();
        params['to']   = _dateRange!.end.toIso8601String();
      }
      params['page']  = '1';
      params['limit'] = '100';

      String url = '${ApiConfig.baseUrl}/customers/${widget.customer.id}/payments';
      if (params.isNotEmpty) {
        url += '?' + params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      }

      final response = await http.get(Uri.parse(url), headers: {
        'Content-Type': 'application/json',
        if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
      });

      if (response.headers['content-type']?.contains('text/html') ?? false) {
        throw Exception('Server returned HTML. Please check your backend configuration.');
      }

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        List<Map<String, dynamic>> list = [];
        if (data['data'] != null) {
          if (data['data']['payments'] != null) {
            list = (data['data']['payments'] as List).map<Map<String, dynamic>>((e) => Map.from(e)).toList();
          } else if (data['data'] is List) {
            list = (data['data'] as List).map<Map<String, dynamic>>((e) => Map.from(e)).toList();
          }
        }
        double total = 0;
        for (final p in list) {
          total += double.tryParse((p['debit'] ?? p['amount'] ?? 0).toString()) ?? 0;
        }
        setState(() { _payments = list; _totalPaid = total; _isLoading = false; _expandedIndex = null; });
        _animCtrl.forward(from: 0);
      } else {
        setState(() {
          _error = data['message'] ?? (widget.languageProvider.isEnglish ? 'Failed to load payments' : 'ادائیگیاں لوڈ کرنے میں ناکامی');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _deletePayment(Map<String, dynamic> payment) async {
    final lp = widget.languageProvider;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(payment: payment, df: _df, cf: _cf, languageProvider: lp),
    );
    if (confirmed != true) return;

    try {
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/customers/${widget.customer.id}/payments/${payment['id']}'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        _showSnack(lp.isEnglish ? 'Payment deleted successfully' : 'ادائیگی کامیابی سے حذف ہوگئی', _C.emerald);
        try { Provider.of<CustomerLedgerProvider>(context, listen: false).fetchCustomerLedger(customerId: widget.customer.id); }
        catch (_) {}
        _fetchPayments();
      } else {
        _showSnack(data['message'] ?? (lp.isEnglish ? 'Delete failed' : 'حذف کرنے میں ناکامی'), _C.red);
      }
    } catch (e) {
      _showSnack('${lp.isEnglish ? 'Error' : 'خرابی'}: $e', _C.red);
    }
  }

  Future<void> _markChequeCleared(Map<String, dynamic> payment) async {
    final lp = widget.languageProvider;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ChequeClearDialog(payment: payment, cf: _cf, languageProvider: lp),
    );
    if (confirmed != true) return;

    try {
      final res = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/customers/customer-ledger/${payment['id']}/cheque-status'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
        body: json.encode({'cheque_cleared': true, 'cheque_cleared_date': DateTime.now().toIso8601String()}),
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        _showSnack(lp.isEnglish ? 'Cheque marked as cleared' : 'چیک کلیئر شدہ کے طور پر نشان زد ہوگیا', _C.emerald);
        _fetchPayments();
      } else {
        _showSnack(data['message'] ?? (lp.isEnglish ? 'Failed' : 'ناکامی'), _C.red);
      }
    } catch (e) {
      _showSnack('${lp.isEnglish ? 'Error' : 'خرابی'}: $e', _C.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _C.emerald)),
        child: child!,
      ),
    );
    if (picked != null) { setState(() => _dateRange = picked); _fetchPayments(); }
  }

  @override
  Widget build(BuildContext context) {
    final lp = widget.languageProvider;
    final meta = _methodMeta(lp);

    return Scaffold(
      backgroundColor: _C.bg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          _AppBarSliver(
            customer: widget.customer,
            lp: lp,
            dateRange: _dateRange,
            payments: _payments,
            totalPaid: _totalPaid,
            filterMethod: _filterMethod,
            onPickDate: _pickDateRange,
            onClearDate: () { setState(() => _dateRange = null); _fetchPayments(); },
            cf: _cf,
            df: _df,
          ),
        ],
        body: Column(
          children: [
            _MethodFilterBar(
              selectedMethod: _filterMethod,
              methodMeta: meta,
              lp: lp,
              onSelect: (k) { setState(() => _filterMethod = k); _fetchPayments(); },
            ),
            Expanded(child: _buildBody(lp, meta)),
          ],
        ),
      ),
      floatingActionButton: _NewPaymentFab(
        lp: lp,
        customer: widget.customer,
        onCreated: _fetchPayments,
      ),
    );
  }

  Widget _buildBody(LanguageProvider lp, Map<String, Map<String, dynamic>> meta) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _C.emerald, strokeWidth: 2.5));
    }
    if (_error != null) {
      return _ErrorState(error: _error!, lp: lp, onRetry: _fetchPayments);
    }
    if (_payments.isEmpty) {
      return _EmptyState(lp: lp);
    }

    return RefreshIndicator(
      onRefresh: _fetchPayments,
      color: _C.emerald,
      strokeWidth: 2.5,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: _payments.length,
        itemBuilder: (_, i) {
          final isExp = _expandedIndex == i;
          return FadeTransition(
            opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
              parent: _animCtrl,
              curve: Interval(
                (i / _payments.length).clamp(0.0, 0.8),
                ((i / _payments.length) + 0.35).clamp(0.0, 1.0),
                curve: Curves.easeOut,
              ),
            )),
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                  .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut)),
              child: _PaymentCard(
                payment: _payments[i],
                df: _df,
                dtf: _dtf,
                cf: _cf,
                methodMeta: meta,
                isExpanded: isExp,
                onTap: () => setState(() => _expandedIndex = isExp ? null : i),
                onDelete: () => _deletePayment(_payments[i]),
                onMarkCleared: () => _markChequeCleared(_payments[i]),
                languageProvider: lp,
                index: i,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── App Bar (SliverAppBar) ────────────────────────────────────────────────────
class _AppBarSliver extends StatelessWidget {
  final Customer customer;
  final LanguageProvider lp;
  final DateTimeRange? dateRange;
  final List<Map<String, dynamic>> payments;
  final double totalPaid;
  final String filterMethod;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final NumberFormat cf;
  final DateFormat df;

  const _AppBarSliver({
    required this.customer, required this.lp, required this.dateRange,
    required this.payments, required this.totalPaid, required this.filterMethod,
    required this.onPickDate, required this.onClearDate,
    required this.cf, required this.df,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 190,
      pinned: true,
      elevation: 0,
      backgroundColor: _C.slate900,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 15, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // PDF export
        Builder(builder: (ctx) => IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.white),
          ),
          onPressed: () => CustomerPdfService.showDownloadOptions(
            context: ctx,
            customer: customer,
            payments: payments,
            totalPaid: totalPaid,
            filterMethod: filterMethod,
            dateRange: dateRange,
            languageProvider: lp,
          ),
          tooltip: lp.isEnglish ? 'Export PDF' : 'PDF ایکسپورٹ',
        )),
        // Date range
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: dateRange != null
                  ? _C.emerald.withOpacity(0.25)
                  : Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: dateRange != null
                  ? Border.all(color: _C.emerald.withOpacity(0.6))
                  : null,
            ),
            child: Icon(
              Icons.date_range_outlined,
              size: 18,
              color: dateRange != null ? _C.emerald : Colors.white,
            ),
          ),
          onPressed: onPickDate,
        ),
        if (dateRange != null)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _C.red.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, size: 15, color: _C.red),
            ),
            onPressed: onClearDate,
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _HeaderBackground(
          customer: customer,
          lp: lp,
          payments: payments,
          totalPaid: totalPaid,
          dateRange: dateRange,
          cf: cf,
          df: df,
        ),
      ),
    );
  }
}

class _HeaderBackground extends StatelessWidget {
  final Customer customer;
  final LanguageProvider lp;
  final List<Map<String, dynamic>> payments;
  final double totalPaid;
  final DateTimeRange? dateRange;
  final NumberFormat cf;
  final DateFormat df;

  const _HeaderBackground({
    required this.customer, required this.lp, required this.payments,
    required this.totalPaid, required this.dateRange,
    required this.cf, required this.df,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Deep gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Decorative emerald glow
        Positioned(
          right: -40,
          top: -20,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _C.emerald.withOpacity(0.18),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        // Content
        Positioned(
          left: 20, right: 20, bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Customer name + label
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _C.emerald.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.emerald.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.person_outline, size: 20, color: _C.emerald),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: -0.5,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lp.isEnglish ? 'Payment History' : 'ادائیگی کی تاریخ',
                          style: TextStyle(
                            fontSize: 12, color: Colors.white.withOpacity(0.55),
                            fontFamily: lp.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Stat pills
              Row(
                children: [
                  _StatPill(
                    label: lp.isEnglish ? 'Payments' : 'ادائیگیاں',
                    value: '${payments.length}',
                    icon: Icons.receipt_long_outlined,
                    lp: lp,
                  ),
                  const SizedBox(width: 10),
                  _StatPill(
                    label: lp.isEnglish ? 'Received' : 'وصول شدہ',
                    value: 'Rs ${cf.format(totalPaid)}',
                    icon: Icons.payments_outlined,
                    accent: true,
                    lp: lp,
                  ),
                  if (dateRange != null) ...[
                    const SizedBox(width: 10),
                    _StatPill(
                      label: lp.isEnglish ? 'Range' : 'حد',
                      value: '${df.format(dateRange!.start)} – ${df.format(dateRange!.end)}',
                      icon: Icons.date_range,
                      lp: lp,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool accent;
  final LanguageProvider lp;

  const _StatPill({
    required this.label, required this.value, required this.icon,
    this.accent = false, required this.lp,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: accent ? _C.emerald.withOpacity(0.15) : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accent ? _C.emerald.withOpacity(0.35) : Colors.white.withOpacity(0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: accent ? _C.emerald : Colors.white54),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w600,
                      color: accent ? _C.emerald.withOpacity(0.8) : Colors.white38,
                      fontFamily: lp.fontFamily, letterSpacing: 0.4,
                    ),
                  ),
                  Text(value,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: accent ? _C.emerald : Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Method Filter Bar ─────────────────────────────────────────────────────────
class _MethodFilterBar extends StatelessWidget {
  final String selectedMethod;
  final Map<String, Map<String, dynamic>> methodMeta;
  final LanguageProvider lp;
  final ValueChanged<String> onSelect;

  const _MethodFilterBar({
    required this.selectedMethod, required this.methodMeta,
    required this.lp, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: methodMeta.keys.map((key) {
            final meta  = methodMeta[key]!;
            final color = meta['color'] as Color;
            final sel   = selectedMethod == key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? color : _C.slate100,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: sel ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))] : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        meta['icon'] as IconData,
                        size: 13,
                        color: sel ? Colors.white : _C.slate500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        meta['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? Colors.white : _C.slate500,
                          fontFamily: lp.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Payment Card ──────────────────────────────────────────────────────────────
class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final DateFormat df;
  final DateFormat dtf;
  final NumberFormat cf;
  final Map<String, Map<String, dynamic>> methodMeta;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onMarkCleared;
  final LanguageProvider languageProvider;
  final int index;

  const _PaymentCard({
    required this.payment, required this.df, required this.dtf, required this.cf,
    required this.methodMeta, required this.isExpanded, required this.onTap,
    required this.onDelete, required this.onMarkCleared,
    required this.languageProvider, required this.index,
  });

  String _methodKey() {
    if (payment['payment_method'] != null) return payment['payment_method'].toString().toLowerCase();
    final d = (payment['description'] ?? '').toString().toLowerCase();
    if (d.contains('bank'))   return 'bank';
    if (d.contains('cheque')) return 'cheque';
    if (d.contains('card'))   return 'card';
    if (d.contains('online')) return 'online';
    return 'cash';
  }

  String _methodLabel(String key) {
    final labels = languageProvider.isEnglish
        ? {'cash':'Cash','bank':'Bank','cheque':'Cheque','card':'Card','online':'Online'}
        : {'cash':'نقد','bank':'بینک','cheque':'چیک','card':'کارڈ','online':'آن لائن'};
    return labels[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final method = _methodKey();
    final meta   = methodMeta[method] ?? methodMeta['cash']!;
    final color  = meta['color'] as Color;

    final amount    = double.tryParse((payment['debit'] ?? payment['amount'] ?? 0).toString()) ?? 0;
    final bankName  = payment['bank_name']?.toString();
    final chequeNum = payment['cheque_number']?.toString();
    final chequeCleared = payment['cheque_cleared'] == true;

    String _parseDate(String fmt, String? a, String? b, String? c) {
      final raw = a ?? b ?? c;
      if (raw == null) return '—';
      try { return fmt == 'd' ? df.format(DateTime.parse(raw)) : dtf.format(DateTime.parse(raw)); }
      catch (_) { return '—'; }
    }

    final date     = _parseDate('d', payment['date']?.toString(), payment['transaction_date']?.toString(), payment['created_at']?.toString());
    final dateTime = _parseDate('dt', payment['date']?.toString(), payment['transaction_date']?.toString(), payment['created_at']?.toString());
    final refNum   = (payment['reference_number'] ?? payment['reference'])?.toString();
    final balance  = payment['balance'] != null ? double.tryParse(payment['balance'].toString()) : null;
    final desc     = (payment['description'] ?? payment['notes'])?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isExpanded ? color.withOpacity(0.10) : Colors.black.withOpacity(0.04),
            blurRadius: isExpanded ? 20 : 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isExpanded ? color.withOpacity(0.25) : _C.slate100,
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // ── Collapsed Row ──
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Method icon badge
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Icon(meta['icon'] as IconData, size: 20, color: color),
                    ),
                    const SizedBox(width: 12),
                    // Centre info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _methodLabel(method),
                                style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: _C.slate900, fontFamily: languageProvider.fontFamily,
                                ),
                              ),
                              if (chequeNum != null && chequeNum.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '# $chequeNum',
                                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                              if (method == 'cheque' && chequeCleared) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.check_circle, size: 14, color: _C.emerald),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 11, color: _C.slate500),
                              const SizedBox(width: 4),
                              Text(date, style: const TextStyle(fontSize: 11, color: _C.slate500)),
                              if (bankName != null && bankName.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.account_balance_outlined, size: 11, color: _C.slate500),
                                const SizedBox(width: 3),
                                Flexible(child: Text(bankName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: _C.slate500))),
                              ],
                              if (refNum != null && refNum.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Flexible(child: Text(refNum,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: _C.violet, fontWeight: FontWeight.w600))),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Amount + actions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rs ${cf.format(amount)}',
                          style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800, color: _C.emerald,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Delete
                            GestureDetector(
                              onTap: onDelete,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: _C.red.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.delete_outline, size: 15, color: _C.red),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Expand chevron
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: isExpanded ? color : _C.slate300,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Expanded Detail ──
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _DetailPanel(
                payment: payment,
                color: color,
                method: method,
                amount: amount,
                bankName: bankName,
                chequeNum: chequeNum,
                chequeDate: payment['cheque_date'] != null
                    ? ((){try{return df.format(DateTime.parse(payment['cheque_date']));}catch(_){return null;}})()
                    : null,
                chequeCleared: chequeCleared,
                chequeClearedDate: payment['cheque_cleared_date'] != null
                    ? ((){try{return df.format(DateTime.parse(payment['cheque_cleared_date']));}catch(_){return null;}})()
                    : null,
                refNum: refNum,
                desc: desc,
                dateTime: dateTime,
                balance: balance,
                cf: cf,
                lp: languageProvider,
                methodLabel: _methodLabel(method),
                onMarkCleared: onMarkCleared,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detail Panel ──────────────────────────────────────────────────────────────
class _DetailPanel extends StatelessWidget {
  final Map<String, dynamic> payment;
  final Color color;
  final String method;
  final double amount;
  final String? bankName;
  final String? chequeNum;
  final String? chequeDate;
  final bool chequeCleared;
  final String? chequeClearedDate;
  final String? refNum;
  final String? desc;
  final String dateTime;
  final double? balance;
  final NumberFormat cf;
  final LanguageProvider lp;
  final String methodLabel;
  final VoidCallback onMarkCleared;

  const _DetailPanel({
    required this.payment, required this.color, required this.method,
    required this.amount, required this.bankName, required this.chequeNum,
    required this.chequeDate, required this.chequeCleared,
    required this.chequeClearedDate, required this.refNum, required this.desc,
    required this.dateTime, required this.balance, required this.cf,
    required this.lp, required this.methodLabel, required this.onMarkCleared,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.bg,
        border: Border(top: BorderSide(color: color.withOpacity(0.15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: color.withOpacity(0.06),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: color),
                const SizedBox(width: 7),
                Text(
                  lp.isEnglish ? 'Payment Details' : 'ادائیگی کی تفصیلات',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color,
                    fontFamily: lp.fontFamily,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ID #${payment['id']}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Row: date + method
                Row(
                  children: [
                    Expanded(child: _InfoTile(icon: Icons.access_time_outlined, label: lp.isEnglish ? 'Date & Time' : 'تاریخ و وقت', value: dateTime, color: color, lp: lp)),
                    const SizedBox(width: 10),
                    Expanded(child: _InfoTile(icon: Icons.category_outlined, label: lp.isEnglish ? 'Method' : 'طریقہ', value: methodLabel, valueColor: color, color: color, lp: lp)),
                  ],
                ),

                if (bankName != null && bankName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoTile(icon: Icons.account_balance_outlined, label: lp.isEnglish ? 'Bank' : 'بینک', value: bankName!, color: color, lp: lp),
                ],

                if (chequeNum != null && chequeNum!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _InfoTile(icon: Icons.receipt_long_outlined, label: lp.isEnglish ? 'Cheque #' : 'چیک نمبر', value: chequeNum!, color: color, lp: lp)),
                      if (chequeDate != null) ...[
                        const SizedBox(width: 10),
                        Expanded(child: _InfoTile(icon: Icons.event_outlined, label: lp.isEnglish ? 'Cheque Date' : 'چیک کی تاریخ', value: chequeDate!, color: color, lp: lp)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ChequeClearTile(
                    chequeCleared: chequeCleared,
                    chequeClearedDate: chequeClearedDate,
                    lp: lp,
                    onMarkCleared: onMarkCleared,
                  ),
                ],

                if (refNum != null && refNum!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoTile(icon: Icons.tag_outlined, label: lp.isEnglish ? 'Reference' : 'حوالہ نمبر', value: refNum!, valueColor: _C.violet, color: color, lp: lp),
                ],

                if (desc != null && desc!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoTile(icon: Icons.notes_outlined, label: lp.isEnglish ? 'Description' : 'تفصیل', value: desc!, color: color, lp: lp),
                ],

                const SizedBox(height: 12),
                // Amount / Balance summary
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.slate100),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _SummaryCell(
                        label: lp.isEnglish ? 'Received' : 'وصول شدہ رقم',
                        value: 'Rs ${cf.format(amount)}',
                        color: _C.emerald,
                        lp: lp,
                      )),
                      Container(width: 1, height: 38, color: _C.slate100),
                      Expanded(child: _SummaryCell(
                        label: lp.isEnglish ? 'Balance' : 'بیلنس',
                        value: balance != null ? 'Rs ${cf.format(balance)}' : '—',
                        color: (balance ?? 0) > 0 ? _C.emerald : (balance ?? 0) < 0 ? _C.red : _C.slate500,
                        lp: lp,
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color color;
  final LanguageProvider lp;

  const _InfoTile({
    required this.icon, required this.label, required this.value,
    this.valueColor, required this.color, required this.lp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.slate100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 9, color: _C.slate500, fontWeight: FontWeight.w600, letterSpacing: 0.3, fontFamily: lp.fontFamily)),
                const SizedBox(height: 3),
                Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: valueColor ?? _C.slate900, fontFamily: lp.fontFamily)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChequeClearTile extends StatelessWidget {
  final bool chequeCleared;
  final String? chequeClearedDate;
  final LanguageProvider lp;
  final VoidCallback onMarkCleared;

  const _ChequeClearTile({
    required this.chequeCleared, required this.chequeClearedDate,
    required this.lp, required this.onMarkCleared,
  });

  @override
  Widget build(BuildContext context) {
    final color = chequeCleared ? _C.emerald : _C.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(chequeCleared ? Icons.check_circle_outline : Icons.schedule_outlined, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lp.isEnglish ? 'Cheque Status' : 'چیک کی حالت',
                  style: const TextStyle(fontSize: 9, color: _C.slate500, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                ),
                const SizedBox(height: 2),
                Text(
                  chequeCleared
                      ? (lp.isEnglish ? 'Cleared${chequeClearedDate != null ? ' on $chequeClearedDate' : ''}' : 'کلیئر شدہ')
                      : (lp.isEnglish ? 'Pending — awaiting bank clearing' : 'زیر التواء — کلیئرنگ کے انتظار میں'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, fontFamily: lp.fontFamily),
                ),
              ],
            ),
          ),
          if (!chequeCleared)
            GestureDetector(
              onTap: onMarkCleared,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _C.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  lp.isEnglish ? 'Clear' : 'کلیئر',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final LanguageProvider lp;

  const _SummaryCell({required this.label, required this.value, required this.color, required this.lp});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: _C.slate500, fontWeight: FontWeight.w500, fontFamily: lp.fontFamily)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────
class _NewPaymentFab extends StatelessWidget {
  final LanguageProvider lp;
  final Customer customer;
  final VoidCallback onCreated;

  const _NewPaymentFab({required this.lp, required this.customer, required this.onCreated});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await showDialog<bool>(
          context: context,
          builder: (_) => CustomerPaymentDialog(customer: customer, languageProvider: lp),
        );
        if (result == true) onCreated();
      },
      backgroundColor: _C.slate900,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: _C.emerald, borderRadius: BorderRadius.circular(7)),
        child: const Icon(Icons.add, size: 14, color: Colors.white),
      ),
      label: Text(
        lp.isEnglish ? 'New Payment' : 'نئی ادائیگی',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, fontFamily: lp.fontFamily),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

// ── Error / Empty States ──────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  final LanguageProvider lp;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.lp, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _C.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 40, color: _C.red),
            ),
            const SizedBox(height: 16),
            Text(lp.isEnglish ? 'Unable to load' : 'لوڈ کرنے میں ناکامی',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.slate900)),
            const SizedBox(height: 6),
            Text(error, style: const TextStyle(fontSize: 12, color: _C.slate500), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(lp.isEnglish ? 'Try Again' : 'دوبارہ کوشش کریں', style: TextStyle(fontFamily: lp.fontFamily)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.slate900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final LanguageProvider lp;
  const _EmptyState({required this.lp});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: _C.emerald.withOpacity(0.25), width: 2),
            ),
            child: const Icon(Icons.payments_outlined, size: 48, color: _C.emerald),
          ),
          const SizedBox(height: 20),
          Text(
            lp.isEnglish ? 'No payments yet' : 'ابھی تک کوئی ادائیگی نہیں',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _C.slate900, fontFamily: lp.fontFamily),
          ),
          const SizedBox(height: 6),
          Text(
            lp.isEnglish ? 'Tap the button below to record one' : 'ریکارڈ کرنے کے لیے نیچے ٹیپ کریں',
            style: TextStyle(fontSize: 13, color: _C.slate500, fontFamily: lp.fontFamily),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Delete Dialog ─────────────────────────────────────────────────────────────
class _DeleteDialog extends StatelessWidget {
  final Map<String, dynamic> payment;
  final DateFormat df;
  final NumberFormat cf;
  final LanguageProvider languageProvider;

  const _DeleteDialog({required this.payment, required this.df, required this.cf, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    final lp = languageProvider;
    final amount = double.tryParse((payment['debit'] ?? payment['amount'] ?? 0).toString()) ?? 0;
    final method = payment['payment_method'] ?? 'payment';
    final bank   = payment['bank_name'];
    final raw    = payment['date'] ?? payment['transaction_date'];
    final date   = raw != null
        ? ((){try{return df.format(DateTime.parse(raw.toString()));}catch(_){return lp.isEnglish?'Unknown date':'نامعلوم تاریخ';}})()
        : (lp.isEnglish ? 'Unknown date' : 'نامعلوم تاریخ');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _C.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: _C.red, size: 28),
            ),
            const SizedBox(height: 14),
            Text(lp.isEnglish ? 'Delete Payment?' : 'ادائیگی حذف کریں؟',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.slate900)),
            const SizedBox(height: 8),
            Text(
              lp.isEnglish
                  ? 'This will reverse the ledger entry and cannot be undone.'
                  : 'یہ لیجر اندراج کو ریورس کر دے گا اور واپس نہیں کیا جا سکتا۔',
              style: const TextStyle(fontSize: 13, color: _C.slate500, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.slate100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rs ${cf.format(amount)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _C.slate900)),
                  const SizedBox(height: 4),
                  Text(
                    '$method${bank != null ? ' • $bank' : ''} • $date',
                    style: const TextStyle(fontSize: 12, color: _C.slate500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _C.slate300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(lp.isEnglish ? 'Cancel' : 'منسوخ کریں',
                        style: TextStyle(color: _C.slate700, fontFamily: lp.fontFamily, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                    ),
                    child: Text(lp.isEnglish ? 'Delete' : 'حذف کریں',
                        style: TextStyle(fontWeight: FontWeight.w700, fontFamily: lp.fontFamily)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cheque Clear Dialog ───────────────────────────────────────────────────────
class _ChequeClearDialog extends StatelessWidget {
  final Map<String, dynamic> payment;
  final NumberFormat cf;
  final LanguageProvider languageProvider;

  const _ChequeClearDialog({required this.payment, required this.cf, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    final lp = languageProvider;
    final amount = double.tryParse((payment['debit'] ?? payment['amount'] ?? 0).toString()) ?? 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _C.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: _C.amber, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              lp.isEnglish ? 'Mark Cheque Cleared?' : 'چیک کلیئر نشان زد کریں؟',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _C.slate900),
            ),
            const SizedBox(height: 8),
            Text(
              lp.isEnglish
                  ? 'This will update the bank balance and mark the cheque as cleared.'
                  : 'یہ بینک بیلنس کو اپ ڈیٹ کرے گا اور چیک کو کلیئر شدہ نشان زد کرے گا۔',
              style: const TextStyle(fontSize: 13, color: _C.slate500, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.amber.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.amber.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rs ${cf.format(amount)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _C.slate900)),
                  if (payment['cheque_number'] != null)
                    Text('${lp.isEnglish ? 'Cheque #' : 'چیک نمبر'}: ${payment['cheque_number']}',
                        style: const TextStyle(fontSize: 12, color: _C.slate500)),
                  if (payment['bank_name'] != null)
                    Text('${lp.isEnglish ? 'Bank' : 'بینک'}: ${payment['bank_name']}',
                        style: const TextStyle(fontSize: 12, color: _C.slate500)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _C.slate300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(lp.isEnglish ? 'Cancel' : 'منسوخ',
                        style: TextStyle(color: _C.slate700, fontFamily: lp.fontFamily, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.amber,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                    ),
                    child: Text(lp.isEnglish ? 'Mark Cleared' : 'کلیئر کریں',
                        style: TextStyle(fontWeight: FontWeight.w700, fontFamily: lp.fontFamily)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}