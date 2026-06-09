// lib/screens/cashbook/cashbook_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';

class CashbookScreen extends StatefulWidget {
  const CashbookScreen({super.key});
  @override
  State<CashbookScreen> createState() => _CashbookScreenState();
}

class _CashbookScreenState extends State<CashbookScreen> {
  List<dynamic> _entries = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  String? _error;

  DateTime _selectedDate = DateTime.now();

  final _df = DateFormat('MMM dd, yyyy');
  final _dfFull = DateFormat('EEEE, MMM dd yyyy');
  final _nf = NumberFormat.currency(symbol: 'Rs ');

  @override
  void initState() {
    super.initState();
    _loadCashbook();
  }

  String? _getToken() =>
      Provider.of<AuthProvider>(context, listen: false).user?.token;

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _goToPreviousDay() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _loadCashbook();
  }

  void _goToNextDay() {
    if (_isToday) return;
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _loadCashbook();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF10B981)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadCashbook();
    }
  }

  Future<void> _loadCashbook() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final dateStr = _selectedDate.toIso8601String().split('T').first;
      final params = <String, String>{
        'from_date': dateStr,
        'to_date': dateStr,
        'limit': '200',
        'sort_order': 'asc',
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/cashbook')
          .replace(queryParameters: params);

      final res = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
      });

      final contentType = res.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        setState(() => _error = 'Server error (${res.statusCode})');
        return;
      }

      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        setState(() {
          _entries = json['data']['entries'] as List;
          _summary = json['data']['summary'] ?? {};
        });
      } else {
        setState(() => _error = json['message']);
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddEntryDialog() async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    String entryType = 'cash_in';
    DateTime entryDate = _selectedDate;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Manual Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: entryDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(primary: Color(0xFF10B981)),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setS(() => entryDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text(
                          _df.format(entryDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Type toggle
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => entryType = 'cash_in'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: entryType == 'cash_in'
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: entryType == 'cash_in'
                                  ? const Color(0xFF10B981)
                                  : Colors.grey.shade300,
                              width: entryType == 'cash_in' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.arrow_downward_rounded,
                                  color: entryType == 'cash_in'
                                      ? const Color(0xFF10B981)
                                      : Colors.grey,
                                  size: 22),
                              const SizedBox(height: 4),
                              Text('Cash In',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: entryType == 'cash_in'
                                        ? const Color(0xFF10B981)
                                        : Colors.grey,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => entryType = 'cash_out'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: entryType == 'cash_out'
                                ? Colors.red.withOpacity(0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: entryType == 'cash_out'
                                  ? Colors.red
                                  : Colors.grey.shade300,
                              width: entryType == 'cash_out' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.arrow_upward_rounded,
                                  color: entryType == 'cash_out'
                                      ? Colors.red
                                      : Colors.grey,
                                  size: 22),
                              const SizedBox(height: 4),
                              Text('Cash Out',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: entryType == 'cash_out'
                                        ? Colors.red
                                        : Colors.grey,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount *',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: InputDecoration(
                    labelText: 'Reference # (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Enter valid amount'),
                      backgroundColor: Colors.red));
                  return;
                }
                if (descCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Description required'),
                      backgroundColor: Colors.red));
                  return;
                }
                Navigator.pop(ctx, true);
                await _submitManualEntry(
                  entryType: entryType,
                  amount: amount,
                  description: descCtrl.text.trim(),
                  referenceNumber: refCtrl.text.trim().isEmpty
                      ? null
                      : refCtrl.text.trim(),
                  entryDate: entryDate,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: entryType == 'cash_in'
                    ? const Color(0xFF10B981)
                    : Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditEntryDialog(Map<String, dynamic> entry) async {
    final amountCtrl = TextEditingController(text: entry['amount'].toString());
    final descCtrl = TextEditingController(text: entry['description'] ?? '');
    final refCtrl = TextEditingController(text: entry['reference_number'] ?? '');
    String entryType = entry['entry_type'];
    DateTime entryDate = DateTime.parse(entry['entry_date']);

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Manual Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: entryDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(primary: Color(0xFF10B981)),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setS(() => entryDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text(
                          _df.format(entryDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Type toggle
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => entryType = 'cash_in'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: entryType == 'cash_in'
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: entryType == 'cash_in'
                                  ? const Color(0xFF10B981)
                                  : Colors.grey.shade300,
                              width: entryType == 'cash_in' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.arrow_downward_rounded,
                                  color: entryType == 'cash_in'
                                      ? const Color(0xFF10B981)
                                      : Colors.grey,
                                  size: 22),
                              const SizedBox(height: 4),
                              Text('Cash In',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: entryType == 'cash_in'
                                        ? const Color(0xFF10B981)
                                        : Colors.grey,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => entryType = 'cash_out'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: entryType == 'cash_out'
                                ? Colors.red.withOpacity(0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: entryType == 'cash_out'
                                  ? Colors.red
                                  : Colors.grey.shade300,
                              width: entryType == 'cash_out' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.arrow_upward_rounded,
                                  color: entryType == 'cash_out'
                                      ? Colors.red
                                      : Colors.grey,
                                  size: 22),
                              const SizedBox(height: 4),
                              Text('Cash Out',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: entryType == 'cash_out'
                                        ? Colors.red
                                        : Colors.grey,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount *',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: InputDecoration(
                    labelText: 'Reference # (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Enter valid amount'),
                      backgroundColor: Colors.red));
                  return;
                }
                if (descCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Description required'),
                      backgroundColor: Colors.red));
                  return;
                }
                Navigator.pop(ctx, true);
                await _editManualEntry(
                  id: entry['id'],
                  entryType: entryType,
                  amount: amount,
                  description: descCtrl.text.trim(),
                  referenceNumber: refCtrl.text.trim().isEmpty
                      ? null
                      : refCtrl.text.trim(),
                  entryDate: entryDate,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: entryType == 'cash_in'
                    ? const Color(0xFF10B981)
                    : Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Update Entry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitManualEntry({
    required String entryType,
    required double amount,
    required String description,
    String? referenceNumber,
    required DateTime entryDate,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/cashbook/manual'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
        body: jsonEncode({
          'entry_type': entryType,
          'amount': amount,
          'description': description,
          'reference_number': referenceNumber,
          'entry_date': entryDate.toIso8601String().split('T').first,
        }),
      );
      final json = jsonDecode(res.body);
      if (json['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(json['message'] ?? 'Entry added'),
          backgroundColor: Colors.green,
        ));
        _loadCashbook();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(json['message'] ?? 'Failed'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _editManualEntry({
    required int id,
    required String entryType,
    required double amount,
    required String description,
    String? referenceNumber,
    required DateTime entryDate,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/cashbook/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
        body: jsonEncode({
          'entry_type': entryType,
          'amount': amount,
          'description': description,
          'reference_number': referenceNumber,
          'entry_date': entryDate.toIso8601String().split('T').first,
        }),
      );
      final json = jsonDecode(res.body);
      if (json['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(json['message'] ?? 'Entry updated'),
          backgroundColor: Colors.green,
        ));
        _loadCashbook();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(json['message'] ?? 'Failed to update'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteEntry(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Delete this manual entry?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/cashbook/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
      );
      final json = jsonDecode(res.body);
      if (json['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Entry deleted'), backgroundColor: Colors.green));
        _loadCashbook();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Cashbook',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142))),
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: Color(0xFF10B981)),
            tooltip: 'Go to today',
            onPressed: _isToday
                ? null
                : () {
              setState(() => _selectedDate = DateTime.now());
              _loadCashbook();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF7C3AED)),
            onPressed: _loadCashbook,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEntryDialog,
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
      body: Column(
        children: [
          _buildDayNavigator(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    TextButton(
                        onPressed: _loadCashbook,
                        child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else ...[
              _buildDaySummaryCards(),
              Expanded(child: _buildEntriesList()),
            ],
        ],
      ),
    );
  }

  Widget _buildDayNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            color: const Color(0xFF2D3142),
            onPressed: _goToPreviousDay,
          ),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Column(
                children: [
                  Text(
                    _isToday ? 'Today' : _dfFull.format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_isToday)
                    Text(
                      _dfFull.format(_selectedDate),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today,
                          size: 11, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text('Tap to pick date',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right,
                size: 28,
                color: _isToday
                    ? Colors.grey[300]
                    : const Color(0xFF2D3142)),
            onPressed: _isToday ? null : _goToNextDay,
          ),
        ],
      ),
    );
  }

  Widget _buildDaySummaryCards() {
    final currentBalance =
        double.tryParse(_summary['current_balance']?.toString() ?? '0') ?? 0.0;
    final dayIn =
        double.tryParse(_summary['total_cash_in']?.toString() ?? '0') ?? 0.0;
    final dayOut =
        double.tryParse(_summary['total_cash_out']?.toString() ?? '0') ?? 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cash on Hand',
                        style:
                        TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      _nf.format(currentBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'As of end of day',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10),
                    ),
                    Text(
                      _df.format(_selectedDate),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMiniCard(
                  label: "Today's In",
                  amount: dayIn,
                  icon: Icons.arrow_downward_rounded,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniCard(
                  label: "Today's Out",
                  amount: dayOut,
                  icon: Icons.arrow_upward_rounded,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniCard(
                  label: 'Net',
                  amount: (dayIn - dayOut).abs(),
                  icon: dayIn >= dayOut
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: dayIn >= dayOut
                      ? const Color(0xFF10B981)
                      : Colors.red,
                  prefix: dayIn >= dayOut ? '+' : '-',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    String prefix = '',
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$prefix${_nf.format(amount)}',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList() {
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No entries for ${_df.format(_selectedDate)}',
                style: TextStyle(fontSize: 15, color: Colors.grey[500])),
            const SizedBox(height: 6),
            Text('Tap + Add Entry to record cash',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final isCashIn = entry['entry_type'] == 'cash_in';
        final isManual = entry['source_type'] == 'manual';
        final color = isCashIn ? const Color(0xFF10B981) : Colors.red;
        final amount = double.tryParse(
            entry['amount']?.toString() ?? '0') ??
            0.0;
        final balance = double.tryParse(
            entry['balance']?.toString() ?? '0') ??
            0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    isCashIn
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildSourceBadge(entry['source_type']),
                          if (isManual) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Manual',
                                  style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entry['description'] ?? '',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entry['reference_number'] != null)
                        Text(
                          '# ${entry['reference_number']}',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isCashIn ? '+' : '-'}${_nf.format(amount)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bal: ${_nf.format(balance)}',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[500]),
                    ),
                    if (isManual) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _showEditEntryDialog(entry),
                            child: const Icon(Icons.edit_outlined,
                                size: 15, color: Colors.blue),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _deleteEntry(entry['id']),
                            child: const Icon(Icons.delete_outline,
                                size: 15, color: Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceBadge(String? sourceType) {
    final map = {
      'customer_payment': ('Customer', Colors.blue),
      'supplier_payment': ('Supplier', Colors.orange),
      'manual': ('Manual', Colors.purple),
      'opening_balance': ('Opening', Colors.teal),
    };
    final info = map[sourceType] ?? ('Unknown', Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: info.$2.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(info.$1,
          style: TextStyle(
              fontSize: 8, color: info.$2, fontWeight: FontWeight.bold)),
    );
  }
}