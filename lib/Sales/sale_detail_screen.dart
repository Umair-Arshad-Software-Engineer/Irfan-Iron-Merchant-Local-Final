import 'package:flutter/material.dart';
import 'package:irfan_iron_merchant_local/Sales/sale_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../providers/sale_provider.dart';
import '../../models/sale_model.dart';
import '../components/loading_indicator.dart';
import '../components/error_widget.dart';
import '../Banks/banknames.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';
import '../services/sale_pdf_generator.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../providers/lanprovider.dart'; // Add this import

class SaleDetailScreen extends StatefulWidget {
  final int saleId;
  const SaleDetailScreen({super.key, required this.saleId});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  SaleModel? _sale;
  bool _isLoading = true;
  String? _error;

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final DateFormat _timeFormat = DateFormat('hh:mm a');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs ');

  // Responsive breakpoints
  static const double _mobileBreakpoint = 600;
  static const double _tabletBreakpoint = 900;
  static const double _desktopBreakpoint = 1200;

  // Helper to get bank ID by name
  int? _getBankIdByName(String? bankName) {
    if (bankName == null) return null;
    final index = pakistaniBanks.indexWhere((bank) => bank.name == bankName);
    return index >= 0 ? index + 1 : null;
  }

  String _safeLengthLabel(String length, int qty) {
    const fsi = '\u2068';
    const pdi = '\u2069';
    return '$fsi$length$pdi × $qty';
  }

  @override
  void initState() {
    super.initState();
    _loadSale();
  }

  Future<void> _loadSale() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<SaleProvider>(context, listen: false);
      final sale = await provider.getSaleById(widget.saleId);

      setState(() {
        _sale = sale;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load sale details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAndOpenPdf(Uint8List pdfData, String fileName) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\-\.]'), '_');
      final fullFileName = '${safeFileName}_$timestamp.pdf';
      final filePath = '${directory.path}/$fullFileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfData);

      if (mounted) Navigator.pop(context);

      final result = await OpenFile.open(file.path);
      if (result.type == ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(languageProvider.isEnglish
                  ? 'PDF saved: $fullFileName'
                  : 'پی ڈی ایف محفوظ: $fullFileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception(languageProvider.isEnglish
            ? 'Failed to open PDF: ${result.message}'
            : 'پی ڈی ایف کھولنے میں ناکامی: ${result.message}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'Failed to save/open PDF: $e'
                : 'پی ڈی ایف محفوظ/کھولنے میں ناکامی: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _voidSale() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(languageProvider.isEnglish ? 'Void Sale' : 'فروخت منسوخ کریں'),
        content: Text(
          languageProvider.isEnglish
              ? 'Are you sure you want to void ${_sale!.invoiceNumber}? This will restore stock and reverse ledger entries.'
              : 'کیا آپ واقعی ${_sale!.invoiceNumber} کو منسوخ کرنا چاہتے ہیں؟ اس سے اسٹاک بحال ہوگا اور لیجر اندراجات کو الٹ دیا جائے گا۔',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(languageProvider.isEnglish ? 'Void Sale' : 'فروخت منسوخ کریں'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final provider = Provider.of<SaleProvider>(context, listen: false);
      final result = await provider.deleteSale(widget.saleId);

      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'Sale voided successfully'
                : 'فروخت کامیابی سے منسوخ ہوگئی'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? (languageProvider.isEnglish
                  ? 'Failed to void sale'
                  : 'فروخت منسوخ کرنے میں ناکامی'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _recordPayment() async {
    if (_sale == null) return;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final amountController = TextEditingController(text: _sale!.outstandingBalance.toStringAsFixed(2));
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
          title: Text(languageProvider.isEnglish ? 'Record Payment' : 'ادائیگی ریکارڈ کریں'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            languageProvider.isEnglish
                                ? 'Outstanding: ${_currencyFormat.format(_sale!.outstandingBalance)}'
                                : 'بقایا: ${_currencyFormat.format(_sale!.outstandingBalance)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Payment Amount' : 'ادائیگی کی رقم',
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
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED)),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => paymentDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            languageProvider.isEnglish
                                ? 'Payment Date: ${DateFormat('MMM dd, yyyy').format(paymentDate!)}'
                                : 'ادائیگی کی تاریخ: ${DateFormat('MMM dd, yyyy').format(paymentDate!)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    languageProvider.isEnglish ? 'Payment Method' : 'ادائیگی کا طریقہ',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildMethodChip(
                          label: languageProvider.isEnglish ? 'Cash' : 'نقد',
                          icon: Icons.payments_outlined,
                          color: const Color(0xFF10B981),
                          isSelected: selectedMethod == 'cash',
                          onTap: () => setState(() => selectedMethod = 'cash'),
                          languageProvider: languageProvider,
                        ),
                        const SizedBox(width: 8),
                        _buildMethodChip(
                          label: languageProvider.isEnglish ? 'Bank' : 'بینک',
                          icon: Icons.account_balance_outlined,
                          color: const Color(0xFF3B82F6),
                          isSelected: selectedMethod == 'bank',
                          onTap: () => setState(() => selectedMethod = 'bank'),
                          languageProvider: languageProvider,
                        ),
                        const SizedBox(width: 8),
                        _buildMethodChip(
                          label: languageProvider.isEnglish ? 'Cheque' : 'چیک',
                          icon: Icons.receipt_long_outlined,
                          color: const Color(0xFFF59E0B),
                          isSelected: selectedMethod == 'cheque',
                          onTap: () => setState(() => selectedMethod = 'cheque'),
                          languageProvider: languageProvider,
                        ),
                        const SizedBox(width: 8),
                        _buildMethodChip(
                          label: languageProvider.isEnglish ? 'Slip' : 'سلپ',
                          icon: Icons.receipt_outlined,
                          color: const Color(0xFF8B5CF6),
                          isSelected: selectedMethod == 'slip',
                          onTap: () => setState(() => selectedMethod = 'slip'),
                          languageProvider: languageProvider,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selectedMethod == 'bank') ...[
                    _buildBankSelector(
                      label: languageProvider.isEnglish ? 'Bank (Receiving) *' : 'بینک (وصول کنندہ) *',
                      selectedBank: selectedBank,
                      onTap: () => _openBankPicker(
                        context: context,
                        title: languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں',
                        onSelected: (bank) => setState(() => selectedBank = bank),
                        currentSelection: selectedBank,
                      ),
                    ),
                  ] else if (selectedMethod == 'cheque') ...[
                    _buildBankSelector(
                      label: languageProvider.isEnglish ? 'Bank *' : 'بینک *',
                      selectedBank: selectedChequeBank,
                      onTap: () => _openBankPicker(
                        context: context,
                        title: languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں',
                        onSelected: (bank) => setState(() => selectedChequeBank = bank),
                        currentSelection: selectedChequeBank,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: chequeNumberCtrl,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Cheque Number *' : 'چیک نمبر *',
                        hintText: languageProvider.isEnglish ? 'e.g. 001234' : 'مثال: 001234',
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
                            data: Theme.of(ctx).copyWith(
                              colorScheme: const ColorScheme.light(primary: Color(0xFFF59E0B)),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setState(() => chequeDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, size: 18, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 12),
                            Text(
                              chequeDate != null
                                  ? (languageProvider.isEnglish
                                  ? 'Cheque Date: ${DateFormat('MMM dd, yyyy').format(chequeDate!)}'
                                  : 'چیک کی تاریخ: ${DateFormat('MMM dd, yyyy').format(chequeDate!)}')
                                  : (languageProvider.isEnglish ? 'Select Cheque Date *' : 'چیک کی تاریخ منتخب کریں *'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (selectedMethod == 'slip') ...[
                    _buildBankSelector(
                      label: languageProvider.isEnglish ? 'Bank *' : 'بینک *',
                      selectedBank: selectedSlipBank,
                      onTap: () => _openBankPicker(
                        context: context,
                        title: languageProvider.isEnglish ? 'Select Bank' : 'بینک منتخب کریں',
                        onSelected: (bank) => setState(() => selectedSlipBank = bank),
                        currentSelection: selectedSlipBank,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: slipNumberCtrl,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Slip Number *' : 'سلپ نمبر *',
                        hintText: languageProvider.isEnglish ? 'e.g. SLIP-001' : 'مثال: SLIP-001',
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
                            data: Theme.of(ctx).copyWith(
                              colorScheme: const ColorScheme.light(primary: Color(0xFF8B5CF6)),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setState(() => slipDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, size: 18, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 12),
                            Text(
                              slipDate != null
                                  ? (languageProvider.isEnglish
                                  ? 'Slip Date: ${DateFormat('MMM dd, yyyy').format(slipDate!)}'
                                  : 'سلپ کی تاریخ: ${DateFormat('MMM dd, yyyy').format(slipDate!)}')
                                  : (languageProvider.isEnglish ? 'Select Slip Date *' : 'سلپ کی تاریخ منتخب کریں *'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(languageProvider.isEnglish
                          ? 'Enter valid amount'
                          : 'درست رقم درج کریں'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (amount > _sale!.outstandingBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(languageProvider.isEnglish
                          ? 'Amount cannot exceed outstanding balance'
                          : 'رقم بقایا سے زیادہ نہیں ہوسکتی'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (selectedMethod == 'bank') {
                  if (selectedBank == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(languageProvider.isEnglish
                            ? 'Please select a bank'
                            : 'براہ کرم بینک منتخب کریں'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                } else if (selectedMethod == 'cheque') {
                  if (selectedChequeBank == null || chequeNumberCtrl.text.isEmpty || chequeDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(languageProvider.isEnglish
                            ? 'Please fill all cheque details'
                            : 'براہ کرم تمام چیک کی تفصیلات پُر کریں'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                } else if (selectedMethod == 'slip') {
                  if (selectedSlipBank == null || slipNumberCtrl.text.isEmpty || slipDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(languageProvider.isEnglish
                            ? 'Please fill all slip details'
                            : 'براہ کرم تمام سلپ کی تفصیلات پُر کریں'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }

                Map<String, dynamic> paymentDetails = {
                  'amount': amount,
                  'method': selectedMethod,
                  'payment_date': paymentDate!.toIso8601String(),
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
              child: Text(languageProvider.isEnglish ? 'Record Payment' : 'ادائیگی ریکارڈ کریں'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final provider = Provider.of<SaleProvider>(context, listen: false);
      final amount = result['amount'];
      final method = result['method'];
      final paymentDate = DateTime.parse(result['payment_date']);

      String? chequeNumber;
      String? bankName;
      int? bankId;
      DateTime? chequeDate;

      if (method == 'cheque') {
        chequeNumber = result['cheque_number'];
        bankName = result['bank'];
        bankId = result['bank_id'];
        chequeDate = result['cheque_date'] != null ? DateTime.parse(result['cheque_date']) : null;
      } else if (method == 'bank' || method == 'slip') {
        bankName = result['bank'];
        bankId = result['bank_id'];
      }

      final response = await provider.recordPayment(
        widget.saleId,
        amount,
        method,
        paymentDate: paymentDate,
        chequeNumber: chequeNumber,
        bankName: bankName,
        bankId: bankId,
        chequeDate: chequeDate,
      );

      if (response['success'] == true && mounted) {
        String successMsg;
        if (method == 'cheque' && chequeNumber != null) {
          successMsg = languageProvider.isEnglish
              ? 'Cheque #$chequeNumber recorded. Status: Pending (awaiting clearing)'
              : 'چیک #$chequeNumber ریکارڈ ہوگیا۔ حیثیت: زیر التواء (کلئیرنگ کا انتظار)';
        } else if (method == 'bank' && bankName != null) {
          successMsg = languageProvider.isEnglish
              ? 'Bank transfer to $bankName recorded successfully'
              : '$bankName میں بینک ٹرانسفر کامیابی سے ریکارڈ ہوگیا';
        } else {
          successMsg = languageProvider.isEnglish
              ? 'Payment recorded successfully'
              : 'ادائیگی کامیابی سے ریکارڈ ہوگئی';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMsg), backgroundColor: Colors.green),
        );
        _loadSale();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? (languageProvider.isEnglish
                  ? 'Failed to record payment'
                  : 'ادائیگی ریکارڈ کرنے میں ناکامی'),
            ),
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
    required LanguageProvider languageProvider,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
                fontFamily: languageProvider.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankSelector({
    required String label,
    required Bank? selectedBank,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93)),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selectedBank != null ? Colors.blue.withOpacity(0.05) : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selectedBank != null ? Colors.blue.withOpacity(0.4) : const Color(0xFFE5E5EA),
              ),
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
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.account_balance,
                        size: 28,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedBank.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, color: Colors.blue, size: 18),
                ] else ...[
                  Icon(Icons.account_balance_outlined, size: 20, color: Colors.grey[400]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Select bank',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
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
    required Function(Bank) onSelected,
    Bank? currentSelection,
  }) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PaymentBankSheet(
        title: title,
        selected: currentSelection,
        accentColor: const Color(0xFF7C3AED),
      ),
    );
    if (result != null) {
      onSelected(result['bank'] as Bank);
    }
  }

  Customer? _toCustomer(CustomerInfo? info) {
    if (info == null) return null;
    return Customer(
      id: info.id,
      name: info.name,
      contact: info.contact ?? '',
      address: info.address,
      email: info.email,
      customerType: info.customerType,
      balance: 0.0,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void _showPrintOptionsSheet(Uint8List pdfData) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              languageProvider.isEnglish ? 'Document Options' : 'دستاویز کے اختیارات',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildPrintOption(
                  icon: Icons.print,
                  label: languageProvider.isEnglish ? 'Print' : 'پرنٹ کریں',
                  color: const Color(0xFF7C3AED),
                  onTap: () {
                    Navigator.pop(ctx);
                    SalePdfGenerator.printPdf(pdfData);
                  },
                ),
                _buildPrintOption(
                  icon: Icons.share,
                  label: languageProvider.isEnglish ? 'Share' : 'شیئر کریں',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    Navigator.pop(ctx);
                    SalePdfGenerator.sharePdf(pdfData, '${_sale!.invoiceNumber}.pdf');
                  },
                ),
                _buildPrintOption(
                  icon: Icons.download,
                  label: languageProvider.isEnglish ? 'Save & Open' : 'محفوظ اور کھولیں',
                  color: const Color(0xFF3B82F6),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _saveAndOpenPdf(pdfData, _sale!.invoiceNumber);
                  },
                ),
                _buildPrintOption(
                  icon: Icons.visibility,
                  label: languageProvider.isEnglish ? 'Preview' : 'پیش نظارہ',
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPdfPreview(pdfData);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 120,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPdfPreview(Uint8List pdfData) async {
    await Printing.layoutPdf(onLayout: (_) => pdfData);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < _mobileBreakpoint;
        final isTablet = screenWidth >= _mobileBreakpoint && screenWidth < _desktopBreakpoint;
        final isDesktop = screenWidth >= _desktopBreakpoint;

        if (_isLoading) {
          return const Scaffold(
            body: LoadingIndicator(),
          );
        }

        if (_error != null) {
          return Scaffold(
            body: CustomErrorWidget(
              message: _error!,
              onRetry: _loadSale,
            ),
          );
        }

        if (_sale == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(languageProvider.isEnglish ? 'Sale Details' : 'فروخت کی تفصیلات'),
            ),
            body: Center(
              child: Text(languageProvider.isEnglish ? 'Sale not found' : 'فروخت نہیں ملی'),
            ),
          );
        }

        final bool isCredit = _sale!.paymentMethod == 'credit';
        final bool isOverdue = _sale!.isOverdue;

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)),
                onPressed: () => Navigator.pop(context, true),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _sale!.invoiceNumber,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      if (isCredit)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            languageProvider.isEnglish ? 'CREDIT' : 'کریڈٹ',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7C3AED),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    _sale!.saleType == 'pos'
                        ? (languageProvider.isEnglish ? 'POS Counter Sale' : 'پی او ایس کاؤنٹر فروخت')
                        : (languageProvider.isEnglish ? 'Invoice' : 'انوائس'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: languageProvider.fontFamily,
                    ),
                  ),
                ],
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Color(0xFF2D3142),
                  ),
                  tooltip: languageProvider.isEnglish ? 'More actions' : 'مزید اقدامات',
                  onSelected: (value) async {
                    switch (value) {
                      case 'payment':
                        _recordPayment();
                        break;

                      case 'print':
                        if (_sale != null) {
                          final items = _sale!.items?.map((item) => {
                            'product_name': item.productName,
                            'description': item.description ?? '',
                            'quantity': item.quantity,
                            'weight': item.weight ?? 0.0,
                            'unit_price': item.unitPrice,
                            'total': item.totalPrice,
                            'selected_lengths': item.selectedLengths ?? [],
                            'length_quantities': item.lengthQuantities ?? {},
                          }).toList() ?? [];

                          try {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(child: CircularProgressIndicator()),
                            );

                            // ✅ Fetch current customer balance from provider
                            double previousBalance = 0.0;
                            if (_sale!.customer != null) {
                              final custProvider = Provider.of<CustomerProvider>(context, listen: false);
                              await custProvider.fetchCustomerById(_sale!.customer!.id);
                              final freshCustomer = custProvider.getCustomerById(_sale!.customer!.id);
                              if (freshCustomer != null) {
                                // Current balance includes this invoice's outstanding
                                // Previous balance = current balance - outstanding of THIS invoice
                                previousBalance = freshCustomer.balance - _sale!.outstandingBalance;
                              }
                            }

                            final pdfData = await SalePdfGenerator.generateSalePdf(
                              saleData: {
                                'invoice_number': _sale!.invoiceNumber,
                                'sale_category': _sale!.saleCategory ?? 'filled',
                                'reference': _sale!.reference ?? '',
                              },
                              customer: _toCustomer(_sale!.customer),
                              items: items,
                              subtotal: _sale!.subtotal,
                              discountValue: _sale!.discountAmount,
                              grandTotal: _sale!.grandTotal,
                              isPosMode: _sale!.saleType == 'pos',
                              paymentMethod: _sale!.paymentMethod,
                              amountPaid: _sale!.amountPaid,
                              dueDate: _sale!.dueDate,
                              notes: _sale!.notes,
                              previousBalance: previousBalance, // ✅ correct value
                            );

                            if (mounted) Navigator.pop(context);
                            _showPrintOptionsSheet(pdfData);
                          } catch (e) {
                            if (mounted) Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(languageProvider.isEnglish
                                    ? 'Failed to generate PDF: $e'
                                    : 'پی ڈی ایف بنانے میں ناکامی: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                        break;

                      case 'edit':
                        if (_sale!.paymentStatus != 'paid') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SaleScreen(existingSale: _sale!),
                            ),
                          ).then((refreshed) {
                            if (refreshed == true) {
                              _loadSale();
                            }
                          });
                        }
                        break;

                      case 'void':
                        if (_sale!.paymentStatus != 'paid') {
                          _voidSale();
                        }
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    if (_sale!.paymentStatus != 'paid')
                      PopupMenuItem<String>(
                        value: 'payment',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.payment,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(languageProvider.isEnglish ? 'Record Payment' : 'ادائیگی ریکارڈ کریں'),
                          ],
                        ),
                      ),

                    PopupMenuItem<String>(
                      value: 'print',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.print,
                            color: Color(0xFF7C3AED),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(languageProvider.isEnglish ? 'Print/Save Receipt' : 'رسید پرنٹ/محفوظ کریں'),
                        ],
                      ),
                    ),

                    if (_sale!.paymentStatus != 'paid') ...[
                      const PopupMenuDivider(),

                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              color: Color(0xFF7C3AED),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(languageProvider.isEnglish ? 'Edit Sale' : 'فروخت میں ترمیم کریں'),
                          ],
                        ),
                      ),

                      PopupMenuItem<String>(
                        value: 'void',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              languageProvider.isEnglish ? 'Void Sale' : 'فروخت منسوخ کریں',
                              style: const TextStyle(
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 1400 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Banner
                    Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      decoration: BoxDecoration(
                        color: isCredit && _sale!.paymentStatus != 'paid'
                            ? const Color(0xFF7C3AED).withOpacity(0.1)
                            : _sale!.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCredit && _sale!.paymentStatus != 'paid'
                              ? const Color(0xFF7C3AED).withOpacity(0.3)
                              : _sale!.statusColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCredit && _sale!.paymentStatus != 'paid'
                                ? Icons.credit_card
                                : _sale!.paymentStatus == 'paid'
                                ? Icons.check_circle
                                : _sale!.paymentStatus == 'partial'
                                ? Icons.pending
                                : Icons.error,
                            color: isCredit && _sale!.paymentStatus != 'paid'
                                ? const Color(0xFF7C3AED)
                                : _sale!.statusColor,
                            size: isMobile ? 20 : 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCredit && _sale!.paymentStatus != 'paid'
                                      ? (languageProvider.isEnglish ? 'CREDIT SALE' : 'کریڈٹ فروخت')
                                      : (languageProvider.isEnglish
                                      ? 'Payment Status: ${_sale!.paymentStatus.toUpperCase()}'
                                      : 'ادائیگی کی حیثیت: ${_sale!.paymentStatus.toUpperCase()}'),
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: isCredit && _sale!.paymentStatus != 'paid'
                                        ? const Color(0xFF7C3AED)
                                        : _sale!.statusColor,
                                    fontFamily: languageProvider.fontFamily,
                                  ),
                                ),
                                if (_sale!.paymentStatus != 'paid')
                                  Text(
                                    languageProvider.isEnglish
                                        ? 'Outstanding: ${_currencyFormat.format(_sale!.outstandingBalance)}'
                                        : 'بقایا: ${_currencyFormat.format(_sale!.outstandingBalance)}',
                                    style: TextStyle(
                                      fontSize: isMobile ? 12 : 14,
                                      color: isCredit && _sale!.paymentStatus != 'paid'
                                          ? const Color(0xFF7C3AED)
                                          : _sale!.statusColor,
                                      fontFamily: languageProvider.fontFamily,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isOverdue)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                languageProvider.isEnglish ? 'OVERDUE' : 'واقع شدہ',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Customer & Date Info - Responsive Grid
                    Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF0F0F5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.isEnglish ? 'Transaction Details' : 'لین دین کی تفصیلات',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          if (_sale!.reference != null && _sale!.reference!.isNotEmpty) ...[
                            _buildInfoRow(
                              icon: Icons.receipt,
                              label: languageProvider.isEnglish ? 'Reference' : 'حوالہ',
                              value: _sale!.reference!,
                              isMobile: isMobile,
                              languageProvider: languageProvider,
                            ),
                            const Divider(height: 24),
                          ],
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildInfoRow(
                                    icon: Icons.person,
                                    label: languageProvider.isEnglish ? 'Customer' : 'کسٹمر',
                                    value: _sale!.customer?.name ?? (languageProvider.isEnglish ? 'Walk-in Customer' : 'واک ان کسٹمر'),
                                    isMobile: isMobile,
                                    languageProvider: languageProvider,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildInfoRow(
                                    icon: Icons.phone,
                                    label: languageProvider.isEnglish ? 'Contact' : 'رابطہ',
                                    value: _sale!.customer?.contact ?? 'N/A',
                                    isMobile: isMobile,
                                    languageProvider: languageProvider,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildInfoRow(
                                    icon: Icons.calendar_today,
                                    label: languageProvider.isEnglish ? 'Sale Date' : 'فروخت کی تاریخ',
                                    value: '${_dateFormat.format(_sale!.saleDate)} ${_timeFormat.format(_sale!.saleDate)}',
                                    isMobile: isMobile,
                                    languageProvider: languageProvider,
                                  ),
                                ),
                                if (_sale!.dueDate != null) ...[
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildInfoRow(
                                      icon: Icons.event,
                                      label: languageProvider.isEnglish ? 'Due Date' : 'آخری تاریخ',
                                      value: _dateFormat.format(_sale!.dueDate!),
                                      isMobile: isMobile,
                                      languageProvider: languageProvider,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          else
                            Column(
                              children: [
                                if (isTablet)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildInfoRow(
                                          icon: Icons.person,
                                          label: languageProvider.isEnglish ? 'Customer' : 'کسٹمر',
                                          value: _sale!.customer?.name ?? (languageProvider.isEnglish ? 'Walk-in Customer' : 'واک ان کسٹمر'),
                                          isMobile: isMobile,
                                          languageProvider: languageProvider,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildInfoRow(
                                          icon: Icons.phone,
                                          label: languageProvider.isEnglish ? 'Contact' : 'رابطہ',
                                          value: _sale!.customer?.contact ?? 'N/A',
                                          isMobile: isMobile,
                                          languageProvider: languageProvider,
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  _buildInfoRow(
                                    icon: Icons.person,
                                    label: languageProvider.isEnglish ? 'Customer' : 'کسٹمر',
                                    value: _sale!.customer?.name ?? (languageProvider.isEnglish ? 'Walk-in Customer' : 'واک ان کسٹمر'),
                                    isMobile: isMobile,
                                    languageProvider: languageProvider,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(
                                    icon: Icons.phone,
                                    label: languageProvider.isEnglish ? 'Contact' : 'رابطہ',
                                    value: _sale!.customer?.contact ?? 'N/A',
                                    isMobile: isMobile,
                                    languageProvider: languageProvider,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                if (isTablet)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildInfoRow(
                                          icon: Icons.calendar_today,
                                          label: languageProvider.isEnglish ? 'Sale Date' : 'فروخت کی تاریخ',
                                          value: '${_dateFormat.format(_sale!.saleDate)} ${_timeFormat.format(_sale!.saleDate)}',
                                          isMobile: isMobile,
                                          languageProvider: languageProvider,
                                        ),
                                      ),
                                      if (_sale!.dueDate != null) ...[
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildInfoRow(
                                            icon: Icons.event,
                                            label: languageProvider.isEnglish ? 'Due Date' : 'آخری تاریخ',
                                            value: _dateFormat.format(_sale!.dueDate!),
                                            isMobile: isMobile,
                                            languageProvider: languageProvider,
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                else ...[
                                  _buildInfoRow(
                                    icon: Icons.calendar_today,
                                    label: languageProvider.isEnglish ? 'Sale Date' : 'فروخت کی تاریخ',
                                    value: '${_dateFormat.format(_sale!.saleDate)} ${_timeFormat.format(_sale!.saleDate)}',
                                    isMobile: isMobile,
                                    languageProvider: languageProvider,
                                  ),
                                  if (_sale!.dueDate != null) ...[
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      icon: Icons.event,
                                      label: languageProvider.isEnglish ? 'Due Date' : 'آخری تاریخ',
                                      value: _dateFormat.format(_sale!.dueDate!),
                                      isMobile: isMobile,
                                      languageProvider: languageProvider,
                                    ),
                                  ],
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Items Section
                    Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF0F0F5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                languageProvider.isEnglish ? 'Items' : 'اشیاء',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _sale!.saleCategory == 'sarya'
                                      ? const Color(0xFFEFF6FF)
                                      : const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _sale!.saleCategory == 'sarya'
                                          ? Icons.scale
                                          : Icons.production_quantity_limits,
                                      size: 12,
                                      color: _sale!.saleCategory == 'sarya'
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFF10B981),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _sale!.saleCategory == 'sarya'
                                          ? (languageProvider.isEnglish ? 'Weight-based' : 'وزن کی بنیاد پر')
                                          : (languageProvider.isEnglish ? 'Quantity-based' : 'مقدار کی بنیاد پر'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _sale!.saleCategory == 'sarya'
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_sale!.items?.any((i) => i.hasLengthCombinations) ?? false) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.straighten, size: 13, color: Color(0xFF7C3AED)),
                                      const SizedBox(width: 4),
                                      Text(
                                        isMobile
                                            ? (languageProvider.isEnglish ? 'Multi-length' : 'متعدد لمبائی')
                                            : (languageProvider.isEnglish ? 'Multi-length items' : 'متعدد لمبائی کی اشیاء'),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF7C3AED),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFF0F0F5)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: isMobile ? 2 : 3,
                                        child: Text(
                                          languageProvider.isEnglish ? 'Product' : 'پروڈکٹ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isMobile ? 11 : 14,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _sale!.saleCategory == 'sarya'
                                              ? (languageProvider.isEnglish ? 'Weight' : 'وزن')
                                              : (languageProvider.isEnglish ? 'Qty' : 'مقدار'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isMobile ? 11 : 14,
                                          ),
                                        ),
                                      ),
                                      if (!isMobile) ...[
                                        const Expanded(
                                          child: Text(
                                            'Price',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const Expanded(
                                          child: Text(
                                            'Total',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                ...?_sale!.items?.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  final hasLengths = item.hasLengthCombinations;
                                  final isSarya = _sale!.saleCategory == 'sarya';

                                  String getDisplayQuantity() {
                                    if (isSarya && (item.weight ?? 0) > 0) {
                                      return '${item.weight!.toStringAsFixed(2)} Kg';
                                    } else {
                                      return '${item.quantity} ${item.product?.unit?.symbol ?? 'pcs'}';
                                    }
                                  }

                                  return Container(
                                    decoration: BoxDecoration(
                                      border: const Border(top: BorderSide(color: Color(0xFFF0F0F5))),
                                      color: index.isEven ? null : const Color(0xFFF9FAFB),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isMobile ? 8 : 16,
                                            vertical: isMobile ? 8 : 12,
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: isMobile ? 2 : 3,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.productName,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: isMobile ? 13 : 14,
                                                        fontFamily: languageProvider.fontFamily,
                                                      ),
                                                    ),
                                                    if (item.barcode != null) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        item.barcode!,
                                                        style: TextStyle(
                                                          fontSize: isMobile ? 10 : 11,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
// ✅ ADD THIS — show description if present
                                                    if (item.description != null && item.description!.isNotEmpty) ...[
                                                      const SizedBox(height: 3),
                                                      Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Icon(
                                                            Icons.notes,
                                                            size: 11,
                                                            color: Colors.grey[500],
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Expanded(
                                                            child: Text(
                                                              item.description!,
                                                              style: TextStyle(
                                                                fontSize: isMobile ? 10 : 11,
                                                                color: Colors.grey[600],
                                                                fontStyle: FontStyle.italic,
                                                                fontFamily: languageProvider.fontFamily,
                                                              ),
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                    if (hasLengths &&
                                                        item.selectedLengthsDisplay != null &&
                                                        item.selectedLengthsDisplay!.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.straighten,
                                                              size: 11, color: Color(0xFF7C3AED)),
                                                          const SizedBox(width: 4),
                                                          Expanded(
                                                            child: Directionality(
                                                              textDirection: TextDirection.ltr,
                                                              child: Text(
                                                                item.selectedLengthsDisplay!,
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  color: Color(0xFF7C3AED),
                                                                  fontStyle: FontStyle.italic,
                                                                ),
                                                                maxLines: 2,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                    if (!isSarya && (item.weight ?? 0) > 0) ...[
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.scale,
                                                              size: 11, color: Color(0xFF1D4ED8)),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            '${languageProvider.isEnglish ? 'Weight' : 'وزن'}: ${item.weight!.toStringAsFixed(2)} Kg',
                                                            style: const TextStyle(
                                                                fontSize: 11, color: Color(0xFF1D4ED8)),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                    if (hasLengths && (item.totalPieces ?? 0) > 0) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        languageProvider.isEnglish
                                                            ? '${item.totalPieces} pcs total'
                                                            : 'کل ${item.totalPieces} ٹکڑے',
                                                        style: TextStyle(
                                                            fontSize: isMobile ? 10 : 11,
                                                            color: Colors.teal[700],
                                                            fontWeight: FontWeight.w500),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  getDisplayQuantity(),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: isMobile ? 12 : 14,
                                                    fontFamily: languageProvider.fontFamily,
                                                  ),
                                                ),
                                              ),
                                              if (!isMobile) ...[
                                                Expanded(
                                                  child: Text(
                                                    _currencyFormat.format(item.unitPrice),
                                                    textAlign: TextAlign.right,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w500,
                                                      fontSize: isMobile ? 12 : 14,
                                                      fontFamily: languageProvider.fontFamily,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    _currencyFormat.format(item.totalPrice),
                                                    textAlign: TextAlign.right,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF7C3AED),
                                                      fontSize: isMobile ? 12 : 14,
                                                      fontFamily: languageProvider.fontFamily,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (isMobile) ...[
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '${languageProvider.isEnglish ? 'Price' : 'قیمت'}: ${_currencyFormat.format(item.unitPrice)}',
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                                Text(
                                                  '${languageProvider.isEnglish ? 'Total' : 'کل'}: ${_currencyFormat.format(item.totalPrice)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF7C3AED),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (hasLengths) ...[
                                          Padding(
                                            padding: EdgeInsets.fromLTRB(
                                              isMobile ? 8 : 16,
                                              0,
                                              isMobile ? 8 : 16,
                                              isMobile ? 8 : 12,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF0FDF4),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: const Color(0xFF10B981).withOpacity(0.3)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        languageProvider.isEnglish ? 'Length Breakdown' : 'لمبائی کی تفصیل',
                                                        style: TextStyle(
                                                          fontSize: isMobile ? 10 : 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.teal[800],
                                                          fontFamily: languageProvider.fontFamily,
                                                        ),
                                                      ),
                                                      if ((item.totalPieces ?? 0) > 0)
                                                        Text(
                                                          languageProvider.isEnglish
                                                              ? '${item.totalPieces} pcs'
                                                              : '${item.totalPieces} ٹکڑے',
                                                          style: TextStyle(
                                                            fontSize: isMobile ? 10 : 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.teal[700],
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children: item.selectedLengths!.map((length) {
                                                      final qty = item.lengthQuantities?[length];
                                                      final qtyNum = qty is num
                                                          ? qty.toInt()
                                                          : int.tryParse(qty?.toString() ?? '') ?? 1;
                                                      return Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 10, vertical: 5),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFD1FAE5),
                                                          borderRadius: BorderRadius.circular(20),
                                                          border: Border.all(
                                                              color: const Color(0xFF10B981)),
                                                        ),
                                                        child: Text(
                                                          _safeLengthLabel(length, qtyNum),
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: Color(0xFF065F46),
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Payment Summary - Responsive layout
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildPaymentSummaryCard(
                              isMobile: isMobile,
                              languageProvider: languageProvider,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildPaymentInfoCard(
                              isMobile: isMobile,
                              isCredit: isCredit,
                              isOverdue: isOverdue,
                              languageProvider: languageProvider,
                            ),
                          ),
                        ],
                      )
                    else if (isTablet)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildPaymentSummaryCard(
                              isMobile: isMobile,
                              languageProvider: languageProvider,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _buildPaymentInfoCard(
                              isMobile: isMobile,
                              isCredit: isCredit,
                              isOverdue: isOverdue,
                              languageProvider: languageProvider,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildPaymentSummaryCard(
                            isMobile: isMobile,
                            languageProvider: languageProvider,
                          ),
                          const SizedBox(height: 16),
                          _buildPaymentInfoCard(
                            isMobile: isMobile,
                            isCredit: isCredit,
                            isOverdue: isOverdue,
                            languageProvider: languageProvider,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: _sale!.paymentStatus != 'paid' && _sale!.saleType == 'invoice'
              ? Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _recordPayment,
                      icon: const Icon(Icons.payment),
                      label: Text(languageProvider.isEnglish ? 'Record Payment' : 'ادائیگی ریکارڈ کریں'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCredit ? const Color(0xFF7C3AED) : Colors.green,
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
              : null,
        );
      },
    );
  }

  Widget _buildPaymentSummaryCard({
    required bool isMobile,
    required LanguageProvider languageProvider,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.isEnglish ? 'Payment Summary' : 'ادائیگی کا خلاصہ',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            languageProvider.isEnglish ? 'Subtotal' : 'ذیلی کل',
            _currencyFormat.format(_sale!.subtotal),
            isMobile: isMobile,
            languageProvider: languageProvider,
          ),
          if (_sale!.discountAmount > 0)
            _buildSummaryRow(
              languageProvider.isEnglish
                  ? 'Discount (${_sale!.discountType == 'percent' ? '${_sale!.discountValue}%' : 'Fixed'})'
                  : 'ڈسکاؤنٹ (${_sale!.discountType == 'percent' ? '${_sale!.discountValue}%' : 'مقررہ'})',
              '-${_currencyFormat.format(_sale!.discountAmount)}',
              color: Colors.green,
              isMobile: isMobile,
              languageProvider: languageProvider,
            ),
          _buildSummaryRow(
            languageProvider.isEnglish ? 'Grand Total' : 'کل رقم',
            _currencyFormat.format(_sale!.grandTotal),
            isBold: true,
            isMobile: isMobile,
            languageProvider: languageProvider,
          ),
          const Divider(height: 24),
          _buildSummaryRow(
            languageProvider.isEnglish ? 'Amount Paid' : 'ادا شدہ رقم',
            _currencyFormat.format(_sale!.amountPaid),
            isMobile: isMobile,
            languageProvider: languageProvider,
          ),
          _buildSummaryRow(
            languageProvider.isEnglish ? 'Change' : 'باقی رقم',
            _currencyFormat.format(_sale!.changeAmount),
            color: Colors.green,
            isMobile: isMobile,
            languageProvider: languageProvider,
          ),
          if (_sale!.paymentStatus != 'paid')
            _buildSummaryRow(
              languageProvider.isEnglish ? 'Outstanding' : 'بقایا',
              _currencyFormat.format(_sale!.outstandingBalance),
              color: _sale!.paymentMethod == 'credit' ? const Color(0xFF7C3AED) : Colors.red,
              isBold: true,
              isMobile: isMobile,
              languageProvider: languageProvider,
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoCard({
    required bool isMobile,
    required bool isCredit,
    required bool isOverdue,
    required LanguageProvider languageProvider,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.isEnglish ? 'Payment Info' : 'ادائیگی کی معلومات',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInfoChip(
            label: languageProvider.isEnglish ? 'Method' : 'طریقہ',
            value: _sale!.paymentMethod.toUpperCase(),
            color: isCredit ? const Color(0xFF7C3AED) : Colors.blue,
            languageProvider: languageProvider,
          ),
          const SizedBox(height: 12),
          _buildInfoChip(
            label: languageProvider.isEnglish ? 'Status' : 'حیثیت',
            value: _sale!.paymentStatus.toUpperCase(),
            color: _sale!.statusColor,
            languageProvider: languageProvider,
          ),
          if (isCredit) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              languageProvider.isEnglish ? 'Credit Details' : 'کریڈٹ کی تفصیلات',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.event,
              label: languageProvider.isEnglish ? 'Due Date' : 'آخری تاریخ',
              value: _sale!.dueDate != null
                  ? _dateFormat.format(_sale!.dueDate!)
                  : (languageProvider.isEnglish ? 'Not specified' : 'مخصوص نہیں'),
              isMobile: isMobile,
              languageProvider: languageProvider,
            ),
            if (_sale!.outstandingBalance > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOverdue ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOverdue ? Icons.warning : Icons.info,
                        size: 16,
                        color: isOverdue ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isOverdue
                              ? (languageProvider.isEnglish ? 'Payment is overdue!' : 'ادائیگی واجب الادا ہے!')
                              : (languageProvider.isEnglish ? 'Payment pending' : 'ادائیگی زیر التواء'),
                          style: TextStyle(
                            color: isOverdue ? Colors.red : Colors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 12 : 14,
                            fontFamily: languageProvider.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (_sale!.notes != null && _sale!.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              languageProvider.isEnglish ? 'Notes' : 'نوٹس',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _sale!.notes!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isMobile ? 13 : 14,
                fontFamily: languageProvider.fontFamily,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMobile = false,
    required LanguageProvider languageProvider,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: isMobile ? 14 : 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: Colors.grey[600],
                    fontFamily: languageProvider.fontFamily,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: languageProvider.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
      String label,
      String value, {
        bool isBold = false,
        Color? color,
        bool isMobile = false,
        required LanguageProvider languageProvider,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? (isMobile ? 12 : 14) : (isMobile ? 11 : 13),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isBold ? const Color(0xFF2D3142) : Colors.grey[600]),
              fontFamily: languageProvider.fontFamily,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? (isMobile ? 14 : 16) : (isMobile ? 11 : 13),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? (isBold ? const Color(0xFF7C3AED) : const Color(0xFF2D3142)),
              fontFamily: languageProvider.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required String label,
    required String value,
    required Color color,
    required LanguageProvider languageProvider,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 13,
              fontFamily: languageProvider.fontFamily,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: languageProvider.fontFamily,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Bank Sheet for Payment Dialog
class _PaymentBankSheet extends StatefulWidget {
  final String title;
  final Bank? selected;
  final Color accentColor;

  const _PaymentBankSheet({
    required this.title,
    required this.selected,
    required this.accentColor,
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
      _filteredBanks = pakistaniBanks
          .where((bank) => bank.name.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 20, 12, isMobile ? 16 : 20, 0),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Text(
                widget.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: languageProvider.isEnglish ? 'Search banks...' : 'بینک تلاش کریں...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F5F7),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 2 : 3,
                childAspectRatio: 2.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _filteredBanks.length,
              itemBuilder: (context, index) {
                final bank = _filteredBanks[index];
                final isSelected = widget.selected?.name == bank.name;

                return Card(
                  elevation: isSelected ? 4 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? widget.accentColor : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, {'bank': bank}),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              bank.iconPath,
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: widget.accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.account_balance,
                                  color: widget.accentColor,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bank.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? widget.accentColor : null,
                                fontSize: 12,
                                fontFamily: languageProvider.fontFamily,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, color: widget.accentColor, size: 16),
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
}