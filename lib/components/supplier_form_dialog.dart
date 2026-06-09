import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/supplier.dart';
import '../providers/lanprovider.dart';
import '../providers/supplier_provider.dart';

class SupplierFormDialog extends StatefulWidget {
  final Supplier? supplier;
  final LanguageProvider languageProvider;

  const SupplierFormDialog({Key? key, this.supplier, required this.languageProvider}) : super(key: key);

  @override
  State<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _discountController = TextEditingController();
  bool _isActive = true;

  LanguageProvider get lp => widget.languageProvider;

  @override
  void initState() {
    super.initState();
    if (widget.supplier != null) {
      _nameController.text = widget.supplier!.name;
      _contactController.text = widget.supplier!.contact;
      _addressController.text = widget.supplier!.address ?? '';
      _isActive = widget.supplier!.isActive;
      _discountController.text = (widget.supplier?.discountPercent ?? 0).toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);

      Map<String, dynamic> result;

      if (widget.supplier == null) {
        result = await supplierProvider.createSupplier(
          context: context,
          name: _nameController.text.trim(),
          contact: _contactController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          discountPercent: double.tryParse(_discountController.text) ?? 0,
        );
      } else {
        result = await supplierProvider.updateSupplier(
          context: context,
          id: widget.supplier!.id,
          name: _nameController.text.trim(),
          contact: _contactController.text.trim(),
          address: _addressController.text.trim(),
          isActive: _isActive,
          discountPercent: double.tryParse(_discountController.text) ?? 0,
        );
      }

      if (result['success']) {
        Navigator.pop(context, result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'], style: TextStyle(fontFamily: lp.fontFamily)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.supplier == null
                        ? (lp.isEnglish ? 'Add New Supplier' : 'نیا سپلائر شامل کریں')
                        : (lp.isEnglish ? 'Edit Supplier' : 'سپلائر میں ترمیم کریں'),
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3142),
                      fontFamily: lp.fontFamily,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                style: TextStyle(fontFamily: lp.fontFamily),
                decoration: InputDecoration(
                  labelText: lp.isEnglish ? 'Supplier Name' : 'سپلائر کا نام',
                  hintText: lp.isEnglish ? 'Enter supplier name' : 'سپلائر کا نام درج کریں',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return lp.isEnglish ? 'Supplier name is required' : 'سپلائر کا نام ضروری ہے';
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
                  labelText: lp.isEnglish ? 'Contact' : 'رابطہ',
                  hintText: lp.isEnglish ? 'Enter contact information' : 'رابطہ کی معلومات درج کریں',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return lp.isEnglish ? 'Contact information is required' : 'رابطہ کی معلومات ضروری ہیں';
                  }
                  if (value.length < 2) {
                    return lp.isEnglish ? 'Contact must be at least 2 characters' : 'رابطہ کم از کم 2 حروف کا ہونا چاہیے';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                style: TextStyle(fontFamily: lp.fontFamily),
                decoration: InputDecoration(
                  labelText: lp.isEnglish ? 'Address (Optional)' : 'پتہ (اختیاری)',
                  hintText: lp.isEnglish ? 'Enter supplier address' : 'سپلائر کا پتہ درج کریں',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 3,
                minLines: 2,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontFamily: lp.fontFamily),
                decoration: InputDecoration(
                  labelText: lp.isEnglish ? 'Discount (%)' : 'چھوٹ (%)',
                  hintText: lp.isEnglish ? 'e.g. 10' : 'مثال: 10',
                  prefixIcon: const Icon(Icons.discount_outlined),
                  suffixText: '%',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  final v = double.tryParse(value ?? '');
                  if (v == null) return lp.isEnglish ? 'Enter a valid number' : 'درست نمبر درج کریں';
                  if (v < 0 || v > 100) return lp.isEnglish ? 'Must be between 0 and 100' : '0 اور 100 کے درمیان ہونا چاہیے';
                  return null;
                },
              ),

              if (widget.supplier != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Switch(
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                      activeColor: const Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isActive
                          ? (lp.isEnglish ? 'Active' : 'فعال')
                          : (lp.isEnglish ? 'Inactive' : 'غیر فعال'),
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500,
                        color: _isActive ? Colors.green : Colors.grey,
                        fontFamily: lp.fontFamily,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    widget.supplier == null
                        ? (lp.isEnglish ? 'Create Supplier' : 'سپلائر بنائیں')
                        : (lp.isEnglish ? 'Update Supplier' : 'سپلائر اپ ڈیٹ کریں'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: lp.fontFamily),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}