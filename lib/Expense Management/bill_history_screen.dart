// lib/screens/expenses/bill_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';

class BillHistoryScreen extends StatefulWidget {
  const BillHistoryScreen({super.key});

  @override
  State<BillHistoryScreen> createState() => _BillHistoryScreenState();
}

class _BillHistoryScreenState extends State<BillHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<BillPayment> _bills = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, electricity, gas, etc.
  DateTimeRange? _selectedDateRange;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final _df = DateFormat('MMM dd, yyyy');
  final _tf = DateFormat('hh:mm a');

  static const _primaryColor = Color(0xFF6366F1);
  static const _billColors = {
    'electricity': Color(0xFFF59E0B),
    'gas': Color(0xFFEF4444),
    'telephone': Color(0xFF3B82F6),
    'water': Color(0xFF10B981),
    'internet': Color(0xFF8B5CF6),
    'tv': Color(0xFFEC4899),
    'other': Color(0xFF6B7280),
  };

  static const _billIcons = {
    'electricity': Icons.bolt,
    'gas': Icons.local_fire_department,
    'telephone': Icons.phone,
    'water': Icons.water_drop,
    'internet': Icons.wifi,
    'tv': Icons.tv,
    'other': Icons.receipt,
  };

  static const _billNames = {
    'electricity': 'Electricity Bill',
    'gas': 'Gas Bill',
    'telephone': 'Telephone Bill',
    'water': 'Water Bill',
    'internet': 'Internet Bill',
    'tv': 'TV Cable Bill',
    'other': 'Other Bill',
  };

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadBillHistory();
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

  Future<void> _loadBillHistory() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/expense-sessions/bills');
      final res = await http.get(url, headers: _headers);
      final data = json.decode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        final List<dynamic> billsJson = data['data'] ?? [];
        setState(() {
          _bills = billsJson.map((j) => BillPayment.fromJson(j)).toList();
          _error = null;
        });
        _animCtrl.forward(from: 0);
      } else {
        setState(() => _error = data['message'] ?? 'Failed to load bills');
      }
    } catch (e) {
      print(e);
      setState(() => _error = 'Connection error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<BillPayment> get _filteredBills {
    var filtered = _bills.where((bill) {
      // Filter by type
      if (_selectedFilter != 'all' && bill.billType != _selectedFilter) {
        return false;
      }

      // Filter by date range
      if (_selectedDateRange != null) {
        final billDate = bill.paymentDate;
        if (billDate.isBefore(_selectedDateRange!.start) ||
            billDate.isAfter(_selectedDateRange!.end)) {
          return false;
        }
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return bill.billName.toLowerCase().contains(query) ||
            (bill.billNumber?.toLowerCase().contains(query) ?? false) ||
            (bill.consumerNumber?.toLowerCase().contains(query) ?? false) ||
            bill.description.toLowerCase().contains(query);
      }

      return true;
    }).toList();

    // Sort by date (newest first)
    filtered.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return filtered;
  }

  double get _totalAmount =>
      _filteredBills.fold(0, (sum, bill) => sum + bill.amount);

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedFilter = 'all';
      _selectedDateRange = null;
    });
  }

  Future<void> _viewBillImage(String? base64Image) async {
    if (base64Image == null) return;

    try {
      final bytes = base64Decode(base64Image);
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.image, color: _primaryColor),
                    const SizedBox(width: 8),
                    const Text('Bill Image',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load image'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Bill History',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1C1E),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Color(0xFF8E8E93)),
            onPressed: _loadBillHistory,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _error != null
          ? _buildError()
          : FadeTransition(opacity: _fadeAnim, child: _buildBody()),
    );
  }

  Widget _buildLoading() => const Center(
    child: CircularProgressIndicator(color: _primaryColor),
  );

  Widget _buildError() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _loadBillHistory, child: const Text('Retry')),
      ],
    ),
  );

  Widget _buildBody() {
    return Column(
      children: [
        _buildFilterBar(),
        _buildSummaryCard(),
        Expanded(
          child: _filteredBills.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredBills.length,
            itemBuilder: (ctx, i) => _buildBillCard(_filteredBills[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Search field
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search bills...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => setState(() => _searchQuery = ''),
              )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF5F5F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          // Filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedFilter == 'all',
                  onSelected: (_) => setState(() => _selectedFilter = 'all'),
                  backgroundColor: const Color(0xFFF5F5F7),
                  selectedColor: _primaryColor.withOpacity(0.2),
                  checkmarkColor: _primaryColor,
                ),
                const SizedBox(width: 8),
                ..._billNames.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(entry.value),
                      selected: _selectedFilter == entry.key,
                      onSelected: (_) => setState(() => _selectedFilter = entry.key),
                      backgroundColor: const Color(0xFFF5F5F7),
                      selectedColor: (_billColors[entry.key] ?? _primaryColor).withOpacity(0.2),
                      avatar: Icon(
                        _billIcons[entry.key],
                        size: 16,
                        color: _selectedFilter == entry.key
                            ? _billColors[entry.key]
                            : null,
                      ),
                    ),
                  );
                }),
                // Date range filter
                ActionChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: _selectedDateRange != null ? _primaryColor : null),
                      const SizedBox(width: 4),
                      Text(
                        _selectedDateRange != null
                            ? '${_df.format(_selectedDateRange!.start)} - ${_df.format(_selectedDateRange!.end)}'
                            : 'Select date',
                        style: TextStyle(
                          fontSize: 12,
                          color: _selectedDateRange != null ? _primaryColor : null,
                        ),
                      ),
                    ],
                  ),
                  onPressed: _selectDateRange,
                  backgroundColor: const Color(0xFFF5F5F7),
                ),
                if (_selectedFilter != 'all' || _selectedDateRange != null || _searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ActionChip(
                      label: const Text('Clear all'),
                      onPressed: _clearFilters,
                      backgroundColor: Colors.red.withOpacity(0.1),
                      labelStyle: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Bills',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_filteredBills.length} bills',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rs ${_totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_df.format(_selectedDateRange!.start)} - ${_df.format(_selectedDateRange!.end)}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.receipt_long_outlined, size: 48, color: _primaryColor),
        ),
        const SizedBox(height: 16),
        const Text(
          'No bills found',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _searchQuery.isNotEmpty || _selectedFilter != 'all' || _selectedDateRange != null
              ? 'Try adjusting your filters'
              : 'No bill payments recorded yet',
          style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
        ),
        if (_searchQuery.isNotEmpty || _selectedFilter != 'all' || _selectedDateRange != null)
          TextButton(onPressed: _clearFilters, child: const Text('Clear filters')),
      ],
    ),
  );

  Widget _buildBillCard(BillPayment bill) {
    final color = _billColors[bill.billType] ?? _primaryColor;
    final icon = _billIcons[bill.billType] ?? Icons.receipt;
    final methodColor = _getMethodColor(bill.paymentMethod);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: InkWell(
        onTap: () => _showBillDetails(bill),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with bill type and amount
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.billName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: methodColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                bill.paymentMethod.toUpperCase(),
                                style: TextStyle(fontSize: 9, color: methodColor),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _df.format(bill.paymentDate),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Rs ${bill.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bill details
              if (bill.billNumber != null || bill.consumerNumber != null) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (bill.billNumber != null)
                      _detailChip(Icons.receipt, 'Bill #${bill.billNumber}'),
                    if (bill.consumerNumber != null)
                      _detailChip(Icons.person, 'Consumer #${bill.consumerNumber}'),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Description
              if (bill.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    bill.description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Reference and bank info
              Row(
                children: [
                  if (bill.referenceNumber != null) ...[
                    Icon(Icons.numbers, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      'Ref: ${bill.referenceNumber}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                    ),
                  ],
                  if (bill.bankName != null && bill.referenceNumber != null)
                    const SizedBox(width: 8),
                  if (bill.bankName != null) ...[
                    Icon(Icons.account_balance, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      bill.bankName!,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                    ),
                  ],
                  const Spacer(),
                  if (bill.hasImage)
                    IconButton(
                      icon: const Icon(Icons.image_outlined, size: 18),
                      onPressed: () => _viewBillImage(bill.billImage),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: _primaryColor,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF8E8E93)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  void _showBillDetails(BillPayment bill) {
    final color = _billColors[bill.billType] ?? _primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_billIcons[bill.billType], size: 28, color: color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.billName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _df.format(bill.paymentDate),
                          style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Rs ${bill.amount.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    _detailRow('Payment Method', bill.paymentMethod.toUpperCase()),
                    if (bill.bankName != null) _detailRow('Bank', bill.bankName!),
                    if (bill.chequeNumber != null) _detailRow('Cheque Number', bill.chequeNumber!),
                    if (bill.referenceNumber != null)
                      _detailRow('Reference Number', bill.referenceNumber!),
                    if (bill.billNumber != null) _detailRow('Bill Number', bill.billNumber!),
                    if (bill.consumerNumber != null)
                      _detailRow('Consumer Number', bill.consumerNumber!),
                    if (bill.description.isNotEmpty) _detailRow('Description', bill.description),
                    if (bill.billImage != null) ...[
                      const SizedBox(height: 16),
                      const Text('Bill Image', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _viewBillImage(bill.billImage),
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FutureBuilder<Uint8List>(
                              future: Future.value(base64Decode(bill.billImage!)),
                              builder: (ctx, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(snapshot.data!, fit: BoxFit.contain);
                                }
                                return const Center(child: Icon(Icons.image, size: 48));
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'cash':
        return const Color(0xFF10B981);
      case 'bank':
        return const Color(0xFF3B82F6);
      case 'cheque':
        return const Color(0xFFF59E0B);
      case 'slip':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF8E8E93);
    }
  }
}

// Bill Payment Model
class BillPayment {
  final int id;
  final String billType;
  final String billName;
  final String? billNumber;
  final String? consumerNumber;
  final String description;
  final double amount;
  final String paymentMethod;
  final String? bankName;
  final String? chequeNumber;
  final String? referenceNumber;
  final DateTime paymentDate;
  final String? billImage;

  BillPayment({
    required this.id,
    required this.billType,
    required this.billName,
    this.billNumber,
    this.consumerNumber,
    required this.description,
    required this.amount,
    required this.paymentMethod,
    this.bankName,
    this.chequeNumber,
    this.referenceNumber,
    required this.paymentDate,
    this.billImage,
  });

  bool get hasImage => billImage != null && billImage!.isNotEmpty;

  factory BillPayment.fromJson(Map<String, dynamic> j) => BillPayment(
    id: j['id'],
    billType: j['bill_type'] ?? 'other',
    billName: j['bill_name'] ?? 'Bill Payment',
    billNumber: j['bill_number'],
    consumerNumber: j['consumer_number'],
    description: j['description'] ?? '',
    amount: double.tryParse(j['amount'].toString()) ?? 0,
    paymentMethod: j['payment_method'] ?? 'cash',
    bankName: j['bank_name'],
    chequeNumber: j['cheque_number'],
    referenceNumber: j['reference_number'],
    paymentDate: DateTime.tryParse(j['entry_time'] ?? '') ?? DateTime.now(),
    billImage: j['bill_image'],
  );
}