// lib/screens/customers/customer_adjustment_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../config/api_config.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../providers/lanprovider.dart';

class CustomerAdjustmentDialog extends StatefulWidget {
  final Customer customer;
  final LanguageProvider languageProvider;

  const CustomerAdjustmentDialog({
    super.key,
    required this.customer,
    required this.languageProvider,
  });

  @override
  State<CustomerAdjustmentDialog> createState() => _CustomerAdjustmentDialogState();
}

class _CustomerAdjustmentDialogState extends State<CustomerAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();

  String _adjustmentType = 'debit';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final _currencyFormat = NumberFormat('#,##0.00');
  final _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  String? _getToken() {
    try {
      return Provider.of<AuthProvider>(context, listen: false).user?.token;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitAdjustment() async {
    final lp = widget.languageProvider;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final amount = double.tryParse(_amountController.text) ?? 0;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/customers/${widget.customer.id}/adjustments'),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
        body: json.encode({
          'type': _adjustmentType,
          'amount': amount,
          'description': _descriptionController.text.trim(),
          'reference_number': _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          'adjustment_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          Navigator.pop(context, true);
        } else {
          _showError(data['message'] ?? (lp.isEnglish ? 'Failed to record adjustment' : 'ایڈجسٹمنٹ ریکارڈ کرنے میں ناکامی'));
        }
      } else {
        _showError('${lp.isEnglish ? 'Server error' : 'سرور خرابی'}: ${response.statusCode}');
      }
    } catch (e) {
      _showError('${lp.isEnglish ? 'Error' : 'خرابی'}: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lp = widget.languageProvider;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.swap_horiz,
                        color: Color(0xFF7C3AED),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lp.isEnglish ? 'Adjust Balance' : 'بیلنس ایڈجسٹ کریں',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.customer.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Current Balance
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lp.isEnglish ? 'Current Balance' : 'موجودہ بیلنس',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.customer.formattedBalance,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: widget.customer.balance > 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                          fontFamily: lp.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Adjustment Type
                Text(
                  lp.isEnglish ? 'Adjustment Type *' : 'ایڈجسٹمنٹ کی قسم *',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _adjustmentType = 'debit'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _adjustmentType == 'debit'
                                ? const Color(0xFFEF4444).withOpacity(0.1)
                                : const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _adjustmentType == 'debit'
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFE5E5EA),
                              width: _adjustmentType == 'debit' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: _adjustmentType == 'debit'
                                    ? const Color(0xFFEF4444)
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lp.isEnglish ? 'Charge' : 'چارج',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _adjustmentType == 'debit' ? FontWeight.bold : FontWeight.normal,
                                  color: _adjustmentType == 'debit'
                                      ? const Color(0xFFEF4444)
                                      : Colors.grey,
                                  fontFamily: lp.fontFamily,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lp.isEnglish ? '(Increase debit)' : '(ڈیبٹ بڑھائیں)',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _adjustmentType == 'debit'
                                      ? const Color(0xFFEF4444).withOpacity(0.7)
                                      : Colors.grey[400],
                                  fontFamily: lp.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _adjustmentType = 'credit'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _adjustmentType == 'credit'
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _adjustmentType == 'credit'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFE5E5EA),
                              width: _adjustmentType == 'credit' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.remove_circle_outline,
                                color: _adjustmentType == 'credit'
                                    ? const Color(0xFF10B981)
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lp.isEnglish ? 'Refund/Credit' : 'ریفنڈ/کریڈٹ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _adjustmentType == 'credit' ? FontWeight.bold : FontWeight.normal,
                                  color: _adjustmentType == 'credit'
                                      ? const Color(0xFF10B981)
                                      : Colors.grey,
                                  fontFamily: lp.fontFamily,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lp.isEnglish ? '(Decrease debit)' : '(ڈیبٹ کم کریں)',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _adjustmentType == 'credit'
                                      ? const Color(0xFF10B981).withOpacity(0.7)
                                      : Colors.grey[400],
                                  fontFamily: lp.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Amount Field
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    labelText: lp.isEnglish ? 'Amount *' : 'رقم *',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return lp.isEnglish ? 'Please enter amount' : 'براہ کرم رقم درج کریں';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return lp.isEnglish ? 'Please enter a valid amount' : 'براہ کرم ایک درست رقم درج کریں';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  style: TextStyle(fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    labelText: lp.isEnglish ? 'Description *' : 'تفصیل *',
                    hintText: lp.isEnglish
                        ? 'e.g. Opening balance, adjustment, discount...'
                        : 'مثال: ابتدائی بیلنس، ایڈجسٹمنٹ، چھوٹ...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return lp.isEnglish ? 'Please enter description' : 'براہ کرم تفصیل درج کریں';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Adjustment Date
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF7C3AED),
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 18, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 10),
                        Text(
                          '${lp.isEnglish ? 'Adjustment Date' : 'ایڈجسٹمنٹ کی تاریخ'}: ${_dateFormat.format(_selectedDate)}',
                          style: TextStyle(fontSize: 14, fontFamily: lp.fontFamily),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Reference Number
                TextFormField(
                  controller: _referenceController,
                  style: TextStyle(fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    labelText: lp.isEnglish ? 'Reference Number (Optional)' : 'حوالہ نمبر (اختیاری)',
                    hintText: lp.isEnglish ? 'e.g. ADJ-001' : 'مثال: ADJ-001',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(lp.isEnglish ? 'Cancel' : 'منسوخ کریں',
                            style: TextStyle(fontFamily: lp.fontFamily)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitAdjustment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Text(lp.isEnglish ? 'Save Adjustment' : 'ایڈجسٹمنٹ محفوظ کریں',
                            style: TextStyle(fontFamily: lp.fontFamily)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}