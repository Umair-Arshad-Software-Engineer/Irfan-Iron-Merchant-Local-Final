import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../models/sale_model.dart';
import '../../providers/sale_provider.dart';
import '../../providers/customer_provider.dart';
import '../components/loading_indicator.dart';
import '../components/error_widget.dart';
import '../Banks/banknames.dart';
import '../providers/lanprovider.dart';

class CustomerInvoicePaymentScreen extends StatefulWidget {
  final Customer customer;
  final bool fromSimpleCashbook;
  final LanguageProvider languageProvider;

  const CustomerInvoicePaymentScreen({
    Key? key,
    required this.customer,
    this.fromSimpleCashbook = false,
    required this.languageProvider,
  }) : super(key: key);

  @override
  State<CustomerInvoicePaymentScreen> createState() => _CustomerInvoicePaymentScreenState();
}

class _CustomerInvoicePaymentScreenState extends State<CustomerInvoicePaymentScreen> {
  List<SaleModel> _sales = [];
  bool _isLoading = true;
  String? _error;
  Set<int> _selectedSaleIds = {};
  bool _selectAll = false;
  String _selectedType = 'all';

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs ');

  List<Map<String, dynamic>> get _filterOptions => [
    {'value': 'all', 'label': widget.languageProvider.isEnglish ? 'All' : 'سب'},
    {'value': 'invoice', 'label': widget.languageProvider.isEnglish ? 'Invoices' : 'انوائسز'},
    {'value': 'pos', 'label': widget.languageProvider.isEnglish ? 'POS Sales' : 'POS فروخت'},
  ];

  List<Map<String, dynamic>> get _methodOptions => [
    {'value': 'cash', 'label': widget.languageProvider.isEnglish ? 'Cash' : 'نقد', 'icon': Icons.payments_outlined, 'color': const Color(0xFF10B981)},
    {'value': 'bank', 'label': widget.languageProvider.isEnglish ? 'Bank' : 'بینک', 'icon': Icons.account_balance_outlined, 'color': const Color(0xFF3B82F6)},
    {'value': 'cheque', 'label': widget.languageProvider.isEnglish ? 'Cheque' : 'چیک', 'icon': Icons.receipt_long_outlined, 'color': const Color(0xFFF59E0B)},
    {'value': 'slip', 'label': widget.languageProvider.isEnglish ? 'Slip' : 'سلیپ', 'icon': Icons.receipt_outlined, 'color': const Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomerSales();
  }

  Future<void> _loadCustomerSales() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);

      await saleProvider.fetchSales(
        customerId: widget.customer.id,
        refresh: true,
      );

      final unpaidSales = saleProvider.sales
          .where((sale) => sale.paymentStatus != 'paid' && sale.outstandingBalance > 0)
          .toList();

      setState(() {
        _sales = unpaidSales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '${widget.languageProvider.isEnglish ? 'Failed to load sales' : 'فروخت لوڈ کرنے میں ناکامی'}: $e';
        _isLoading = false;
      });
    }
  }

  List<SaleModel> get _filteredSales {
    if (_selectedType == 'all') {
      return _sales;
    }
    return _sales.where((sale) => sale.saleType == _selectedType).toList();
  }

  double get _selectedTotalAmount {
    return _selectedSaleIds.fold(0.0, (sum, id) {
      final sale = _sales.firstWhere((s) => s.id == id);
      return sum + sale.outstandingBalance;
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      if (_selectAll) {
        _selectedSaleIds = _filteredSales.map((sale) => sale.id).toSet();
      } else {
        _selectedSaleIds.clear();
      }
    });
  }

  void _toggleSaleSelection(int saleId) {
    setState(() {
      if (_selectedSaleIds.contains(saleId)) {
        _selectedSaleIds.remove(saleId);
        _selectAll = false;
      } else {
        _selectedSaleIds.add(saleId);
        _selectAll = _selectedSaleIds.length == _filteredSales.length;
      }
    });
  }

  int? _getBankIdByName(String? bankName) {
    if (bankName == null) return null;
    final index = pakistaniBanks.indexWhere((bank) => bank.name == bankName);
    return index >= 0 ? index + 1 : null;
  }

  Future<void> _recordPayment() async {
    final lp = widget.languageProvider;

    if (_selectedSaleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lp.isEnglish ? 'Please select at least one sale' : 'براہ کرم کم از کم ایک فروخت منتخب کریں'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedSales = _sales.where((sale) => _selectedSaleIds.contains(sale.id)).toList();
    final totalOutstanding = selectedSales.fold<double>(0, (sum, sale) => sum + sale.outstandingBalance);

    final amountController = TextEditingController(text: totalOutstanding.toStringAsFixed(2));
    String selectedMethod = 'cash';

    Bank? selectedBank;
    final chequeNumberCtrl = TextEditingController();
    DateTime? chequeDate;
    Bank? selectedChequeBank;
    final slipNumberCtrl = TextEditingController();
    DateTime? slipDate;
    Bank? selectedSlipBank;

    DateTime? paymentDate = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(lp.isEnglish ? 'Record Payment' : 'ادائیگی ریکارڈ کریں'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 8),
                          Text(
                            lp.isEnglish
                                ? '${selectedSales.length} Sale(s) Selected'
                                : '${selectedSales.length} فروخت(یں) منتخب',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...selectedSales.map((sale) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: sale.saleType == 'pos' ? const Color(0xFF7C3AED).withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    sale.saleType == 'pos' ? 'POS' : 'INV',
                                    style: TextStyle(fontSize: 8, color: sale.saleType == 'pos' ? const Color(0xFF7C3AED) : Colors.blue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(sale.invoiceNumber, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            Text(_currencyFormat.format(sale.outstandingBalance), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(lp.isEnglish ? 'Total Outstanding' : 'کل بقایا', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(_currencyFormat.format(totalOutstanding), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    labelText: lp.isEnglish ? 'Payment Amount' : 'ادائیگی کی رقم',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED))),
                        child: child!,
                      ),
                    );
                    if (picked != null) setState(() => paymentDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 12),
                        Text(
                          '${lp.isEnglish ? 'Payment Date' : 'ادائیگی کی تاریخ'}: ${DateFormat('MMM dd, yyyy').format(paymentDate!)}',
                          style: TextStyle(fontFamily: lp.fontFamily),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(lp.isEnglish ? 'Payment Method' : 'ادائیگی کا طریقہ',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _methodOptions.map((opt) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildMethodChip(
                          label: opt['label'] as String,
                          icon: opt['icon'] as IconData,
                          color: opt['color'] as Color,
                          isSelected: selectedMethod == opt['value'],
                          onTap: () => setState(() => selectedMethod = opt['value'] as String),
                          lp: lp,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                if (selectedMethod == 'bank') ...[
                  _buildBankSelector(
                    label: lp.isEnglish ? 'Bank (Receiving) *' : 'بینک (وصول کرنے والا) *',
                    selectedBank: selectedBank,
                    onTap: () => _openBankPicker(
                      context: context,
                      title: lp.isEnglish ? 'Select Bank' : 'بینک منتخب کریں',
                      onSelected: (bank, index) => setState(() => selectedBank = bank),
                      currentSelection: selectedBank,
                      lp: lp,
                    ),
                    lp: lp,
                  ),
                ] else if (selectedMethod == 'cheque') ...[
                  _buildBankSelector(
                    label: lp.isEnglish ? 'Bank *' : 'بینک *',
                    selectedBank: selectedChequeBank,
                    onTap: () => _openBankPicker(
                      context: context,
                      title: lp.isEnglish ? 'Select Bank' : 'بینک منتخب کریں',
                      onSelected: (bank, index) => setState(() => selectedChequeBank = bank),
                      currentSelection: selectedChequeBank,
                      lp: lp,
                    ),
                    lp: lp,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: chequeNumberCtrl,
                    style: TextStyle(fontFamily: lp.fontFamily),
                    decoration: InputDecoration(
                      labelText: lp.isEnglish ? 'Cheque Number *' : 'چیک نمبر *',
                      hintText: lp.isEnglish ? 'e.g. 001234' : 'مثال: 001234',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: chequeDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 180)),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFFF59E0B))),
                          child: child!,
                        ),
                      );
                      if (picked != null) setState(() => chequeDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.event, size: 18, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 12),
                          Text(
                            chequeDate != null
                                ? '${lp.isEnglish ? 'Cheque Date' : 'چیک کی تاریخ'}: ${DateFormat('MMM dd, yyyy').format(chequeDate!)}'
                                : (lp.isEnglish ? 'Select Cheque Date *' : 'چیک کی تاریخ منتخب کریں *'),
                            style: TextStyle(fontFamily: lp.fontFamily),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (selectedMethod == 'slip') ...[
                  _buildBankSelector(
                    label: lp.isEnglish ? 'Bank *' : 'بینک *',
                    selectedBank: selectedSlipBank,
                    onTap: () => _openBankPicker(
                      context: context,
                      title: lp.isEnglish ? 'Select Bank' : 'بینک منتخب کریں',
                      onSelected: (bank, index) => setState(() => selectedSlipBank = bank),
                      currentSelection: selectedSlipBank,
                      lp: lp,
                    ),
                    lp: lp,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: slipNumberCtrl,
                    style: TextStyle(fontFamily: lp.fontFamily),
                    decoration: InputDecoration(
                      labelText: lp.isEnglish ? 'Slip Number *' : 'سلیپ نمبر *',
                      hintText: lp.isEnglish ? 'e.g. SLIP-001' : 'مثال: SLIP-001',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: slipDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF8B5CF6))),
                          child: child!,
                        ),
                      );
                      if (picked != null) setState(() => slipDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.event, size: 18, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 12),
                          Text(
                            slipDate != null
                                ? '${lp.isEnglish ? 'Slip Date' : 'سلیپ کی تاریخ'}: ${DateFormat('MMM dd, yyyy').format(slipDate!)}'
                                : (lp.isEnglish ? 'Select Slip Date *' : 'سلیپ کی تاریخ منتخب کریں *'),
                            style: TextStyle(fontFamily: lp.fontFamily),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lp.isEnglish ? 'Cancel' : 'منسوخ کریں'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(lp.isEnglish ? 'Enter valid amount' : 'درست رقم درج کریں'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (amount > totalOutstanding) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(lp.isEnglish ? 'Amount cannot exceed total outstanding' : 'رقم کل بقایا سے زیادہ نہیں ہو سکتی'), backgroundColor: Colors.red),
                  );
                  return;
                }

                if (selectedMethod == 'bank') {
                  if (selectedBank == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(lp.isEnglish ? 'Please select a bank' : 'براہ کرم بینک منتخب کریں'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                } else if (selectedMethod == 'cheque') {
                  if (selectedChequeBank == null || chequeNumberCtrl.text.isEmpty || chequeDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(lp.isEnglish ? 'Please fill all cheque details' : 'براہ کرم تمام چیک کی تفصیلات بھریں'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                } else if (selectedMethod == 'slip') {
                  if (selectedSlipBank == null || slipNumberCtrl.text.isEmpty || slipDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(lp.isEnglish ? 'Please fill all slip details' : 'براہ کرم تمام سلیپ کی تفصیلات بھریں'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                }

                Map<String, dynamic> paymentDetails = {
                  'amount': amount,
                  'method': selectedMethod,
                  'payment_date': paymentDate!.toIso8601String(),
                  'sale_ids': _selectedSaleIds.toList(),
                  'from_simple_cashbook': widget.fromSimpleCashbook,
                };

                if (selectedMethod == 'bank') {
                  paymentDetails['bank'] = selectedBank?.name;
                  paymentDetails['bank_id'] = _getBankIdByName(selectedBank?.name);
                } else if (selectedMethod == 'cheque') {
                  paymentDetails['bank'] = selectedChequeBank?.name;
                  paymentDetails['bank_id'] = _getBankIdByName(selectedChequeBank?.name);
                  paymentDetails['cheque_number'] = chequeNumberCtrl.text.trim();
                  paymentDetails['cheque_date'] = chequeDate!.toIso8601String();
                } else if (selectedMethod == 'slip') {
                  paymentDetails['bank'] = selectedSlipBank?.name;
                  paymentDetails['bank_id'] = _getBankIdByName(selectedSlipBank?.name);
                  paymentDetails['slip_number'] = slipNumberCtrl.text.trim();
                  paymentDetails['slip_date'] = slipDate!.toIso8601String();
                }

                Navigator.pop(context, paymentDetails);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(lp.isEnglish ? 'Record Payment' : 'ادائیگی ریکارڈ کریں'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

      final amount = result['amount'];
      final method = result['method'];
      final paymentDate = DateTime.parse(result['payment_date']);
      final saleIds = List<int>.from(result['sale_ids']);

      String? chequeNumber;
      String? bankName;
      int? bankId;
      DateTime? chequeDateVal;

      if (method == 'cheque') {
        chequeNumber = result['cheque_number'];
        bankName = result['bank'];
        bankId = result['bank_id'];
        chequeDateVal = result['cheque_date'] != null ? DateTime.parse(result['cheque_date']) : null;
      } else if (method == 'bank' || method == 'slip') {
        bankName = result['bank'];
        bankId = result['bank_id'];
      }

      bool allSuccess = true;
      String? successMessage;

      for (int saleId in saleIds) {
        final response = await saleProvider.recordPayment(
          saleId,
          amount,
          method,
          paymentDate: paymentDate,
          chequeNumber: chequeNumber,
          bankName: bankName,
          bankId: bankId,
          chequeDate: chequeDateVal,
          fromSimpleCashbook: widget.fromSimpleCashbook,
        );

        if (response['success'] != true) {
          allSuccess = false;
          break;
        }
        successMessage = response['message'];
      }

      if (allSuccess && mounted) {
        await customerProvider.fetchCustomers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage ?? (lp.isEnglish ? 'Payment recorded successfully' : 'ادائیگی کامیابی سے ریکارڈ ہوگئی')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lp.isEnglish ? 'Failed to record payment for some sales' : 'کچھ فروختوں کے لیے ادائیگی ریکارڈ کرنے میں ناکامی'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMethodChip({
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey.shade700,
                  fontFamily: lp.fontFamily,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBankSelector({
    required String label,
    required Bank? selectedBank,
    required VoidCallback onTap,
    required LanguageProvider lp,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF8E8E93), fontFamily: lp.fontFamily)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selectedBank != null ? Colors.blue.withOpacity(0.05) : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selectedBank != null ? Colors.blue.withOpacity(0.4) : const Color(0xFFE5E5EA)),
            ),
            child: Row(
              children: [
                if (selectedBank != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      selectedBank.iconPath,
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(Icons.account_balance, size: 28, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(selectedBank.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: lp.fontFamily))),
                  Icon(Icons.check_circle_rounded, color: Colors.blue, size: 18),
                ] else ...[
                  Icon(Icons.account_balance_outlined, size: 20, color: Colors.grey[400]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(lp.isEnglish ? 'Select bank' : 'بینک منتخب کریں',
                        style: TextStyle(fontSize: 14, color: const Color(0xFFC7C7CC), fontFamily: lp.fontFamily)),
                  ),
                  Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey[400]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openBankPicker({
    required BuildContext context,
    required String title,
    required Function(Bank, int) onSelected,
    Bank? currentSelection,
    required LanguageProvider lp,
  }) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PaymentBankSheet(
        title: title,
        selected: currentSelection,
        accentColor: const Color(0xFF7C3AED),
        languageProvider: lp,
      ),
    );
    if (result != null) {
      onSelected(result['bank'] as Bank, result['index'] as int);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = widget.languageProvider;
    final filterOptions = _filterOptions;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lp.isEnglish ? 'Receive Payment' : 'ادائیگی وصول کریں',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
            Text(widget.customer.name,
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: lp.fontFamily)),
          ],
        ),
        actions: [
          if (_selectedSaleIds.isNotEmpty)
            TextButton.icon(
              onPressed: _recordPayment,
              icon: const Icon(Icons.payment, color: Colors.green),
              label: Text(
                '${lp.isEnglish ? 'Receive' : 'وصول کریں'} ${_currencyFormat.format(_selectedTotalAmount)}',
                style: const TextStyle(color: Colors.green),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _error != null
          ? CustomErrorWidget(message: _error!, onRetry: _loadCustomerSales)
          : _sales.isEmpty
          ? _buildEmptyState(lp)
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: filterOptions.map((opt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(opt['label'] as String, style: TextStyle(fontFamily: lp.fontFamily)),
                    selected: _selectedType == opt['value'],
                    onSelected: (_) => setState(() {
                      _selectedType = opt['value'] as String;
                      _selectedSaleIds.clear();
                      _selectAll = false;
                    }),
                    backgroundColor: _selectedType == opt['value'] ? const Color(0xFF7C3AED) : Colors.grey[100],
                    selectedColor: const Color(0xFF7C3AED),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(color: _selectedType == opt['value'] ? Colors.white : Colors.grey[700], fontFamily: lp.fontFamily),
                  ),
                );
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Checkbox(
                  value: _selectAll,
                  onChanged: _filteredSales.isNotEmpty ? _toggleSelectAll : null,
                  activeColor: const Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                Text(lp.isEnglish ? 'Select All' : 'سب منتخب کریں',
                    style: TextStyle(fontWeight: FontWeight.w500, fontFamily: lp.fontFamily)),
                const Spacer(),
                Text('${lp.isEnglish ? 'Total' : 'کل'}: ${_currencyFormat.format(_selectedTotalAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredSales.length,
              itemBuilder: (context, index) {
                final sale = _filteredSales[index];
                final isSelected = _selectedSaleIds.contains(sale.id);
                final isOverdue = sale.isOverdue;
                final isPos = sale.saleType == 'pos';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF7C3AED) : isOverdue ? Colors.red.withOpacity(0.3) : const Color(0xFFF0F0F5),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _toggleSaleSelection(sale.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleSaleSelection(sale.id),
                            activeColor: const Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isPos ? const Color(0xFF7C3AED).withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isPos ? 'POS' : 'INVOICE',
                                        style: TextStyle(fontSize: 10, color: isPos ? const Color(0xFF7C3AED) : Colors.blue, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(sale.invoiceNumber,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                                    const SizedBox(width: 8),
                                    if (isOverdue)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: Text(lp.isEnglish ? 'OVERDUE' : 'زیر التواء',
                                            style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 12, color: Colors.grey[400]),
                                    const SizedBox(width: 4),
                                    Text(_dateFormat.format(sale.saleDate),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: lp.fontFamily)),
                                    if (sale.dueDate != null) ...[
                                      const SizedBox(width: 12),
                                      Icon(Icons.event, size: 12, color: Colors.grey[400]),
                                      const SizedBox(width: 4),
                                      Text(_dateFormat.format(sale.dueDate!),
                                          style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red : Colors.grey[600],
                                              fontFamily: lp.fontFamily)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${lp.isEnglish ? 'Total' : 'کل'}: ${_currencyFormat.format(sale.grandTotal)}',
                                        style: const TextStyle(fontSize: 13)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                      child: Text('${lp.isEnglish ? 'Due' : 'بقایا'}: ${_currencyFormat.format(sale.outstandingBalance)}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                    ),
                                  ],
                                ),
                                if (sale.paymentStatus == 'partial')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: LinearProgressIndicator(
                                      value: sale.amountPaid / sale.grandTotal,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider lp) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(lp.isEnglish ? 'No Unpaid Sales' : 'کوئی غیر ادا شدہ فروخت نہیں',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            lp.isEnglish
                ? '${widget.customer.name} has no outstanding invoices or POS sales'
                : '${widget.customer.name} کی کوئی بقایا انوائس یا POS فروخت نہیں ہے',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500], fontFamily: lp.fontFamily),
          ),
        ],
      ),
    );
  }
}

class _PaymentBankSheet extends StatefulWidget {
  final String title;
  final Bank? selected;
  final Color accentColor;
  final LanguageProvider languageProvider;

  const _PaymentBankSheet({
    required this.title,
    required this.selected,
    required this.accentColor,
    required this.languageProvider,
  });

  @override
  State<_PaymentBankSheet> createState() => _PaymentBankSheetState();
}

class _PaymentBankSheetState extends State<_PaymentBankSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Bank> _filteredBanks = pakistaniBanks;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filterBanks);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterBanks() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredBanks = pakistaniBanks.where((bank) => bank.name.toLowerCase().contains(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lp = widget.languageProvider;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)),
          ),
          Row(
            children: [
              Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
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
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredBanks.length,
              itemBuilder: (context, index) {
                final bank = _filteredBanks[index];
                final originalIndex = pakistaniBanks.indexOf(bank);
                final isSelected = widget.selected?.name == bank.name;

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      bank.iconPath,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.account_balance, color: widget.accentColor, size: 20),
                      ),
                    ),
                  ),
                  title: Text(
                    bank.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? widget.accentColor : null,
                      fontFamily: lp.fontFamily,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_circle, color: widget.accentColor) : null,
                  onTap: () => Navigator.pop(context, {'bank': bank, 'index': originalIndex}),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}