// lib/components/customer_form_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';

class CustomerFormDialog extends StatefulWidget {
  final Customer? customer;

  const CustomerFormDialog({Key? key, this.customer}) : super(key: key);

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
      // Pre-fill discount – omit trailing ".0" for cleanliness
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
    return AlertDialog(
      title: Text(
        widget.customer == null ? 'Add New Customer' : 'Edit Customer',
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
              // ── Name ─────────────────────────────────
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter customer name';
                  if (value.length < 2) return 'Name must be at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Contact ───────────────────────────────
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter contact number';
                  if (value.length < 10) return 'Enter a valid contact number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Email ─────────────────────────────────
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final emailRegex = RegExp(
                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Address ───────────────────────────────
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // ── Customer Type ─────────────────────────
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Customer Type',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'regular',
                    child: Row(children: [
                      const Icon(Icons.person, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('Regular Customer'),
                    ]),
                  ),
                  DropdownMenuItem(
                    value: 'retail',
                    child: Row(children: [
                      const Icon(Icons.shopping_cart, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('Retail Customer'),
                    ]),
                  ),
                  DropdownMenuItem(
                    value: 'wholesale',
                    child: Row(children: [
                      const Icon(Icons.business, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('Wholesale Customer'),
                    ]),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 16),

              // ── Discount Percent ──────────────────────
              TextFormField(
                controller: _discountController,
                decoration: InputDecoration(
                  labelText: 'Default Discount (%)',
                  hintText: 'e.g. 10  →  10% off every sale',
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                  suffixText: '%',
                  border: const OutlineInputBorder(),
                  // Subtle green tint when a discount is entered
                  fillColor: _discountController.text.isNotEmpty &&
                      (double.tryParse(_discountController.text) ?? 0) > 0
                      ? Colors.green.withOpacity(0.05)
                      : null,
                  filled: _discountController.text.isNotEmpty &&
                      (double.tryParse(_discountController.text) ?? 0) > 0,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}), // rebuild to update fill color
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final parsed = double.tryParse(value);
                    if (parsed == null) return 'Enter a valid number';
                    if (parsed < 0)   return 'Discount cannot be negative';
                    if (parsed > 100) return 'Discount cannot exceed 100%';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'This discount auto-applies when creating a sale for this customer.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),

              // ── Balance (edit mode only) ───────────────
              if (widget.customer != null) ...[
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _balance.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Balance',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                    border: OutlineInputBorder(),
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
          ),
          child: Text(widget.customer == null ? 'Add Customer' : 'Update'),
        ),
      ],
    );
  }
}