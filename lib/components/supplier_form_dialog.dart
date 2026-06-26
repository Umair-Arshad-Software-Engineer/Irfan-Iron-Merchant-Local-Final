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
  bool _isLoading = false;

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
      setState(() => _isLoading = true);

      try {
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

        if (mounted) {
          if (result['success']) {
            Navigator.pop(context, result);
          } else {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'], style: TextStyle(fontFamily: lp.fontFamily)),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lp.isEnglish ? 'An error occurred. Please try again.' : 'ایک خرابی پیش آگئی۔ براہ کرم دوبارہ کوشش کریں۔',
                style: TextStyle(fontFamily: lp.fontFamily),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 1024;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(isWeb ? 32.0 : 24.0),
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: isWeb ? 700 : double.infinity,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                        fontSize: isWeb ? 22.0 : 20.0,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D3142),
                        fontFamily: lp.fontFamily,
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: lp.isEnglish ? 'Close' : 'بند کریں',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  enabled: !_isLoading,
                  style: TextStyle(fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    labelText: lp.isEnglish ? 'Supplier Name' : 'سپلائر کا نام',
                    hintText: lp.isEnglish ? 'Enter supplier name' : 'سپلائر کا نام درج کریں',
                    prefixIcon: const Icon(Icons.business),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
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
                  enabled: !_isLoading,
                  style: TextStyle(fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    labelText: lp.isEnglish ? 'Contact' : 'رابطہ',
                    hintText: lp.isEnglish ? 'Enter contact information' : 'رابطہ کی معلومات درج کریں',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
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
                  enabled: !_isLoading,
                  style: TextStyle(fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    labelText: lp.isEnglish ? 'Address (Optional)' : 'پتہ (اختیاری)',
                    hintText: lp.isEnglish ? 'Enter supplier address' : 'سپلائر کا پتہ درج کریں',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _discountController,
                  enabled: !_isLoading,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    labelText: lp.isEnglish ? 'Discount (%)' : 'چھوٹ (%)',
                    hintText: lp.isEnglish ? 'e.g. 10' : 'مثال: 10',
                    prefixIcon: const Icon(Icons.discount_outlined),
                    suffixText: '%',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return null; // Optional field
                    }
                    final v = double.tryParse(value);
                    if (v == null) {
                      return lp.isEnglish ? 'Enter a valid number' : 'درست نمبر درج کریں';
                    }
                    if (v < 0 || v > 100) {
                      return lp.isEnglish ? 'Must be between 0 and 100' : '0 اور 100 کے درمیان ہونا چاہیے';
                    }
                    return null;
                  },
                ),

                if (widget.supplier != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Switch(
                          value: _isActive,
                          onChanged: _isLoading ? null : (value) => setState(() => _isActive = value),
                          activeColor: const Color(0xFF7C3AED),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isActive
                              ? (lp.isEnglish ? 'Active' : 'فعال')
                              : (lp.isEnglish ? 'Inactive' : 'غیر فعال'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _isActive ? Colors.green.shade700 : Colors.grey.shade600,
                            fontFamily: lp.fontFamily,
                          ),
                        ),
                        const Spacer(),
                        if (_isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              lp.isEnglish ? 'Active' : 'فعال',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                                fontFamily: lp.fontFamily,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              lp.isEnglish ? 'Inactive' : 'غیر فعال',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                                fontFamily: lp.fontFamily,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          lp.isEnglish ? 'Please wait...' : 'براہ کرم انتظار کریں...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: lp.fontFamily,
                          ),
                        ),
                      ],
                    )
                        : Text(
                      widget.supplier == null
                          ? (lp.isEnglish ? 'Create Supplier' : 'سپلائر بنائیں')
                          : (lp.isEnglish ? 'Update Supplier' : 'سپلائر اپ ڈیٹ کریں'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: lp.fontFamily,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Cancel button for web
                if (isWeb)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}