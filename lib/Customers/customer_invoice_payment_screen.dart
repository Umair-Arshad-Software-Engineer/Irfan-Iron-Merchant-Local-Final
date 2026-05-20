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

class CustomerInvoicePaymentScreen extends StatefulWidget {
  final Customer customer;

  const CustomerInvoicePaymentScreen({
    Key? key,
    required this.customer,
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
  String _selectedType = 'all'; // 'all', 'invoice', 'pos'

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs ');

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
        _error = 'Failed to load sales: $e';
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

  // Helper to get bank ID by name
  int? _getBankIdByName(String? bankName) {
    if (bankName == null) return null;
    final index = pakistaniBanks.indexWhere((bank) => bank.name == bankName);
    return index >= 0 ? index + 1 : null;
  }

  Future<void> _recordPayment() async {
    if (_selectedSaleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one sale'), backgroundColor: Colors.red),
      );
      return;
    }

    final selectedSales = _sales.where((sale) => _selectedSaleIds.contains(sale.id)).toList();
    final totalOutstanding = selectedSales.fold<double>(0, (sum, sale) => sum + sale.outstandingBalance);

    final amountController = TextEditingController(text: totalOutstanding.toStringAsFixed(2));
    String selectedMethod = 'cash';

    // Bank fields (only destination bank where we receive money)
    Bank? selectedBank;

    // Cheque fields
    final chequeNumberCtrl = TextEditingController();
    DateTime? chequeDate;
    Bank? selectedChequeBank;

    // Slip fields
    final slipNumberCtrl = TextEditingController();
    DateTime? slipDate;
    Bank? selectedSlipBank;

    DateTime? paymentDate = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Record Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selected sales summary
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
                          Text('${selectedSales.length} Sale(s) Selected', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          const Text('Total Outstanding', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(_currencyFormat.format(totalOutstanding), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Amount
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Payment Amount',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Date
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
                        Text('Payment Date: ${DateFormat('MMM dd, yyyy').format(paymentDate!)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Method Selector
                const Text('Payment Method', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),

                // Method chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMethodChip(label: 'Cash', icon: Icons.payments_outlined, color: const Color(0xFF10B981), isSelected: selectedMethod == 'cash', onTap: () => setState(() => selectedMethod = 'cash')),
                      const SizedBox(width: 8),
                      _buildMethodChip(label: 'Bank', icon: Icons.account_balance_outlined, color: const Color(0xFF3B82F6), isSelected: selectedMethod == 'bank', onTap: () => setState(() => selectedMethod = 'bank')),
                      const SizedBox(width: 8),
                      _buildMethodChip(label: 'Cheque', icon: Icons.receipt_long_outlined, color: const Color(0xFFF59E0B), isSelected: selectedMethod == 'cheque', onTap: () => setState(() => selectedMethod = 'cheque')),
                      const SizedBox(width: 8),
                      _buildMethodChip(label: 'Slip', icon: Icons.receipt_outlined, color: const Color(0xFF8B5CF6), isSelected: selectedMethod == 'slip', onTap: () => setState(() => selectedMethod = 'slip')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Method-specific fields
                if (selectedMethod == 'bank') ...[
                  _buildBankSelector(
                    label: 'Bank (Receiving) *',
                    selectedBank: selectedBank,
                    onTap: () => _openBankPicker(
                      context: context,
                      title: 'Select Bank',
                      onSelected: (bank, index) => setState(() => selectedBank = bank),
                      currentSelection: selectedBank,
                    ),
                  ),
                ] else if (selectedMethod == 'cheque') ...[
                  _buildBankSelector(
                    label: 'Bank *',
                    selectedBank: selectedChequeBank,
                    onTap: () => _openBankPicker(
                      context: context,
                      title: 'Select Bank',
                      onSelected: (bank, index) => setState(() => selectedChequeBank = bank),
                      currentSelection: selectedChequeBank,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: chequeNumberCtrl,
                    decoration: InputDecoration(
                      labelText: 'Cheque Number *',
                      hintText: 'e.g. 001234',
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
                          Text(chequeDate != null ? 'Cheque Date: ${DateFormat('MMM dd, yyyy').format(chequeDate!)}' : 'Select Cheque Date *'),
                        ],
                      ),
                    ),
                  ),
                ] else if (selectedMethod == 'slip') ...[
                  _buildBankSelector(
                    label: 'Bank *',
                    selectedBank: selectedSlipBank,
                    onTap: () => _openBankPicker(
                      context: context,
                      title: 'Select Bank',
                      onSelected: (bank, index) => setState(() => selectedSlipBank = bank),
                      currentSelection: selectedSlipBank,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: slipNumberCtrl,
                    decoration: InputDecoration(
                      labelText: 'Slip Number *',
                      hintText: 'e.g. SLIP-001',
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
                          Text(slipDate != null ? 'Slip Date: ${DateFormat('MMM dd, yyyy').format(slipDate!)}' : 'Select Slip Date *'),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid amount'), backgroundColor: Colors.red));
                  return;
                }
                if (amount > totalOutstanding) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount cannot exceed total outstanding'), backgroundColor: Colors.red));
                  return;
                }

                // Validate method-specific fields
                if (selectedMethod == 'bank') {
                  if (selectedBank == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a bank'), backgroundColor: Colors.red));
                    return;
                  }
                } else if (selectedMethod == 'cheque') {
                  if (selectedChequeBank == null || chequeNumberCtrl.text.isEmpty || chequeDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all cheque details'), backgroundColor: Colors.red));
                    return;
                  }
                } else if (selectedMethod == 'slip') {
                  if (selectedSlipBank == null || slipNumberCtrl.text.isEmpty || slipDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all slip details'), backgroundColor: Colors.red));
                    return;
                  }
                }

                // Build payment details
                Map<String, dynamic> paymentDetails = {
                  'amount': amount,
                  'method': selectedMethod,
                  'payment_date': paymentDate!.toIso8601String(),
                  'sale_ids': _selectedSaleIds.toList(),
                };

                // Add method-specific details with bank_id
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Record Payment'),
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

      // Prepare additional parameters
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
          chequeDate: chequeDate,
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
          SnackBar(content: Text(successMessage ?? 'Payment recorded successfully'), backgroundColor: Colors.green, duration: const Duration(seconds: 4)),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to record payment for some sales'), backgroundColor: Colors.red),
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
            Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? color : Colors.grey.shade700)),
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
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93))),
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
                  Expanded(child: Text(selectedBank.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                  Icon(Icons.check_circle_rounded, color: Colors.blue, size: 18),
                ] else ...[
                  Icon(Icons.account_balance_outlined, size: 20, color: Colors.grey[400]),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Select bank', style: TextStyle(fontSize: 14, color: Color(0xFFC7C7CC)))),
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
  }) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PaymentBankSheet(title: title, selected: currentSelection, accentColor: const Color(0xFF7C3AED)),
    );
    if (result != null) {
      onSelected(result['bank'] as Bank, result['index'] as int);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)), onPressed: () => Navigator.pop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Receive Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
            Text(widget.customer.name, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        actions: [
          if (_selectedSaleIds.isNotEmpty)
            TextButton.icon(
              onPressed: _recordPayment,
              icon: const Icon(Icons.payment, color: Colors.green),
              label: Text('Receive ${_currencyFormat.format(_selectedTotalAmount)}', style: const TextStyle(color: Colors.green)),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _error != null
          ? CustomErrorWidget(message: _error!, onRetry: _loadCustomerSales)
          : _sales.isEmpty
          ? _buildEmptyState()
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedType == 'all',
                  onSelected: (_) => setState(() {
                    _selectedType = 'all';
                    _selectedSaleIds.clear();
                    _selectAll = false;
                  }),
                  backgroundColor: _selectedType == 'all' ? const Color(0xFF7C3AED) : Colors.grey[100],
                  selectedColor: const Color(0xFF7C3AED),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(color: _selectedType == 'all' ? Colors.white : Colors.grey[700]),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Invoices'),
                  selected: _selectedType == 'invoice',
                  onSelected: (_) => setState(() {
                    _selectedType = 'invoice';
                    _selectedSaleIds.clear();
                    _selectAll = false;
                  }),
                  backgroundColor: _selectedType == 'invoice' ? Colors.blue : Colors.grey[100],
                  selectedColor: Colors.blue,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(color: _selectedType == 'invoice' ? Colors.white : Colors.grey[700]),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('POS Sales'),
                  selected: _selectedType == 'pos',
                  onSelected: (_) => setState(() {
                    _selectedType = 'pos';
                    _selectedSaleIds.clear();
                    _selectAll = false;
                  }),
                  backgroundColor: _selectedType == 'pos' ? const Color(0xFF7C3AED) : Colors.grey[100],
                  selectedColor: const Color(0xFF7C3AED),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(color: _selectedType == 'pos' ? Colors.white : Colors.grey[700]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Checkbox(value: _selectAll, onChanged: _filteredSales.isNotEmpty ? _toggleSelectAll : null, activeColor: const Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                const Text('Select All', style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('Total: ${_currencyFormat.format(_selectedTotalAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
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
                    border: Border.all(color: isSelected ? const Color(0xFF7C3AED) : isOverdue ? Colors.red.withOpacity(0.3) : const Color(0xFFF0F0F5), width: isSelected ? 2 : 1),
                  ),
                  child: InkWell(
                    onTap: () => _toggleSaleSelection(sale.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Checkbox(value: isSelected, onChanged: (_) => _toggleSaleSelection(sale.id), activeColor: const Color(0xFF7C3AED)),
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
                                      child: Text(isPos ? 'POS' : 'INVOICE', style: TextStyle(fontSize: 10, color: isPos ? const Color(0xFF7C3AED) : Colors.blue, fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(sale.invoiceNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                                    const SizedBox(width: 8),
                                    if (isOverdue)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('OVERDUE', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 12, color: Colors.grey[400]),
                                    const SizedBox(width: 4),
                                    Text(_dateFormat.format(sale.saleDate), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    if (sale.dueDate != null) ...[
                                      const SizedBox(width: 12),
                                      Icon(Icons.event, size: 12, color: Colors.grey[400]),
                                      const SizedBox(width: 4),
                                      Text(_dateFormat.format(sale.dueDate!), style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red : Colors.grey[600])),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total: ${_currencyFormat.format(sale.grandTotal)}', style: const TextStyle(fontSize: 13)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                      child: Text('Due: ${_currencyFormat.format(sale.outstandingBalance)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                    ),
                                  ],
                                ),
                                if (sale.paymentStatus == 'partial')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: LinearProgressIndicator(value: sale.amountPaid / sale.grandTotal, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED))),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No Unpaid Sales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('${widget.customer.name} has no outstanding invoices or POS sales', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

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
      _filteredBanks = pakistaniBanks.where((bank) => bank.name.toLowerCase().contains(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
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
            decoration: InputDecoration(
              hintText: 'Search banks...',
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
                        decoration: BoxDecoration(color: widget.accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.account_balance, color: widget.accentColor, size: 20),
                      ),
                    ),
                  ),
                  title: Text(
                    bank.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? widget.accentColor : null,
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