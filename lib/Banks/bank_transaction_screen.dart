// lib/screens/banks/bank_transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/bank_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/bank.dart';
import '../../models/bank_transaction.dart';

class BankTransactionScreen extends StatefulWidget {
  final Bank bank;
  const BankTransactionScreen({super.key, required this.bank});

  @override
  State<BankTransactionScreen> createState() => _BankTransactionScreenState();
}

class _BankTransactionScreenState extends State<BankTransactionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  final ScrollController _historyScrollController = ScrollController();

  String _transactionType = 'in';
  bool _isLoading = false;
  late TabController _tabController;

  final _currencyFormat = NumberFormat('#,##0.00');
  final _dateTimeFormat = DateFormat('dd/MM/yy\nhh:mm a');

  // Transfer related
  int? _selectedTransferBankId;
  bool _isTransferMode = false;
  List<Bank> _otherBanks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bankProvider = Provider.of<BankProvider>(context, listen: false);

    await bankProvider.fetchTransactions(widget.bank.id, authProvider: authProvider);

    // Load other banks for transfer
    await bankProvider.fetchBanks(authProvider: authProvider);
    setState(() {
      _otherBanks = bankProvider.banks
          .where((b) => b.id != widget.bank.id)
          .toList();
    });

    // Scroll to bottom (newest) after data loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_historyScrollController.hasClients) {
        _historyScrollController.animateTo(
          _historyScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF7C3AED),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF7C3AED),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year, date.month, date.day,
        time.hour, time.minute,
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: _buildAppBar(),
      body: Consumer<BankProvider>(
        builder: (context, provider, _) {
          final transactions = provider.transactions
              .where((t) => t.bankId == widget.bank.id)
              .toList();
          final currentBalance = provider.getBankBalanceById(widget.bank.id);

          return TabBarView(
            controller: _tabController,
            children: [
              // ── Tab 1: Record ──
              SingleChildScrollView(
                child: Column(
                  children: [
                    _buildBalanceCard(currentBalance),
                    _buildTransactionForm(),
                    _buildDateTimePicker(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              // ── Tab 2: History ──
              _buildHistoryTab(transactions),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1C1C1E)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                widget.bank.iconPath,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.account_balance,
                  size: 20,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.bank.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const Text(
                  'Bank Transactions',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF7C3AED),
        unselectedLabelColor: const Color(0xFF8E8E93),
        indicatorColor: const Color(0xFF7C3AED),
        tabs: const [
          Tab(text: 'RECORD', icon: Icon(Icons.add_circle_outline, size: 18)),
          Tab(text: 'HISTORY', icon: Icon(Icons.history, size: 18)),
        ],
      ),
    );
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text.trim());
    final description = _descCtrl.text.trim();
    final reference = _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim();

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<BankProvider>(context, listen: false);

    bool success = false;
    String message = '';

    if (_isTransferMode && _selectedTransferBankId != null) {
      // Handle bank transfer
      success = await provider.transferBetweenBanks(
        fromBankId: widget.bank.id,
        toBankId: _selectedTransferBankId!,
        amount: amount,
        description: description,
        referenceNumber: reference,
        authProvider: authProvider,
      );
      message = success
          ? 'Transferred Rs ${_currencyFormat.format(amount)} to ${_otherBanks.firstWhere((b) => b.id == _selectedTransferBankId).name}'
          : 'Transfer failed!';
    } else {
      // Handle regular transaction
      success = await provider.addTransaction(
        bankId: widget.bank.id,
        type: _transactionType,
        amount: amount,
        description: description,
        referenceNumber: reference,
        transactionDate: _selectedDateTime,
        authProvider: authProvider,
      );
      message = success
          ? '${_transactionType == 'in' ? 'Added' : 'Withdrawn'} Rs ${_currencyFormat.format(amount)}'
          : 'Transaction failed!';
    }

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedDateTime = DateTime.now();
          _selectedTransferBankId = null;
          _isTransferMode = false;
        });
        _amountCtrl.clear();
        _descCtrl.clear();
        _refCtrl.clear();
        await _loadData();
        setState(() {});
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper to check if transaction is from customer payment
  bool _isCustomerPayment(String description) {
    final lowerDesc = description.toLowerCase();
    // Check for customer payment patterns
    return lowerDesc.contains('payment received from') ||
        lowerDesc.contains('customer payment') ||
        lowerDesc.contains('cheque #') && lowerDesc.contains('from') ||
        lowerDesc.contains('slip #') && lowerDesc.contains('received');
  }

  // Helper to check if transaction is from supplier payment
  bool _isSupplierPayment(String description) {
    final lowerDesc = description.toLowerCase();
    // Check for supplier payment patterns
    return lowerDesc.contains('payment to supplier') ||
        lowerDesc.contains('supplier payment') ||
        lowerDesc.contains('cheque #') && lowerDesc.contains('to');
  }

  // Helper to check if transaction is from transfer
  bool _isTransfer(String description) {
    return description.toLowerCase().contains('bank transfer');
  }

  // Helper to check if transaction is protected (cannot be deleted)
  bool _isProtectedTransaction(String description) {
    return _isSupplierPayment(description) ||
        _isCustomerPayment(description) ||
        _isTransfer(description);
  }

  Widget _buildBalanceCard(double balance) {
    final isPositive = balance > 0;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [const Color(0xFF10B981), const Color(0xFF34D399)]
              : [const Color(0xFFEF4444), const Color(0xFFF87171)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isPositive
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444))
                .withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('Current Balance',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Text(
                'Rs ${_currencyFormat.format(balance)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Mode selector: Normal vs Transfer
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isTransferMode = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_isTransferMode
                          ? const Color(0xFF7C3AED).withOpacity(0.1)
                          : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_isTransferMode
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFE5E5EA),
                        width: !_isTransferMode ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swap_horiz,
                            size: 18,
                            color: !_isTransferMode
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF8E8E93)),
                        const SizedBox(width: 6),
                        Text(
                          'Normal',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: !_isTransferMode
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF8E8E93),
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
                  onTap: () => setState(() => _isTransferMode = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _isTransferMode
                          ? const Color(0xFF7C3AED).withOpacity(0.1)
                          : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isTransferMode
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFE5E5EA),
                        width: _isTransferMode ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance,
                            size: 18,
                            color: _isTransferMode
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF8E8E93)),
                        const SizedBox(width: 6),
                        Text(
                          'Transfer',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _isTransferMode
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF8E8E93),
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

          // Transfer mode - show target bank selector
          if (_isTransferMode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedTransferBankId,
                  hint: const Text('Select target bank'),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7C3AED)),
                  items: _otherBanks.map((bank) {
                    return DropdownMenuItem<int>(
                      value: bank.id,
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.asset(
                                bank.iconPath,
                                width: 20,
                                height: 20,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.account_balance,
                                  size: 16,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(bank.name)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTransferBankId = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Normal mode - show in/out selector
          if (!_isTransferMode) ...[
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _transactionType = 'in'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _transactionType == 'in'
                            ? const Color(0xFF10B981).withOpacity(0.1)
                            : const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _transactionType == 'in'
                              ? const Color(0xFF10B981)
                              : const Color(0xFFE5E5EA),
                          width: _transactionType == 'in' ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_downward,
                              size: 18,
                              color: _transactionType == 'in'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF8E8E93)),
                          const SizedBox(width: 6),
                          Text(
                            'Add Money',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _transactionType == 'in'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF8E8E93),
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
                    onTap: () => setState(() => _transactionType = 'out'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _transactionType == 'out'
                            ? const Color(0xFFEF4444).withOpacity(0.1)
                            : const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _transactionType == 'out'
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFE5E5EA),
                          width: _transactionType == 'out' ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_upward,
                              size: 18,
                              color: _transactionType == 'out'
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF8E8E93)),
                          const SizedBox(width: 6),
                          Text(
                            'Withdraw',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _transactionType == 'out'
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF8E8E93),
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
          ],

          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.currency_exchange, size: 20),
                    hintText: _isTransferMode ? 'Enter amount to transfer' : 'Enter amount',
                    filled: true,
                    fillColor: const Color(0xFFF5F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF7C3AED), width: 1.5),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Amount required';
                    if ((double.tryParse(v) ?? 0) <= 0)
                      return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.description_outlined, size: 20),
                    hintText: _isTransferMode ? 'Transfer description' : 'Description',
                    filled: true,
                    fillColor: const Color(0xFFF5F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF7C3AED), width: 1.5),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Description required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _refCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.numbers_outlined, size: 20),
                    hintText: 'Reference Number (optional)',
                    filled: true,
                    fillColor: const Color(0xFFF5F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF7C3AED), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading || (_isTransferMode && _selectedTransferBankId == null)
                        ? null
                        : _submitTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTransferMode
                          ? const Color(0xFF7C3AED)
                          : (_transactionType == 'in'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                        : Text(
                      _isTransferMode
                          ? 'Transfer Money'
                          : (_transactionType == 'in' ? 'Add Money' : 'Withdraw Money'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return GestureDetector(
      onTap: _pickDateTime,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 20, color: Color(0xFF7C3AED)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaction Date & Time',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8E8E93),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM dd, yyyy  •  hh:mm a')
                        .format(_selectedDateTime),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedDateTime.difference(DateTime.now()).abs().inMinutes > 1)
              GestureDetector(
                onTap: () => setState(() => _selectedDateTime = DateTime.now()),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.refresh,
                      size: 16, color: Color(0xFF7C3AED)),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: Color(0xFF8E8E93)),
          ],
        ),
      ),
    );
  }

  // ── History Tab ───────────────────────────────────────────────────────────

  Widget _buildHistoryTab(List<BankTransaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No transactions yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('Switch to Record tab to add one',
                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      );
    }

    final sorted = [...transactions]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double runningBalance = 0;
    final List<_TxnRow> rows = [];
    for (final txn in sorted) {
      if (txn.type == 'in') {
        runningBalance += txn.amount;
      } else {
        runningBalance -= txn.amount;
      }
      rows.add(_TxnRow(txn: txn, runningBalance: runningBalance));
    }

    final displayRows = rows;

    final totalIn = sorted
        .where((t) => t.type == 'in')
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalOut = sorted
        .where((t) => t.type == 'out')
        .fold(0.0, (sum, t) => sum + t.amount);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _summaryChip(
                  label: 'Total In',
                  value: 'Rs ${_currencyFormat.format(totalIn)}',
                  color: const Color(0xFF10B981),
                  icon: Icons.arrow_downward,
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFE5E5EA)),
              Expanded(
                child: _summaryChip(
                  label: 'Total Out',
                  value: 'Rs ${_currencyFormat.format(totalOut)}',
                  color: const Color(0xFFEF4444),
                  icon: Icons.arrow_upward,
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFE5E5EA)),
              Expanded(
                child: _summaryChip(
                  label: 'Txns',
                  value: '${sorted.length}',
                  color: const Color(0xFF7C3AED),
                  icon: Icons.receipt_long,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width > 700
                      ? MediaQuery.of(context).size.width - 24
                      : 700,
                  child: Column(
                    children: [
                      _buildTableHeader(),
                      Expanded(
                        child: ListView.builder(
                          controller: _historyScrollController,
                          itemCount: displayRows.length,
                          itemBuilder: (context, index) {
                            return _buildTableRow(displayRows[index], index);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryChip({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF6B7280),
      letterSpacing: 0.5,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          _headerCell('DATE / TIME', flex: 18, style: headerStyle),
          _vDivider(),
          _headerCell('DESCRIPTION', flex: 28, style: headerStyle),
          _vDivider(),
          _headerCell('CASH IN', flex: 18, style: headerStyle, align: TextAlign.right),
          _vDivider(),
          _headerCell('CASH OUT', flex: 18, style: headerStyle, align: TextAlign.right),
          _vDivider(),
          _headerCell('BALANCE', flex: 18, style: headerStyle, align: TextAlign.right),
          _vDivider(),
          _headerCell('', flex: 9, style: headerStyle),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BankTransaction txn) async {
    // Check if transaction is protected (cannot be deleted)
    if (_isProtectedTransaction(txn.description)) {
      String type = '';
      if (_isSupplierPayment(txn.description)) {
        type = 'supplier payment';
      } else if (_isCustomerPayment(txn.description)) {
        type = 'customer payment';
      } else if (_isTransfer(txn.description)) {
        type = 'bank transfer';
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cannot Delete'),
          content: Text(
            'This transaction is from a $type. To reverse it, please use the original transaction source (Sale/Purchase screen).',
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Color(0xFF7C3AED))),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete this transaction and reverse its effect on the bank balance.',
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.description,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    '${txn.type == 'in' ? 'Cash In' : 'Cash Out'}: Rs ${_currencyFormat.format(txn.amount)}',
                    style: TextStyle(
                      color: txn.type == 'in'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(txn.timestamp),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bankProvider = Provider.of<BankProvider>(context, listen: false);

    final success = await bankProvider.deleteTransaction(
      widget.bank.id,
      txn.id,
      authProvider: authProvider,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Transaction deleted and balance updated'
              : bankProvider.error ?? 'Failed to delete'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) await _loadData();
    }
  }

  Widget _buildTableRow(_TxnRow row, int index) {
    final txn = row.txn;
    final isIn = txn.type == 'in';
    final isEven = index % 2 == 0;
    final isTransfer = _isTransfer(txn.description);
    final isSupplierPayment = _isSupplierPayment(txn.description);
    final isCustomerPayment = _isCustomerPayment(txn.description);

    // Hide delete button for supplier payments AND customer payments
    final isProtected = isTransfer || isSupplierPayment || isCustomerPayment;

    String? getTransactionTag() {  // ✅ Changed return type to String?
      if (isTransfer) return 'TRF';
      if (isSupplierPayment) return 'SUPPLIER';
      if (isCustomerPayment) return 'CUSTOMER';
      return null;
    }

    final tag = getTransactionTag();

    Color getTagColor() {
      if (isTransfer) return const Color(0xFF7C3AED);
      if (isSupplierPayment) return const Color(0xFFF59E0B);
      if (isCustomerPayment) return const Color(0xFF10B981);
      return const Color(0xFF7C3AED);
    }

    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFFAFAFC),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.8),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _dataCell(
            flex: 17,
            child: Text(
              _dateTimeFormat.format(txn.timestamp),
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
          _vDivider(),
          _dataCell(
            flex: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        txn.description,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isProtected ? getTagColor() : const Color(0xFF1C1C1E),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tag != null)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: getTagColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: getTagColor(),
                          ),
                        ),
                      ),
                  ],
                ),
                if (txn.referenceNumber != null) ...[
                  const SizedBox(height: 2),
                  Text('Ref: ${txn.referenceNumber}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF7C3AED))),
                ],
              ],
            ),
          ),
          _vDivider(),
          _dataCell(
            flex: 16,
            child: isIn
                ? Text(_currencyFormat.format(txn.amount),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                textAlign: TextAlign.right)
                : const Text('—', style: TextStyle(color: Color(0xFFD1D5DB)), textAlign: TextAlign.right),
            align: CrossAxisAlignment.end,
          ),
          _vDivider(),
          _dataCell(
            flex: 16,
            child: !isIn
                ? Text(_currencyFormat.format(txn.amount),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                textAlign: TextAlign.right)
                : const Text('—', style: TextStyle(color: Color(0xFFD1D5DB)), textAlign: TextAlign.right),
            align: CrossAxisAlignment.end,
          ),
          _vDivider(),
          _dataCell(
            flex: 16,
            child: Text(
              _currencyFormat.format(row.runningBalance),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: row.runningBalance >= 0
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFEF4444),
              ),
              textAlign: TextAlign.right,
            ),
            align: CrossAxisAlignment.end,
          ),
          _vDivider(),
          Expanded(
            flex: 9,
            child: Center(
              child: isProtected
                  ? const SizedBox.shrink()
                  : GestureDetector(
                onTap: () => _confirmDelete(txn),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: Color(0xFFEF4444)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(
      String text, {
        required int flex,
        TextStyle? style,
        TextAlign align = TextAlign.center,
      }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Text(text, style: style, textAlign: align),
      ),
    );
  }

  Widget _dataCell({
    required int flex,
    required Widget child,
    CrossAxisAlignment align = CrossAxisAlignment.start,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Align(
          alignment: align == CrossAxisAlignment.end
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 0.8,
    height: 48,
    color: const Color(0xFFE5E7EB),
  );
}


class _TxnRow {
  final BankTransaction txn;
  final double runningBalance;
  const _TxnRow({required this.txn, required this.runningBalance});
}