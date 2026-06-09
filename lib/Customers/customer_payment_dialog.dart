// lib/screens/customers/customer_payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../config/api_config.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../Banks/banknames.dart';
import '../components/bankpicker.dart';
import '../providers/lanprovider.dart';

class CustomerPaymentDialog extends StatefulWidget {
  final Customer customer;
  final LanguageProvider languageProvider;

  const CustomerPaymentDialog({
    super.key,
    required this.customer,
    required this.languageProvider,
  });

  @override
  State<CustomerPaymentDialog> createState() => _CustomerPaymentDialogState();
}

class _CustomerPaymentDialogState extends State<CustomerPaymentDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _chequeNumCtrl = TextEditingController();

  String _paymentMethod = 'cash';
  int? _selectedBankId;
  String? _selectedBankName;
  String? _selectedBankIcon;

  DateTime _paymentDate = DateTime.now();
  DateTime? _chequeDate;
  bool _isLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final _df = DateFormat('MMM dd, yyyy');

  static const _methodColors = {
    'cash': Color(0xFF10B981),
    'bank': Color(0xFF3B82F6),
    'cheque': Color(0xFFF59E0B),
    'slip': Color(0xFF8B5CF6),
  };

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    _chequeNumCtrl.dispose();
    super.dispose();
  }

  Color get _activeColor => _methodColors[_paymentMethod] ?? const Color(0xFF10B981);

  List<Map<String, dynamic>> _getMethods(LanguageProvider lp) => [
    {'value': 'cash',   'label': lp.isEnglish ? 'Cash' : 'نقد',   'icon': Icons.payments_outlined},
    {'value': 'bank',   'label': lp.isEnglish ? 'Bank' : 'بینک',   'icon': Icons.account_balance_outlined},
    {'value': 'cheque', 'label': lp.isEnglish ? 'Cheque' : 'چیک',   'icon': Icons.receipt_long_outlined},
    {'value': 'slip',   'label': lp.isEnglish ? 'Slip' : 'سلیپ',   'icon': Icons.receipt_outlined},
  ];

  String? _getToken() {
    try {
      return Provider.of<AuthProvider>(context, listen: false).user?.token;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    final lp = widget.languageProvider;

    if (!_formKey.currentState!.validate()) return;

    if ((_paymentMethod == 'bank' || _paymentMethod == 'cheque') &&
        _selectedBankName == null) {
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
      final description = _descCtrl.text.trim();
      final referenceNumber = _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim();

      int? chequeId;
      if (_paymentMethod == 'cheque') {
        final chequeResponse = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/cheques'),
          headers: {
            'Content-Type': 'application/json',
            if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
          },
          body: json.encode({
            'bank_id': _selectedBankId,
            'cheque_number': _chequeNumCtrl.text.trim(),
            'cheque_type': 'received',
            'amount': amount,
            'payee_payer_name': widget.customer.name,
            'description': description.isEmpty
                ? 'Payment received from customer: ${widget.customer.name}'
                : description,
            'issue_date': DateFormat('yyyy-MM-dd').format(_chequeDate ?? _paymentDate),
            'due_date': _chequeDate != null
                ? DateFormat('yyyy-MM-dd').format(_chequeDate!)
                : null,
          }),
        );

        final chequeData = json.decode(chequeResponse.body);

        if (chequeResponse.statusCode == 201 && chequeData['success'] == true) {
          chequeId = chequeData['data']['id'];
          debugPrint('Cheque created with ID: $chequeId');
        } else {
          _err(chequeData['message'] ?? (lp.isEnglish ? 'Failed to create cheque record' : 'چیک ریکارڈ بنانے میں ناکامی'));
          setState(() => _isLoading = false);
          return;
        }
      }

      final paymentResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/customers/${widget.customer.id}/payments'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
        body: json.encode({
          'amount': amount,
          'payment_method': _paymentMethod,
          'bank_id': _selectedBankId,
          'bank_name': _selectedBankName,
          'cheque_number': _paymentMethod == 'cheque' ? _chequeNumCtrl.text.trim() : null,
          'cheque_id': chequeId,
          'cheque_date': _chequeDate != null
              ? "${_chequeDate!.year}-${_chequeDate!.month.toString().padLeft(2, '0')}-${_chequeDate!.day.toString().padLeft(2, '0')}"
              : null,
          'transaction_date': "${_paymentDate.year}-${_paymentDate.month.toString().padLeft(2, '0')}-${_paymentDate.day.toString().padLeft(2, '0')}",
          'reference_number': referenceNumber,
          'description': description.isEmpty ? null : description,
        }),
      );

      final paymentData = json.decode(paymentResponse.body);

      if (paymentResponse.statusCode == 201 && paymentData['success'] == true) {
        if (mounted) {
          Navigator.pop(context, true);

          String successMessage = lp.isEnglish
              ? 'Payment recorded successfully!\nAmount: Rs ${amount.toStringAsFixed(2)}\nMethod: ${_paymentMethod.toUpperCase()}'
              : 'ادائیگی کامیابی سے ریکارڈ ہوگئی!\nرقم: Rs ${amount.toStringAsFixed(2)}\nطریقہ: ${_getMethodLabel(_paymentMethod, lp)}';

          if (_paymentMethod == 'cheque') {
            successMessage += lp.isEnglish
                ? '\nCheque #${_chequeNumCtrl.text.trim()} created\nStatus: Pending (awaiting clearing)'
                : '\nچیک نمبر #${_chequeNumCtrl.text.trim()} بن گیا\nحالت: زیر التواء (کلئیرنگ کے انتظار میں)';
          }

          if (_selectedBankName != null) {
            successMessage += lp.isEnglish
                ? '\nBank: $_selectedBankName'
                : '\nبینک: $_selectedBankName';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (chequeId != null) {
          await http.delete(
            Uri.parse('${ApiConfig.baseUrl}/cheques/$chequeId'),
            headers: {
              'Content-Type': 'application/json',
              if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
            },
          );
        }
        _err(paymentData['message'] ?? (lp.isEnglish ? 'Failed to record payment' : 'ادائیگی ریکارڈ کرنے میں ناکامی'));
      }
    } catch (e) {
      _err('${lp.isEnglish ? 'Error' : 'خرابی'}: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  String _getMethodLabel(String method, LanguageProvider lp) {
    if (lp.isEnglish) {
      const labels = {'cash': 'Cash', 'bank': 'Bank', 'cheque': 'Cheque', 'slip': 'Slip'};
      return labels[method] ?? method;
    } else {
      const labels = {'cash': 'نقد', 'bank': 'بینک', 'cheque': 'چیک', 'slip': 'سلیپ'};
      return labels[method] ?? method;
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ),
  );

  Future<void> _pickPaymentDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: _dpTheme,
    );
    if (p != null) setState(() => _paymentDate = p);
  }

  Future<void> _pickChequeDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _chequeDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: _dpTheme,
    );
    if (p != null) setState(() => _chequeDate = p);
  }

  Widget Function(BuildContext, Widget?) get _dpTheme => (ctx, child) => Theme(
    data: Theme.of(ctx).copyWith(
        colorScheme: ColorScheme.light(primary: _activeColor)),
    child: child!,
  );

  Future<void> _openBankPicker() async {
    final lp = widget.languageProvider;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DbBankSheet(
        accentColor: _activeColor,
        token: _getToken(),
        languageProvider: lp,
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

  @override
  Widget build(BuildContext context) {
    final lp = widget.languageProvider;
    final outstandingBalance = widget.customer.balance;
    final methods = _getMethods(lp);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(outstandingBalance, lp),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAmountField(lp),
                      const SizedBox(height: 20),
                      _buildMethodSelector(lp, methods),
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
                                    decoration: _inp(hint: lp.isEnglish ? 'e.g. 001234' : 'مثال: 001234', lp: lp),
                                    validator: (v) {
                                      if (_paymentMethod == 'cheque' && (v == null || v.isEmpty)) {
                                        return lp.isEnglish ? 'Required' : 'ضروری';
                                      }
                                      return null;
                                    },
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
                                  _dateTile(
                                    val: _chequeDate != null
                                        ? _df.format(_chequeDate!)
                                        : (lp.isEnglish ? 'Pick date' : 'تاریخ منتخب کریں'),
                                    filled: _chequeDate != null,
                                    onTap: _pickChequeDate,
                                    lp: lp,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: const Color(0xFFF59E0B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lp.isEnglish
                                      ? 'Cheque will be recorded as "pending" in Cheque Management. Update status to "cleared" when cashed.'
                                      : 'چیک "زیر التواء" کے طور پر چیک مینجمنٹ میں ریکارڈ کیا جائے گا۔ کیش ہونے پر حالت "کلئیر شدہ" میں تبدیل کریں۔',
                                  style: TextStyle(fontSize: 11, color: const Color(0xFFF59E0B),
                                      fontFamily: lp.fontFamily),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      _lbl(lp.isEnglish ? 'Reference # (optional)' : 'حوالہ نمبر (اختیاری)', lp),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _refCtrl,
                        style: TextStyle(fontFamily: lp.fontFamily),
                        decoration: _inp(hint: lp.isEnglish ? 'e.g. TXN-001, CHQ-123' : 'مثال: TXN-001, CHQ-123', lp: lp),
                      ),
                      const SizedBox(height: 16),

                      _lbl(lp.isEnglish ? 'Description (optional)' : 'تفصیل (اختیاری)', lp),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 2,
                        style: TextStyle(fontFamily: lp.fontFamily),
                        decoration: _inp(hint: lp.isEnglish ? 'e.g. Payment received for goods' : 'مثال: سامان کی وصول کردہ ادائیگی', lp: lp),
                      ),
                      const SizedBox(height: 16),

                      _lbl(lp.isEnglish ? 'Payment Date' : 'ادائیگی کی تاریخ', lp),
                      const SizedBox(height: 6),
                      _dateTile(
                        val: _df.format(_paymentDate),
                        filled: true,
                        onTap: _pickPaymentDate,
                        icon: Icons.calendar_today_outlined,
                        lp: lp,
                      ),
                      const SizedBox(height: 24),
                      _buildSubmitBtn(lp),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double outstandingBalance, LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      decoration: BoxDecoration(
        color: _activeColor.withOpacity(0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
            bottom: BorderSide(color: _activeColor.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _activeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.payments_outlined,
                color: _activeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lp.isEnglish ? 'Record Payment' : 'ادائیگی ریکارڈ کریں',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                Text(widget.customer.name,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8E8E93))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: outstandingBalance > 0
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${lp.isEnglish ? 'Due' : 'بقایا'}: Rs ${NumberFormat('#,##0.00').format(outstandingBalance)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: outstandingBalance > 0
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
                fontFamily: lp.fontFamily,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildAmountField(LanguageProvider lp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lbl(lp.isEnglish ? 'Amount *' : 'رقم *', lp),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _activeColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _activeColor.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('Rs',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _activeColor)),
              ),
              Container(
                  width: 1, height: 40, color: _activeColor.withOpacity(0.2)),
              Expanded(
                child: TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold,
                      fontFamily: lp.fontFamily),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                        color: Color(0xFFC7C7CC),
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                    border: InputBorder.none,
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return lp.isEnglish ? 'Amount required' : 'رقم ضروری ہے';
                    if ((double.tryParse(v) ?? 0) <= 0) return lp.isEnglish ? 'Enter valid amount' : 'درست رقم درج کریں';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMethodSelector(LanguageProvider lp, List<Map<String, dynamic>> methods) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lbl(lp.isEnglish ? 'Payment Method *' : 'ادائیگی کا طریقہ *', lp),
        const SizedBox(height: 8),
        Row(
          children: methods.map((m) {
            final val = m['value'] as String;
            final selected = _paymentMethod == val;
            final col = _methodColors[val]!;
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? col.withOpacity(0.1)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selected ? col : const Color(0xFFE5E5EA),
                        width: selected ? 2 : 1),
                  ),
                  child: Column(children: [
                    Icon(m['icon'] as IconData,
                        size: 22,
                        color: selected ? col : const Color(0xFF8E8E93)),
                    const SizedBox(height: 5),
                    Text(m['label'] as String,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: selected ? col : const Color(0xFF8E8E93),
                            fontFamily: lp.fontFamily)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

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
          border: Border.all(
            color: hasBank ? _activeColor.withOpacity(0.4) : const Color(0xFFE5E5EA),
          ),
        ),
        child: Row(
          children: [
            if (hasBank) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  _selectedBankIcon ?? '',
                  width: 32, height: 32, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                      Icons.account_balance, size: 28, color: _activeColor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_selectedBankName!,
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500, color: const Color(0xFF1C1C1E),
                        fontFamily: lp.fontFamily)),
              ),
              Icon(Icons.check_circle_rounded, color: _activeColor, size: 18),
            ] else ...[
              Icon(Icons.account_balance_outlined, size: 20, color: Colors.grey[400]),
              const SizedBox(width: 10),
              Expanded(child: Text(lp.isEnglish ? 'Select bank' : 'بینک منتخب کریں',
                  style: TextStyle(fontSize: 14, color: const Color(0xFFC7C7CC),
                      fontFamily: lp.fontFamily))),
              Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey[400]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitBtn(LanguageProvider lp) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              _activeColor,
              _activeColor.withOpacity(0.75),
            ],
          ),
          boxShadow: [
            BoxShadow(
                color: _activeColor.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                lp.isEnglish ? 'Confirm Payment' : 'ادائیگی کی تصدیق کریں',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTile({
    required String val,
    required bool filled,
    required VoidCallback onTap,
    IconData icon = Icons.calendar_today_outlined,
    required LanguageProvider lp,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: filled
                ? _activeColor.withOpacity(0.05)
                : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: filled
                    ? _activeColor.withOpacity(0.3)
                    : const Color(0xFFE5E5EA)),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color: filled ? _activeColor : Colors.grey[400]),
              const SizedBox(width: 8),
              Text(val,
                  style: TextStyle(
                      fontSize: 13,
                      color: filled
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFFC7C7CC),
                      fontFamily: lp.fontFamily)),
            ],
          ),
        ),
      );

  Widget _lbl(String t, LanguageProvider lp) => Text(t,
      style: TextStyle(
          fontSize: 12,
          color: const Color(0xFF8E8E93),
          fontWeight: FontWeight.w600,
          fontFamily: lp.fontFamily));

  InputDecoration _inp({required String hint, required LanguageProvider lp}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: const Color(0xFFC7C7CC), fontSize: 13, fontFamily: lp.fontFamily),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    filled: true,
    fillColor: const Color(0xFFF5F5F7),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _activeColor, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
  );
}