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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _discountController = TextEditingController();

  String _selectedType = 'regular';
  double _balance = 0.0;
  bool _isWeb = false;

  List<Map<String, dynamic>> get _customerTypes => [
    {
      'value': 'regular',
      'label': widget.languageProvider.isEnglish ? 'Regular Customer' : 'عام کسٹمر',
      'icon': Icons.person,
      'color': Colors.blue,
    },
    {
      'value': 'retail',
      'label': widget.languageProvider.isEnglish ? 'Retail Customer' : 'خوردہ کسٹمر',
      'icon': Icons.shopping_cart,
      'color': Colors.green,
    },
    {
      'value': 'wholesale',
      'label': widget.languageProvider.isEnglish ? 'Wholesale Customer' : 'تھوک کسٹمر',
      'icon': Icons.business,
      'color': Colors.orange,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      final c = widget.customer!;
      _nameController.text = c.name;
      _contactController.text = c.contact;
      _addressController.text = c.address ?? '';
      _emailController.text = c.email ?? '';
      _selectedType = c.customerType;
      _balance = c.balance;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateResponsiveState();
  }

  void _updateResponsiveState() {
    final width = MediaQuery.of(context).size.width;
    setState(() {
      _isWeb = width >= 600;
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final customerProvider =
      Provider.of<CustomerProvider>(context, listen: false);

      final discountPercent =
          double.tryParse(_discountController.text.trim()) ?? 0.0;

      final result = widget.customer == null
          ? await customerProvider.createCustomer(
        name: _nameController.text.trim(),
        contact: _contactController.text.trim(),
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        customerType: _selectedType,
        balance: _balance,
        discountPercent: discountPercent,
      )
          : await customerProvider.updateCustomer(
        id: widget.customer!.id,
        name: _nameController.text.trim(),
        contact: _contactController.text.trim(),
        address: _addressController.text.trim(),
        email: _emailController.text.trim(),
        customerType: _selectedType,
        balance: _balance,
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

    return _isWeb
        ? _buildWebDialog(context, lp)
        : _buildMobileDialog(context, lp);
  }

  Widget _buildMobileDialog(BuildContext context, LanguageProvider lp) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(lp),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: _buildForm(lp),
              ),
            ),
            const SizedBox(height: 16),
            _buildActions(lp),
          ],
        ),
      ),
    );
  }

  Widget _buildWebDialog(BuildContext context, LanguageProvider lp) {
    return AlertDialog(
      title: _buildHeader(lp),
      content: SingleChildScrollView(
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxWidth: 600),
          child: _buildForm(lp),
        ),
      ),
      actions: _buildWebActions(lp),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    );
  }

  Widget _buildHeader(LanguageProvider lp) {
    final isEdit = widget.customer != null;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isEdit ? Icons.edit : Icons.person_add,
            color: const Color(0xFF7C3AED),
            size: _isWeb ? 22 : 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isEdit
                ? (lp.isEnglish ? 'Edit Customer' : 'کسٹمر میں ترمیم کریں')
                : (lp.isEnglish ? 'Add New Customer' : 'نیا کسٹمر شامل کریں'),
            style: TextStyle(
              fontSize: _isWeb ? 22 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3142),
              fontFamily: lp.fontFamily,
            ),
          ),
        ),
        if (_isWeb)
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Widget _buildForm(LanguageProvider lp) {
    final isEdit = widget.customer != null;
    final discountValue = _discountController.text;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name Field
          _buildTextField(
            controller: _nameController,
            icon: Icons.person,
            label: lp.isEnglish ? 'Customer Name *' : 'کسٹمر کا نام *',
            hint: lp.isEnglish ? 'Enter customer name' : 'کسٹمر کا نام درج کریں',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return lp.isEnglish ? 'Please enter customer name' : 'براہ کرم کسٹمر کا نام درج کریں';
              }
              if (value.length < 2) {
                return lp.isEnglish ? 'Name must be at least 2 characters' : 'نام کم از کم 2 حروف کا ہونا چاہیے';
              }
              return null;
            },
            lp: lp,
            isWeb: _isWeb,
          ),

          const SizedBox(height: 16),

          // Contact Field
          _buildTextField(
            controller: _contactController,
            icon: Icons.phone,
            label: lp.isEnglish ? 'Contact Number *' : 'رابطہ نمبر *',
            hint: lp.isEnglish ? 'Enter contact number' : 'رابطہ نمبر درج کریں',
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
            lp: lp,
            isWeb: _isWeb,
          ),

          const SizedBox(height: 16),

          // Email Field
          _buildTextField(
            controller: _emailController,
            icon: Icons.email,
            label: lp.isEnglish ? 'Email Address' : 'ای میل پتہ',
            hint: lp.isEnglish ? 'Enter email address' : 'ای میل پتہ درج کریں',
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
            lp: lp,
            isWeb: _isWeb,
          ),

          const SizedBox(height: 16),

          // Address Field
          _buildTextField(
            controller: _addressController,
            icon: Icons.location_on,
            label: lp.isEnglish ? 'Address' : 'پتہ',
            hint: lp.isEnglish ? 'Enter address' : 'پتہ درج کریں',
            maxLines: _isWeb ? 2 : 3,
            lp: lp,
            isWeb: _isWeb,
          ),

          const SizedBox(height: 16),

          // Customer Type Dropdown
          _buildTypeDropdown(lp),

          const SizedBox(height: 16),

          // Discount Field
          _buildTextField(
            controller: _discountController,
            icon: Icons.local_offer_outlined,
            label: lp.isEnglish ? 'Default Discount (%)' : 'پہلے سے طے شدہ چھوٹ (%)',
            hint: lp.isEnglish ? 'e.g. 10' : 'مثال: 10',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixText: '%',
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
            filled: discountValue.isNotEmpty &&
                (double.tryParse(discountValue) ?? 0) > 0,
            fillColor: discountValue.isNotEmpty &&
                (double.tryParse(discountValue) ?? 0) > 0
                ? Colors.green.withOpacity(0.05)
                : null,
            onChanged: (_) => setState(() {}),
            lp: lp,
            isWeb: _isWeb,
          ),

          if (!_isWeb) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                lp.isEnglish
                    ? 'This discount auto-applies when creating a sale for this customer.'
                    : 'یہ چھوٹ اس کسٹمر کے لیے فروخت بناتے وقت خود بخود لاگو ہوتی ہے۔',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontFamily: lp.fontFamily,
                ),
              ),
            ),
          ],

          if (isEdit) ...[
            const SizedBox(height: 16),
            _buildTextField(
              initialValue: _balance.toString(),
              icon: Icons.account_balance_wallet,
              label: lp.isEnglish ? 'Balance' : 'بیلنس',
              hint: lp.isEnglish ? 'Enter balance' : 'بیلنس درج کریں',
              keyboardType: TextInputType.number,
              onChanged: (value) => _balance = double.tryParse(value) ?? 0.0,
              lp: lp,
              isWeb: _isWeb,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    IconData? icon,
    required String label,
    required String hint,
    String? initialValue,
    TextInputType? keyboardType,
    int? maxLines,
    String? suffixText,
    String? Function(String?)? validator,
    Function(String)? onChanged,
    bool filled = false,
    Color? fillColor,
    required LanguageProvider lp,
    required bool isWeb,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      style: TextStyle(
        fontSize: isWeb ? 15 : 14,
        fontFamily: lp.fontFamily,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: isWeb ? 14 : 13,
          color: Colors.grey[400],
          fontFamily: lp.fontFamily,
        ),
        prefixIcon: icon != null ? Icon(icon, size: isWeb ? 22 : 20) : null,
        suffixText: suffixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: filled,
        fillColor: fillColor,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isWeb ? 16 : 14,
          vertical: isWeb ? 16 : 14,
        ),
        labelStyle: TextStyle(
          fontSize: isWeb ? 14 : 13,
          fontFamily: lp.fontFamily,
        ),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _buildTypeDropdown(LanguageProvider lp) {
    return DropdownButtonFormField<String>(
      value: _selectedType,
      decoration: InputDecoration(
        labelText: lp.isEnglish ? 'Customer Type' : 'کسٹمر کی قسم',
        prefixIcon: const Icon(Icons.category),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_isWeb ? 12 : 10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_isWeb ? 12 : 10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_isWeb ? 12 : 10),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: _isWeb ? 16 : 14,
          vertical: _isWeb ? 16 : 14,
        ),
        labelStyle: TextStyle(
          fontSize: _isWeb ? 14 : 13,
          fontFamily: lp.fontFamily,
          color: Colors.black, // 👈 added
        ),
      ),

      items: _customerTypes.map((type) {
        return DropdownMenuItem(
          value: type['value'] as String,
          child: Row(
            children: [
              Icon(
                type['icon'] as IconData,
                color: type['color'] as Color,
                size: _isWeb ? 20 : 18,
              ),
              const SizedBox(width: 10),
              Text(
                type['label'] as String,
                style: TextStyle(
                  fontSize: _isWeb ? 14 : 13,
                  fontFamily: lp.fontFamily,
                  color: Colors.black, // 👈 added
                ),
              ),
            ],
          ),
        );
      }).toList(),

      onChanged: (value) => setState(() => _selectedType = value!),

      style: TextStyle(
        fontSize: _isWeb ? 14 : 13,
        fontFamily: lp.fontFamily,
        color: Colors.black, // 👈 added (selected value color)
      ),
    );
  }

  Widget _buildActions(LanguageProvider lp) {
    final isEdit = widget.customer != null;
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              lp.isEnglish ? 'Cancel' : 'منسوخ کریں',
              style: TextStyle(
                fontSize: 14,
                fontFamily: lp.fontFamily,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            child: Text(
              isEdit
                  ? (lp.isEnglish ? 'Update' : 'اپ ڈیٹ کریں')
                  : (lp.isEnglish ? 'Add Customer' : 'کسٹمر شامل کریں'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: lp.fontFamily,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildWebActions(LanguageProvider lp) {
    final isEdit = widget.customer != null;
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          lp.isEnglish ? 'Cancel' : 'منسوخ کریں',
          style: TextStyle(
            fontSize: 14,
            fontFamily: lp.fontFamily,
          ),
        ),
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
        child: Text(
          isEdit
              ? (lp.isEnglish ? 'Update Customer' : 'کسٹمر اپ ڈیٹ کریں')
              : (lp.isEnglish ? 'Add Customer' : 'کسٹمر شامل کریں'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: lp.fontFamily,
          ),
        ),
      ),
    ];
  }
}