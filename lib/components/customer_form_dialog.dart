// lib/components/customer_form_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';
import '../providers/lanprovider.dart';

class CustomerFormDialog extends StatefulWidget {
  final Customer? customer;
  final LanguageProvider languageProvider;

  const CustomerFormDialog({
    Key? key,
    this.customer,
    required this.languageProvider,
  }) : super(key: key);

  @override
  _CustomerFormDialogState createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey        = GlobalKey<FormState>();
  final _nameController    = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController   = TextEditingController();
  final _discountController = TextEditingController();

  String _selectedType = 'regular';
  double _balance      = 0.0;

  List<Map<String, dynamic>> get _customerTypes => [
    {'value': 'regular', 'label': widget.languageProvider.isEnglish ? 'Regular Customer' : 'عام کسٹمر', 'icon': Icons.person, 'color': Colors.blue},
    {'value': 'retail',  'label': widget.languageProvider.isEnglish ? 'Retail Customer' : 'خوردہ کسٹمر',  'icon': Icons.shopping_cart, 'color': Colors.green},
    {'value': 'wholesale','label': widget.languageProvider.isEnglish ? 'Wholesale Customer' : 'تھوک کسٹمر', 'icon': Icons.business, 'color': Colors.orange},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      final c = widget.customer!;
      _nameController.text    = c.name;
      _contactController.text = c.contact;
      _addressController.text = c.address ?? '';
      _emailController.text   = c.email   ?? '';
      _selectedType           = c.customerType;
      _balance                = c.balance;
      _discountController.text = c.discountPercent == 0
          ? ''
          : c.discountPercent % 1 == 0
          ? c.discountPercent.toInt().toString()
          : c.discountPercent.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final customerProvider =
      Provider.of<CustomerProvider>(context, listen: false);

      final discountPercent =
          double.tryParse(_discountController.text.trim()) ?? 0.0;

      final result = widget.customer == null
          ? await customerProvider.createCustomer(
        name:            _nameController.text.trim(),
        contact:         _contactController.text.trim(),
        address:         _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        email:           _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        customerType:    _selectedType,
        balance:         _balance,
        discountPercent: discountPercent,
      )
          : await customerProvider.updateCustomer(
        id:              widget.customer!.id,
        name:            _nameController.text.trim(),
        contact:         _contactController.text.trim(),
        address:         _addressController.text.trim(),
        email:           _emailController.text.trim(),
        customerType:    _selectedType,
        balance:         _balance,
        discountPercent: discountPercent,
      );

      if (result['success'] == true) {
        Navigator.of(context).pop(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = widget.languageProvider;

    return AlertDialog(
      title: Text(
        widget.customer == null
            ? (lp.isEnglish ? 'Add New Customer' : 'نیا کسٹمر شامل کریں')
            : (lp.isEnglish ? 'Edit Customer' : 'کسٹمر میں ترمیم کریں'),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3142),
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: TextStyle(fontFamily: lp.fontFamily),
                decoration: InputDecoration(
                  labelText: lp.isEnglish ? 'Customer Name *' : 'کسٹمر کا نام *',
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return lp.isEnglish ? 'Please enter customer name' : 'براہ کرم کسٹمر کا نام درج کریں';
                  }
                  if (value.length < 2) {
                    return lp.isEnglish ? 'Name must be at least 2 characters' : 'نام کم از کم 2 حروف کا ہونا چاہیے';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _contactController,
                style: TextStyle(fontFamily: lp.fontFamily),
                decoration: InputDecoration(
                  labelText: lp.isEnglish ? 'Contact Number *' : 'رابطہ نمبر *',
                  prefixIcon: const Icon(Icons.phone),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return lp.isEnglish ? 'Please enter contact number' : 'براہ کرم رابطہ نمبر درج کریں';
                  }
                  if (value.length < 10) {
                    return lp.isEnglish ? 'Enter a valid contact number' : 'ایک درست رابطہ نمبر درج کریں';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                style: TextStyle(fontFamily: lp.fontFamily),
                decoration: InputDecoration(
                  labelText: lp.isEnglish ? 'Email Address' : 'ای میل پتہ',
                  prefixIcon: const Icon(Icons.email),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final emailRegex = RegExp(
                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                    if (!emailRegex.hasMatch(value)) {
                      return lp.isEnglish ? 'Enter a valid email address' : 'ایک درست ای میل پتہ درج کریں';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                style: TextStyle(fontFamily: lp.fontFamily),
                decoration: InputDecoration(
                  labelText: lp.isEnglish ? 'Address' : 'پتہ',
                  prefixIcon: const Icon(Icons.location_on),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: lp.isEnglish ? 'Customer Type' : 'کسٹمر کی قسم',
                  prefixIcon: const Icon(Icons.category),
                  border: const OutlineInputBorder(),
                ),
                items: _customerTypes.map((type) {
                  return DropdownMenuItem(
                    value: type['value'] as String,
                    child: Row(
                      children: [
                        Icon(type['icon'] as IconData, color: type['color'] as Color),
                        const SizedBox(width: 8),
                        Text(type['label'] as String,
                            style: TextStyle(fontFamily: lp.fontFamily)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedType = value!),
                style: TextStyle(fontFamily: lp.fontFamily),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _discountController,
                style: TextStyle(fontFamily: lp.fontFamily),
                decoration: InputDecoration(
                  labelText: lp.isEnglish ? 'Default Discount (%)' : 'پہلے سے طے شدہ چھوٹ (%)',
                  hintText: lp.isEnglish ? 'e.g. 10  →  10% off every sale' : 'مثال: 10  →  ہر فروخت پر 10% چھوٹ',
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                  suffixText: '%',
                  border: const OutlineInputBorder(),
                  fillColor: _discountController.text.isNotEmpty &&
                      (double.tryParse(_discountController.text) ?? 0) > 0
                      ? Colors.green.withOpacity(0.05)
                      : null,
                  filled: _discountController.text.isNotEmpty &&
                      (double.tryParse(_discountController.text) ?? 0) > 0,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final parsed = double.tryParse(value);
                    if (parsed == null) {
                      return lp.isEnglish ? 'Enter a valid number' : 'ایک درست نمبر درج کریں';
                    }
                    if (parsed < 0) {
                      return lp.isEnglish ? 'Discount cannot be negative' : 'چھوٹ منفی نہیں ہو سکتی';
                    }
                    if (parsed > 100) {
                      return lp.isEnglish ? 'Discount cannot exceed 100%' : 'چھوٹ 100% سے زیادہ نہیں ہو سکتی';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  lp.isEnglish
                      ? 'This discount auto-applies when creating a sale for this customer.'
                      : 'یہ چھوٹ اس کسٹمر کے لیے فروخت بناتے وقت خود بخود لاگو ہوتی ہے۔',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontFamily: lp.fontFamily),
                ),
              ),

              if (widget.customer != null) ...[
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _balance.toString(),
                  style: TextStyle(fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    labelText: lp.isEnglish ? 'Balance' : 'بیلنس',
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _balance = double.tryParse(value) ?? 0.0,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(lp.isEnglish ? 'Cancel' : 'منسوخ کریں'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
          ),
          child: Text(widget.customer == null
              ? (lp.isEnglish ? 'Add Customer' : 'کسٹمر شامل کریں')
              : (lp.isEnglish ? 'Update' : 'اپ ڈیٹ کریں')),
        ),
      ],
    );
  }
}