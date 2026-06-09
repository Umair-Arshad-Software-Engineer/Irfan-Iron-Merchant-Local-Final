// lib/screens/simple_cashbook/simple_cashbook_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../Banks/banknames.dart';
import '../Customers/customer_invoice_payment_screen.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';
import '../providers/lanprovider.dart';

class SimpleCashbookScreen extends StatefulWidget {
  const SimpleCashbookScreen({super.key});

  @override
  State<SimpleCashbookScreen> createState() => _SimpleCashbookScreenState();
}

class _SimpleCashbookScreenState extends State<SimpleCashbookScreen> {
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
    _loadSimpleCashbook();
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
    _loadSimpleCashbook();
  }

  void _goToNextDay() {
    if (_isToday) return;
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _loadSimpleCashbook();
  }

  Future<void> _pickDate() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
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
      _loadSimpleCashbook();
    }
  }

  Future<void> _loadSimpleCashbook() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final dateStr = _selectedDate.toIso8601String().split('T').first;
      final params = <String, String>{
        'from_date': dateStr,
        'to_date': dateStr,
        'limit': '200',
        'sort_order': 'asc',
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/simple-cashbook')
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

  List<Map<String, dynamic>> _getMethods(LanguageProvider lp) => [
    {'value': 'cash', 'label': lp.isEnglish ? 'Cash' : 'نقد', 'icon': Icons.payments_outlined, 'color': const Color(0xFF10B981)},
    {'value': 'bank', 'label': lp.isEnglish ? 'Bank' : 'بینک', 'icon': Icons.account_balance_outlined, 'color': const Color(0xFF3B82F6)},
    {'value': 'cheque', 'label': lp.isEnglish ? 'Cheque' : 'چیک', 'icon': Icons.receipt_long_outlined, 'color': const Color(0xFFF59E0B)},
    {'value': 'slip', 'label': lp.isEnglish ? 'Slip' : 'سلیپ', 'icon': Icons.receipt_outlined, 'color': const Color(0xFF8B5CF6)},
  ];

  Map<String, String> _getSourceBadgeLabels(LanguageProvider lp) => {
    'customer_payment': lp.isEnglish ? 'Customer' : 'کسٹمر',
    'supplier_payment': lp.isEnglish ? 'Supplier' : 'سپلائر',
    'manual': lp.isEnglish ? 'Manual' : 'دستی',
    'opening_balance': lp.isEnglish ? 'Opening' : 'ابتدائی',
  };

  Future<void> _showAddEntryDialog() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final methods = _getMethods(lp);

    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    String entryType = 'cash_in';
    String paymentMethod = 'cash';
    bool isCustomerPayment = false;
    Customer? selectedCustomer;

    Map<String, dynamic>? selectedBank;
    final chequeNumberCtrl = TextEditingController();
    DateTime? chequeDate;
    Map<String, dynamic>? selectedChequeBank;
    final slipNumberCtrl = TextEditingController();
    DateTime? slipDate;
    Map<String, dynamic>? selectedSlipBank;
    DateTime entryDate = _selectedDate;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(lp.isEnglish ? 'Add Manual Entry' : 'دستی اندراج شامل کریں'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCustomerPayment ? const Color(0xFF7C3AED).withOpacity(0.05) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isCustomerPayment ? const Color(0xFF7C3AED).withOpacity(0.3) : Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isCustomerPayment,
                        onChanged: (value) {
                          setS(() {
                            isCustomerPayment = value ?? false;
                            if (!isCustomerPayment) selectedCustomer = null;
                          });
                        },
                        activeColor: const Color(0xFF7C3AED),
                      ),
                      Expanded(
                        child: Text(lp.isEnglish ? 'This is a customer payment' : 'یہ کسٹمر کی ادائیگی ہے',
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (isCustomerPayment) ...[
                  GestureDetector(
                    onTap: () async {
                      final customer = await _showCustomerSelectionDialog(ctx, lp);
                      if (customer != null) setS(() => selectedCustomer = customer);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: selectedCustomer != null ? const Color(0xFF7C3AED).withOpacity(0.05) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selectedCustomer != null ? const Color(0xFF7C3AED).withOpacity(0.3) : Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline,
                              color: selectedCustomer != null ? const Color(0xFF7C3AED) : Colors.grey[500]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedCustomer?.name ?? (lp.isEnglish ? 'Select Customer' : 'کسٹمر منتخب کریں'),
                              style: TextStyle(
                                fontSize: 14,
                                color: selectedCustomer != null ? const Color(0xFF2D3142) : Colors.grey[600],
                                fontFamily: lp.fontFamily,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                  if (selectedCustomer != null) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final result = await _navigateToPaymentScreen(selectedCustomer!, lp);
                        if (result == true && mounted) _loadSimpleCashbook();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.payment, size: 20),
                          const SizedBox(width: 8),
                          Text(lp.isEnglish ? 'Receive Payment from Customer' : 'کسٹمر سے ادائیگی وصول کریں'),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(lp.isEnglish ? 'Or add manual entry below' : 'یا نیچے دستی اندراج شامل کریں',
                            style: const TextStyle(fontSize: 11, color: Colors.orange)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => entryType = 'cash_in'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: entryType == 'cash_in' ? const Color(0xFF10B981).withOpacity(0.1) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: entryType == 'cash_in' ? const Color(0xFF10B981) : Colors.grey.shade300, width: entryType == 'cash_in' ? 2 : 1),
                          ),
                          child: Column(children: [
                            Icon(Icons.arrow_downward_rounded,
                                color: entryType == 'cash_in' ? const Color(0xFF10B981) : Colors.grey, size: 22),
                            const SizedBox(height: 4),
                            Text(lp.isEnglish ? 'Cash In' : 'نقدی اندرون',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                                    color: entryType == 'cash_in' ? const Color(0xFF10B981) : Colors.grey)),
                          ]),
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
                            color: entryType == 'cash_out' ? Colors.red.withOpacity(0.1) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: entryType == 'cash_out' ? Colors.red : Colors.grey.shade300, width: entryType == 'cash_out' ? 2 : 1),
                          ),
                          child: Column(children: [
                            Icon(Icons.arrow_upward_rounded,
                                color: entryType == 'cash_out' ? Colors.red : Colors.grey, size: 22),
                            const SizedBox(height: 4),
                            Text(lp.isEnglish ? 'Cash Out' : 'نقدی باہر',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                                    color: entryType == 'cash_out' ? Colors.red : Colors.grey)),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Payment Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: methods.map((m) {
                    return _methodChip(
                      label: m['label'] as String,
                      icon: m['icon'] as IconData,
                      color: m['color'] as Color,
                      isSelected: paymentMethod == m['value'],
                      onTap: () => setS(() => paymentMethod = m['value'] as String),
                      lp: lp,
                    );
                  }).toList()),
                ),
                const SizedBox(height: 16),

                if (paymentMethod == 'bank') ...[
                  _bankSelectorTile(
                    label: lp.isEnglish ? 'Bank (Receiving) *' : 'بینک (وصول کرنے والا) *',
                    selectedBank: selectedBank,
                    accentColor: const Color(0xFF3B82F6),
                    onTap: () async {
                      final result = await _pickBank(ctx, lp);
                      if (result != null) setS(() => selectedBank = result);
                    },
                    lp: lp,
                  ),
                ] else if (paymentMethod == 'cheque') ...[
                  _bankSelectorTile(
                    label: lp.isEnglish ? 'Bank *' : 'بینک *',
                    selectedBank: selectedChequeBank,
                    accentColor: const Color(0xFFF59E0B),
                    onTap: () async {
                      final result = await _pickBank(ctx, lp);
                      if (result != null) setS(() => selectedChequeBank = result);
                    },
                    lp: lp,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: chequeNumberCtrl,
                    style: TextStyle(fontFamily: lp.fontFamily),
                    decoration: InputDecoration(
                      labelText: lp.isEnglish ? 'Cheque Number *' : 'چیک نمبر *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: chequeDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 180)),
                      );
                      if (picked != null) setS(() => chequeDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.event, size: 18, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 12),
                        Text(chequeDate != null
                            ? '${lp.isEnglish ? 'Cheque Date' : 'چیک کی تاریخ'}: ${_df.format(chequeDate!)}'
                            : (lp.isEnglish ? 'Select Cheque Date *' : 'چیک کی تاریخ منتخب کریں *')),
                      ]),
                    ),
                  ),
                ] else if (paymentMethod == 'slip') ...[
                  _bankSelectorTile(
                    label: lp.isEnglish ? 'Bank *' : 'بینک *',
                    selectedBank: selectedSlipBank,
                    accentColor: const Color(0xFF8B5CF6),
                    onTap: () async {
                      final result = await _pickBank(ctx, lp);
                      if (result != null) setS(() => selectedSlipBank = result);
                    },
                    lp: lp,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: slipNumberCtrl,
                    style: TextStyle(fontFamily: lp.fontFamily),
                    decoration: InputDecoration(
                      labelText: lp.isEnglish ? 'Slip Number *' : 'سلیپ نمبر *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: slipDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) setS(() => slipDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.event, size: 18, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 12),
                        Text(slipDate != null
                            ? '${lp.isEnglish ? 'Slip Date' : 'سلیپ کی تاریخ'}: ${_df.format(slipDate!)}'
                            : (lp.isEnglish ? 'Select Slip Date *' : 'سلیپ کی تاریخ منتخب کریں *')),
                      ]),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    labelText: lp.isEnglish ? 'Amount *' : 'رقم *',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  style: TextStyle(fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    labelText: lp.isEnglish ? 'Description *' : 'تفصیل *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),

                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: entryDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF10B981))),
                        child: child!,
                      ),
                    );
                    if (picked != null) setS(() => entryDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${lp.isEnglish ? 'Entry for' : 'اندراج برائے'}: ${_df.format(entryDate)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF10B981)),
                        ),
                      ),
                      const Icon(Icons.edit_calendar, size: 14, color: Color(0xFF10B981)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lp.isEnglish ? 'Cancel' : 'منسوخ کریں')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(lp.isEnglish ? 'Enter valid amount' : 'درست رقم درج کریں'),
                      backgroundColor: Colors.red));
                  return;
                }
                if (descCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(lp.isEnglish ? 'Description required' : 'تفصیل ضروری ہے'),
                      backgroundColor: Colors.red));
                  return;
                }
                if (paymentMethod == 'bank' && selectedBank == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(lp.isEnglish ? 'Please select a bank' : 'براہ کرم بینک منتخب کریں'),
                      backgroundColor: Colors.red));
                  return;
                }
                if (paymentMethod == 'cheque' && (selectedChequeBank == null || chequeNumberCtrl.text.isEmpty || chequeDate == null)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(lp.isEnglish ? 'Please fill all cheque details' : 'براہ کرم تمام چیک کی تفصیلات بھریں'),
                      backgroundColor: Colors.red));
                  return;
                }
                if (paymentMethod == 'slip' && (selectedSlipBank == null || slipNumberCtrl.text.isEmpty || slipDate == null)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(lp.isEnglish ? 'Please fill all slip details' : 'براہ کرم تمام سلیپ کی تفصیلات بھریں'),
                      backgroundColor: Colors.red));
                  return;
                }

                Navigator.pop(ctx, true);
                await _submitManualEntry(
                  entryType: entryType,
                  amount: amount,
                  description: descCtrl.text.trim(),
                  paymentMethod: paymentMethod,
                  entryDate: entryDate,
                  bankId: selectedBank?['id'] ?? selectedChequeBank?['id'] ?? selectedSlipBank?['id'],
                  bankName: selectedBank?['name'] ?? selectedChequeBank?['name'] ?? selectedSlipBank?['name'],
                  chequeNumber: chequeNumberCtrl.text.trim().isEmpty ? null : chequeNumberCtrl.text.trim(),
                  chequeDate: chequeDate,
                  slipNumber: slipNumberCtrl.text.trim().isEmpty ? null : slipNumberCtrl.text.trim(),
                  slipDate: slipDate,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: entryType == 'cash_in' ? const Color(0xFF10B981) : Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(lp.isEnglish ? 'Save Entry' : 'اندراج محفوظ کریں'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required LanguageProvider lp,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: isSelected ? color : Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey.shade700,
                  fontFamily: lp.fontFamily)),
        ]),
      ),
    );
  }

  Widget _bankSelectorTile({
    required String label,
    required Map<String, dynamic>? selectedBank,
    required Color accentColor,
    required VoidCallback onTap,
    required LanguageProvider lp,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selectedBank != null ? accentColor.withOpacity(0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selectedBank != null ? accentColor.withOpacity(0.4) : Colors.grey.shade300),
        ),
        child: Row(children: [
          Icon(Icons.account_balance_outlined, size: 20,
              color: selectedBank != null ? accentColor : Colors.grey[400]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              selectedBank?['name'] ?? label,
              style: TextStyle(fontSize: 14,
                  color: selectedBank != null ? const Color(0xFF2D3142) : Colors.grey[500],
                  fontFamily: lp.fontFamily),
            ),
          ),
          Icon(selectedBank != null ? Icons.check_circle_rounded : Icons.keyboard_arrow_down,
              size: 20, color: selectedBank != null ? accentColor : Colors.grey[400]),
        ]),
      ),
    );
  }

  Future<Map<String, dynamic>?> _pickBank(BuildContext context, LanguageProvider lp) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SimpleCashbookBankSheet(languageProvider: lp),
    );
    return result;
  }

  Future<Customer?> _showCustomerSelectionDialog(BuildContext context, LanguageProvider lp) async {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

    if (customerProvider.customers.isEmpty) {
      await customerProvider.fetchCustomers(limit: 100);
    }

    return showDialog<Customer>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          width: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(lp.isEnglish ? 'Select Customer' : 'کسٹمر منتخب کریں',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                style: TextStyle(fontFamily: lp.fontFamily),
                onChanged: (value) {},
                decoration: InputDecoration(
                  hintText: lp.isEnglish ? 'Search customers...' : 'کسٹمرز تلاش کریں...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Consumer<CustomerProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.customers.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (provider.customers.isEmpty) {
                      return Center(child: Text(lp.isEnglish ? 'No customers found' : 'کوئی کسٹمر نہیں ملا'));
                    }
                    return ListView.builder(
                      itemCount: provider.customers.length,
                      itemBuilder: (context, index) {
                        final customer = provider.customers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF7C3AED).withOpacity(0.1),
                            child: Text(customer.name[0].toUpperCase(),
                                style: const TextStyle(color: Color(0xFF7C3AED))),
                          ),
                          title: Text(customer.name, style: TextStyle(fontFamily: lp.fontFamily)),
                          subtitle: Text(
                            '${lp.isEnglish ? 'Balance' : 'بیلنس'}: ${customer.formattedBalance}',
                            style: TextStyle(color: customer.balance > 0 ? Colors.red : Colors.green,
                                fontFamily: lp.fontFamily),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => Navigator.pop(ctx, customer),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _navigateToPaymentScreen(Customer customer, LanguageProvider lp) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerInvoicePaymentScreen(
          customer: customer,
          fromSimpleCashbook: true,
          languageProvider: lp,
        ),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lp.isEnglish ? 'Payment recorded successfully' : 'ادائیگی کامیابی سے ریکارڈ ہوگئی'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      return true;
    }
    return false;
  }

  Future<void> _submitManualEntry({
    required String entryType,
    required double amount,
    required String description,
    required String paymentMethod,
    DateTime? entryDate,
    int? bankId,
    String? bankName,
    String? chequeNumber,
    DateTime? chequeDate,
    String? slipNumber,
    DateTime? slipDate,
  }) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    try {
      final dateToUse = entryDate ?? _selectedDate;
      final body = <String, dynamic>{
        'entry_type': entryType,
        'amount': amount,
        'description': description,
        'entry_date': dateToUse.toIso8601String().split('T').first,
        'payment_method': paymentMethod,
        if (bankId != null) 'bank_id': bankId,
        if (bankName != null) 'bank_name': bankName,
        if (chequeNumber != null) 'cheque_number': chequeNumber,
        if (chequeDate != null) 'cheque_date': chequeDate.toIso8601String(),
        if (slipNumber != null) 'slip_number': slipNumber,
        if (slipDate != null) 'slip_date': slipDate.toIso8601String(),
      };

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/simple-cashbook/manual'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
        body: jsonEncode(body),
      );
      final json = jsonDecode(res.body);
      if (json['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(json['message'] ?? (lp.isEnglish ? 'Entry added' : 'اندراج شامل ہوگیا')),
            backgroundColor: Colors.green));
        _loadSimpleCashbook();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(json['message'] ?? (lp.isEnglish ? 'Failed' : 'ناکام')),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${lp.isEnglish ? 'Error' : 'خرابی'}: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteEntry(int id) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lp.isEnglish ? 'Delete Entry' : 'اندراج حذف کریں'),
        content: Text(lp.isEnglish ? 'Delete this manual entry?' : 'یہ دستی اندراج حذف کریں؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lp.isEnglish ? 'Cancel' : 'منسوخ کریں')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(lp.isEnglish ? 'Delete' : 'حذف کریں'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/simple-cashbook/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
      );
      final json = jsonDecode(res.body);
      if (json['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lp.isEnglish ? 'Entry deleted' : 'اندراج حذف ہوگیا'),
            backgroundColor: Colors.green));
        _loadSimpleCashbook();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${lp.isEnglish ? 'Error' : 'خرابی'}: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(languageProvider.isEnglish ? 'Simple Cashbook' : 'سادہ کیش بک',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
            actions: [
              IconButton(
                icon: const Icon(Icons.today, color: Color(0xFF10B981)),
                tooltip: languageProvider.isEnglish ? 'Go to today' : 'آج کی تاریخ پر جائیں',
                onPressed: _isToday ? null : () {
                  setState(() => _selectedDate = DateTime.now());
                  _loadSimpleCashbook();
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF7C3AED)),
                onPressed: _loadSimpleCashbook,
                tooltip: languageProvider.isEnglish ? 'Refresh' : 'تازہ کریں',
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddEntryDialog,
            backgroundColor: const Color(0xFF10B981),
            icon: const Icon(Icons.add),
            label: Text(languageProvider.isEnglish ? 'Add Entry' : 'اندراج شامل کریں'),
          ),
          body: Column(
            children: [
              _buildDayNavigator(languageProvider),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        TextButton(onPressed: _loadSimpleCashbook, child: Text(languageProvider.isEnglish ? 'Retry' : 'دوبارہ کوشش کریں')),
                      ],
                    ),
                  ),
                )
              else ...[
                  _buildDaySummaryCards(languageProvider),
                  Expanded(child: _buildEntriesList(languageProvider)),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayNavigator(LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
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
                    _isToday ? (lp.isEnglish ? 'Today' : 'آج') : _dfFull.format(_selectedDate),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                    textAlign: TextAlign.center,
                  ),
                  if (_isToday)
                    Text(
                      _dfFull.format(_selectedDate),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: lp.fontFamily),
                      textAlign: TextAlign.center,
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 11, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(lp.isEnglish ? 'Tap to pick date' : 'تاریخ منتخب کرنے کے لیے تھپتھپائیں',
                          style: TextStyle(fontSize: 10, color: Colors.grey[400], fontFamily: lp.fontFamily)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, size: 28, color: _isToday ? Colors.grey[300] : const Color(0xFF2D3142)),
            onPressed: _isToday ? null : _goToNextDay,
          ),
        ],
      ),
    );
  }

  Widget _buildDaySummaryCards(LanguageProvider lp) {
    final currentBalance = double.tryParse(_summary['current_balance']?.toString() ?? '0') ?? 0.0;
    final dayIn = double.tryParse(_summary['total_cash_in']?.toString() ?? '0') ?? 0.0;
    final dayOut = double.tryParse(_summary['total_cash_out']?.toString() ?? '0') ?? 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lp.isEnglish ? 'Cash Balance' : 'نقدی بیلنس',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(_nf.format(currentBalance),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(lp.isEnglish ? 'As of end of day' : 'دن کے اختتام پر',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                    Text(_df.format(_selectedDate), style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildMiniCard(lp.isEnglish ? "Today's In" : "آج کی اندرونی", dayIn,
                  Icons.arrow_downward_rounded, const Color(0xFF10B981), lp)),
              const SizedBox(width: 10),
              Expanded(child: _buildMiniCard(lp.isEnglish ? "Today's Out" : "آج کی باہری", dayOut,
                  Icons.arrow_upward_rounded, Colors.red, lp)),
              const SizedBox(width: 10),
              Expanded(child: _buildMiniCard(lp.isEnglish ? 'Net' : 'خالص', (dayIn - dayOut).abs(),
                  dayIn >= dayOut ? Icons.trending_up : Icons.trending_down,
                  dayIn >= dayOut ? const Color(0xFF10B981) : Colors.red, lp,
                  prefix: dayIn >= dayOut ? '+' : '-')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard(String label, double amount, IconData icon, Color color, LanguageProvider lp, {String prefix = ''}) {
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
              Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontFamily: lp.fontFamily)),
            ],
          ),
          const SizedBox(height: 4),
          Text('$prefix${_nf.format(amount)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color, fontFamily: lp.fontFamily),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEntriesList(LanguageProvider lp) {
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('${lp.isEnglish ? 'No entries for' : 'کے لیے کوئی اندراج نہیں'} ${_df.format(_selectedDate)}',
                style: TextStyle(fontSize: 15, color: Colors.grey[500], fontFamily: lp.fontFamily)),
            const SizedBox(height: 6),
            Text(lp.isEnglish ? 'Tap + Add Entry to record cash' : 'نقدی ریکارڈ کرنے کے لیے + Add Entry پر تھپتھپائیں',
                style: TextStyle(fontSize: 12, color: Colors.grey[400], fontFamily: lp.fontFamily)),
          ],
        ),
      );
    }

    final sourceLabels = _getSourceBadgeLabels(lp);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final isCashIn = entry['entry_type'] == 'cash_in';
        final isManual = entry['source_type'] == 'manual';
        final color = isCashIn ? const Color(0xFF10B981) : Colors.red;
        final amount = double.tryParse(entry['amount']?.toString() ?? '0') ?? 0.0;
        final balance = double.tryParse(entry['balance']?.toString() ?? '0') ?? 0.0;
        final sourceType = entry['source_type'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                  child: Icon(isCashIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildSourceBadge(sourceType, sourceLabels, lp),
                          if (isManual) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(lp.isEnglish ? 'Manual' : 'دستی',
                                  style: const TextStyle(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(entry['description'] ?? '',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (entry['reference_number'] != null)
                        Text('# ${entry['reference_number']}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: lp.fontFamily)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${isCashIn ? '+' : '-'}${_nf.format(amount)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color, fontFamily: lp.fontFamily)),
                    const SizedBox(height: 2),
                    Text('${lp.isEnglish ? 'Bal' : 'بیلنس'}: ${_nf.format(balance)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: lp.fontFamily)),
                    if (isManual) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _deleteEntry(entry['id']),
                        child: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
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

  Widget _buildSourceBadge(String sourceType, Map<String, String> labels, LanguageProvider lp) {
    final label = labels[sourceType] ?? (lp.isEnglish ? 'Unknown' : 'نامعلوم');
    final colorMap = {
      'customer_payment': Colors.blue,
      'supplier_payment': Colors.orange,
      'manual': Colors.purple,
      'opening_balance': Colors.teal,
    };
    final color = colorMap[sourceType] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.bold, fontFamily: lp.fontFamily)),
    );
  }
}

class _SimpleCashbookBankSheet extends StatefulWidget {
  final LanguageProvider languageProvider;

  const _SimpleCashbookBankSheet({required this.languageProvider});

  @override
  State<_SimpleCashbookBankSheet> createState() => _SimpleCashbookBankSheetState();
}

class _SimpleCashbookBankSheetState extends State<_SimpleCashbookBankSheet> {
  final _searchCtrl = TextEditingController();
  List<Bank> _filtered = pakistaniBanks;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = pakistaniBanks.where((b) => b.name.toLowerCase().contains(q)).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = widget.languageProvider;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(children: [
        Container(
          width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)),
        ),
        Row(children: [
          Text(lp.isEnglish ? 'Select Bank' : 'بینک منتخب کریں',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          style: TextStyle(fontFamily: lp.fontFamily),
          decoration: InputDecoration(
            hintText: lp.isEnglish ? 'Search banks...' : 'بینکس تلاش کریں...',
            prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            filled: true,
            fillColor: const Color(0xFFF5F5F7),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (ctx, i) {
              final bank = _filtered[i];
              final originalIndex = pakistaniBanks.indexOf(bank);
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(bank.iconPath, width: 40, height: 40, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.account_balance, color: Color(0xFF10B981), size: 20),
                      )),
                ),
                title: Text(bank.name, style: TextStyle(fontFamily: lp.fontFamily)),
                onTap: () => Navigator.pop(context, {'id': originalIndex + 1, 'name': bank.name}),
              );
            },
          ),
        ),
      ]),
    );
  }
}