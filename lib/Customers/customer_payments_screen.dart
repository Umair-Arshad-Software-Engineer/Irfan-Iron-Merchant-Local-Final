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
import '../services/CustomerPdfService.dart';
import 'customer_payment_dialog.dart';

class CustomerPaymentsScreen extends StatefulWidget {
  final Customer customer;

  const CustomerPaymentsScreen({super.key, required this.customer});

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

  final _df = DateFormat('MMM dd, yyyy');
  final _dtf = DateFormat('MMM dd, yyyy • hh:mm a');
  final _cf = NumberFormat('#,##0.00');

  String _filterMethod = 'all';
  DateTimeRange? _dateRange;

  late AnimationController _animCtrl;

  // Method metadata
  static const Map<String, Map<String, dynamic>> _methodMeta = {
    'all': {'label': 'All', 'icon': Icons.list_alt_outlined, 'color': Color(0xFF6B7280)},
    'cash': {'label': 'Cash', 'icon': Icons.payments_outlined, 'color': Color(0xFF10B981)},
    'bank': {'label': 'Bank', 'icon': Icons.account_balance_outlined, 'color': Color(0xFF3B82F6)},
    'cheque': {'label': 'Cheque', 'icon': Icons.receipt_long_outlined, 'color': Color(0xFFF59E0B)},
    'card': {'label': 'Card', 'icon': Icons.credit_card_outlined, 'color': Color(0xFF8B5CF6)},
    'online': {'label': 'Online', 'icon': Icons.public_outlined, 'color': Color(0xFFEC4899)},
  };

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fetchPayments();
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

  Future<void> _fetchPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final params = <String, String>{};
      if (_filterMethod != 'all') params['payment_method'] = _filterMethod;
      if (_dateRange != null) {
        params['from'] = _dateRange!.start.toIso8601String();
        params['to'] = _dateRange!.end.toIso8601String();
      }

      params['page'] = '1';
      params['limit'] = '100';

      String url = '${ApiConfig.baseUrl}/customers/${widget.customer.id}/payments';

      if (params.isNotEmpty) {
        url += '?' + params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      }

      print('Fetching payments from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
      );

      if (response.headers['content-type']?.contains('text/html') ?? false) {
        throw Exception('Server returned HTML. Please check your backend configuration.');
      }

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        List<Map<String, dynamic>> paymentList = [];

        if (data['data'] != null) {
          if (data['data']['payments'] != null) {
            paymentList = (data['data']['payments'] as List)
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList();
          } else if (data['data'] is List) {
            paymentList = (data['data'] as List)
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }

        // Calculate total paid - DEBIT entries (payments received)
        double total = 0;
        for (final p in paymentList) {
          double amount = 0;
          if (p['debit'] != null) {
            amount = double.tryParse(p['debit'].toString()) ?? 0;
          } else if (p['amount'] != null) {
            amount = double.tryParse(p['amount'].toString()) ?? 0;
          }
          total += amount;
        }

        setState(() {
          _payments = paymentList;
          _totalPaid = total;
          _isLoading = false;
          _expandedIndex = null;
        });

        _animCtrl.forward(from: 0);
      } else {
        setState(() {
          _error = data['message'] ?? 'Failed to load payments';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching payments: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePayment(Map<String, dynamic> payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(payment: payment, df: _df, cf: _cf),
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/customers/${widget.customer.id}/payments/${payment['id']}'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment deleted successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );

        try {
          Provider.of<CustomerLedgerProvider>(context, listen: false)
              .fetchCustomerLedger(customerId: widget.customer.id);
        } catch (_) {}

        _fetchPayments();
      } else {
        _showError(data['message'] ?? 'Delete failed');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _markChequeCleared(Map<String, dynamic> payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mark Cheque as Cleared'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This will update the bank balance and mark the cheque as cleared.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    'Amount: Rs ${_cf.format(double.tryParse(payment['debit']?.toString() ?? '0') ?? 0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (payment['cheque_number'] != null)
                    Text('Cheque #: ${payment['cheque_number']}'),
                  if (payment['bank_name'] != null)
                    Text('Bank: ${payment['bank_name']}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Cleared'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/customers/customer-ledger/${payment['id']}/cheque-status'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
        body: json.encode({
          'cheque_cleared': true,
          'cheque_cleared_date': DateTime.now().toIso8601String(),
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cheque marked as cleared'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _fetchPayments();
      } else {
        _showError(data['message'] ?? 'Failed to mark cheque as cleared');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF10B981)),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      _fetchPayments();
    }
  }

  Future<void> _generatePdf() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );

      await CustomerPdfService.generatePaymentReport(
        customer: widget.customer,
        payments: _payments,
        totalPaid: _totalPaid,
        filterMethod: _filterMethod,
        dateRange: _dateRange,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generated successfully'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStatsBar(),
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (_) => CustomerPaymentDialog(customer: widget.customer),
          );
          if (result == true) _fetchPayments();
        },
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Payment', style: TextStyle(fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF10B981),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.customer.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const Text(
            'Payment History',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onSelected: (value) {
            if (value == 'options') {
              CustomerPdfService.showDownloadOptions(
                context: context,
                customer: widget.customer,
                payments: _payments,
                totalPaid: _totalPaid,
                filterMethod: _filterMethod,
                dateRange: _dateRange,
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'options',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, size: 18),
                  SizedBox(width: 8),
                  Text('Export PDF'),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.calendar_month_outlined),
              if (_dateRange != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.yellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: _pickDateRange,
        ),
        if (_dateRange != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 20),
            onPressed: () {
              setState(() => _dateRange = null);
              _fetchPayments();
            },
          ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white12),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          _statChip(
            icon: Icons.receipt_long_outlined,
            label: 'Total Payments',
            value: '${_payments.length}',
            bg: Colors.white12,
          ),
          const SizedBox(width: 10),
          _statChip(
            icon: Icons.payments_outlined,
            label: 'Total Received',
            value: 'Rs ${_cf.format(_totalPaid)}',
            bg: Colors.white12,
          ),
          if (_dateRange != null) ...[
            const SizedBox(width: 10),
            _statChip(
              icon: Icons.date_range,
              label: 'Date Range',
              value: '${_df.format(_dateRange!.start)} – ${_df.format(_dateRange!.end)}',
              bg: Colors.white24,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color bg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 11, color: Colors.white70),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _methodMeta.keys.map((key) {
            final meta = _methodMeta[key]!;
            final sel = _filterMethod == key;
            final color = meta['color'] as Color;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _filterMethod = key);
                  _fetchPayments();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? color.withOpacity(0.1) : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? color : const Color(0xFFE5E5EA),
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        meta['icon'] as IconData,
                        size: 14,
                        color: sel ? color : const Color(0xFF8E8E93),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        meta['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          color: sel ? color : const Color(0xFF8E8E93),
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchPayments,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.payments_outlined,
                size: 56,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No payments found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to record a payment',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPayments,
      color: const Color(0xFF10B981),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _payments.length,
        itemBuilder: (_, i) {
          final isExpanded = _expandedIndex == i;
          return FadeTransition(
            opacity: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                parent: _animCtrl,
                curve: Interval(
                  (i / _payments.length) * 0.6,
                  (i / _payments.length) * 0.6 + 0.4,
                  curve: Curves.easeOut,
                ),
              ),
            ),
            child: _PaymentCard(
              payment: _payments[i],
              df: _df,
              dtf: _dtf,
              cf: _cf,
              methodMeta: _methodMeta,
              isExpanded: isExpanded,
              onTap: () => setState(() => _expandedIndex = isExpanded ? null : i),
              onDelete: () => _deletePayment(_payments[i]),
              onMarkCleared: () => _markChequeCleared(_payments[i]),
            ),
          );
        },
      ),
    );
  }
}

// Payment Card (expandable)
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

  const _PaymentCard({
    required this.payment,
    required this.df,
    required this.dtf,
    required this.cf,
    required this.methodMeta,
    required this.isExpanded,
    required this.onTap,
    required this.onDelete,
    required this.onMarkCleared,
  });

  @override
  Widget build(BuildContext context) {
    // Determine payment method
    String method = 'cash';
    if (payment['payment_method'] != null) {
      method = payment['payment_method'].toString().toLowerCase();
    } else {
      final desc = payment['description']?.toString().toLowerCase() ?? '';
      if (desc.contains('bank')) method = 'bank';
      else if (desc.contains('cheque')) method = 'cheque';
      else if (desc.contains('card')) method = 'card';
      else if (desc.contains('online')) method = 'online';
    }

    final meta = methodMeta[method] ?? methodMeta['cash']!;
    final color = meta['color'] as Color;

    // Get amount - payments are DEBIT entries
    double amount = 0;
    if (payment['debit'] != null) {
      amount = double.tryParse(payment['debit'].toString()) ?? 0;
    } else if (payment['amount'] != null) {
      amount = double.tryParse(payment['amount'].toString()) ?? 0;
    }

    // Parse dates
    final date = payment['date'] != null
        ? df.format(DateTime.parse(payment['date']))
        : payment['transaction_date'] != null
        ? df.format(DateTime.parse(payment['transaction_date']))
        : payment['created_at'] != null
        ? df.format(DateTime.parse(payment['created_at']))
        : '—';

    final dateTime = payment['date'] != null
        ? dtf.format(DateTime.parse(payment['date']))
        : payment['transaction_date'] != null
        ? dtf.format(DateTime.parse(payment['transaction_date']))
        : payment['created_at'] != null
        ? dtf.format(DateTime.parse(payment['created_at']))
        : '—';

    // Payment details
    final bankName = payment['bank_name']?.toString();
    final chequeNum = payment['cheque_number']?.toString();
    final chequeDate = payment['cheque_date'] != null
        ? df.format(DateTime.parse(payment['cheque_date']))
        : null;
    final chequeCleared = payment['cheque_cleared'] == true;
    final chequeClearedDate = payment['cheque_cleared_date'] != null
        ? df.format(DateTime.parse(payment['cheque_cleared_date']))
        : null;
    final refNum = payment['reference_number']?.toString() ??
        payment['reference']?.toString();
    final desc = payment['description']?.toString() ??
        payment['notes']?.toString();
    final balance = payment['balance'] != null
        ? double.tryParse(payment['balance'].toString())
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: isExpanded
                ? color.withOpacity(0.12)
                : Colors.black.withOpacity(0.05),
            blurRadius: isExpanded ? 16 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (always visible)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Method badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(meta['icon'] as IconData, size: 13, color: color),
                            const SizedBox(width: 5),
                            Text(
                              (meta['label'] as String).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (bankName != null && bankName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_balance_outlined,
                                size: 11,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                bankName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (method == 'cheque' && chequeCleared) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 11, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'Cleared',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Amount chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Rs ${cf.format(amount)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Quick-info row
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (chequeNum != null && chequeNum.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Chq# $chequeNum',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (refNum != null && refNum.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.tag_outlined,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            refNum,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7C3AED),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Expand/collapse arrow
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: isExpanded ? color : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded detail panel
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildDetailPanel(
              color,
              method,
              bankName,
              chequeNum,
              chequeDate,
              chequeCleared,
              chequeClearedDate,
              refNum,
              desc,
              dateTime,
              balance,
              amount,
            ),
            crossFadeState:
            isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel(
      Color color,
      String method,
      String? bankName,
      String? chequeNum,
      String? chequeDate,
      bool chequeCleared,
      String? chequeClearedDate,
      String? refNum,
      String? desc,
      String dateTime,
      double? balance,
      double amount,
      ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 15, color: color),
                const SizedBox(width: 8),
                Text(
                  'Payment Details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  'ID #${payment['id']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: date + method
                Row(
                  children: [
                    Expanded(
                      child: _detailTile(
                        icon: Icons.access_time_outlined,
                        label: 'Payment Date',
                        value: dateTime,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _detailTile(
                        icon: Icons.category_outlined,
                        label: 'Payment Method',
                        value: _methodLabel(method),
                        valueColor: color,
                        color: color,
                      ),
                    ),
                  ],
                ),

                // Bank info (bank / cheque methods)
                if (bankName != null && bankName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _detailTile(
                    icon: Icons.account_balance_outlined,
                    label: 'Bank',
                    value: bankName,
                    color: color,
                  ),
                ],

                // Cheque-specific row
                if (chequeNum != null && chequeNum.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _detailTile(
                          icon: Icons.receipt_long_outlined,
                          label: 'Cheque Number',
                          value: chequeNum,
                          color: color,
                        ),
                      ),
                      if (chequeDate != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _detailTile(
                            icon: Icons.event_outlined,
                            label: 'Cheque Date',
                            value: chequeDate,
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Cheque cleared status
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: chequeCleared
                          ? Colors.green.withOpacity(0.1)
                          : const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: chequeCleared
                            ? Colors.green.withOpacity(0.3)
                            : const Color(0xFFF59E0B).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          chequeCleared ? Icons.check_circle_outline : Icons.pending_outlined,
                          size: 16,
                          color: chequeCleared ? Colors.green : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cheque Status',
                                style: TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                              ),
                              Text(
                                chequeCleared
                                    ? 'Cleared${chequeClearedDate != null ? ' on $chequeClearedDate' : ''}'
                                    : 'Pending (awaiting clearing)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: chequeCleared ? Colors.green : const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!chequeCleared)
                          TextButton(
                            onPressed: onMarkCleared,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              backgroundColor: const Color(0xFFF59E0B).withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Mark Cleared',
                              style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Reference number
                if (refNum != null && refNum.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _detailTile(
                    icon: Icons.tag_outlined,
                    label: 'Reference Number',
                    value: refNum,
                    valueColor: const Color(0xFF7C3AED),
                    color: color,
                  ),
                ],

                // Description
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _detailTile(
                    icon: Icons.notes_outlined,
                    label: 'Description',
                    value: desc,
                    color: color,
                  ),
                ],

                // Amount + balance row
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _amountCell(
                          label: 'Amount Received',
                          value: 'Rs ${cf.format(amount)}',
                          color: const Color(0xFF10B981),
                          bold: true,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: const Color(0xFFE5E5EA),
                      ),
                      Expanded(
                        child: _amountCell(
                          label: 'Running Balance',
                          value: balance != null ? 'Rs ${cf.format(balance)}' : '—',
                          color: (balance ?? 0) > 0
                              ? const Color(0xFF10B981)
                              : (balance ?? 0) < 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF8E8E93),
                          bold: true,
                        ),
                      ),
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

  String _methodLabel(String method) {
    const labels = {
      'cash': 'Cash Payment',
      'bank': 'Bank Transfer',
      'cheque': 'Cheque Payment',
      'card': 'Card Payment',
      'online': 'Online Payment',
    };
    return labels[method] ?? method;
  }

  Widget _detailTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color.withOpacity(0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountCell({
    required String label,
    required String value,
    required Color color,
    bool bold = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF8E8E93),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// Delete Confirmation Dialog
class _DeleteDialog extends StatelessWidget {
  final Map<String, dynamic> payment;
  final DateFormat df;
  final NumberFormat cf;

  const _DeleteDialog({
    required this.payment,
    required this.df,
    required this.cf,
  });

  @override
  Widget build(BuildContext context) {
    double amount = 0;
    if (payment['debit'] != null) {
      amount = double.tryParse(payment['debit'].toString()) ?? 0;
    } else if (payment['amount'] != null) {
      amount = double.tryParse(payment['amount'].toString()) ?? 0;
    }
    final method = payment['payment_method'] ?? 'payment';
    final bank = payment['bank_name'];
    final date = payment['date'] != null
        ? df.format(DateTime.parse(payment['date']))
        : payment['transaction_date'] != null
        ? df.format(DateTime.parse(payment['transaction_date']))
        : 'Unknown date';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Delete Payment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This will reverse the ledger entry. This cannot be undone.',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: Colors.red, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rs ${cf.format(amount)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$method${bank != null ? ' • $bank' : ''} • $date',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Delete Payment'),
        ),
      ],
    );
  }
}