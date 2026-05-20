import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/confirmation_dialog.dart';
import '../components/customer_form_dialog.dart';
import '../components/customer_list_item.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';
import '../components/custom_button.dart';
import 'customer_adjustment_dialog.dart';
import 'customer_balance_report_screen.dart';
import 'customer_invoice_payment_screen.dart';
import 'customer_ledger_screen.dart';
import 'customer_payments_screen.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({Key? key}) : super(key: key);

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showActiveOnly = false;
  String _currentSearch = '';
  String _selectedType = 'all';
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeData();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (_hasInitialized) return;

    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    _hasInitialized = true;
    await customerProvider.fetchCustomers();
    await customerProvider.fetchActiveCustomers();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreCustomers();
    }
  }

  Future<void> _loadMoreCustomers() async {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

    if (customerProvider.hasMorePages && !customerProvider.isLoading) {
      await customerProvider.fetchCustomers(
        page: customerProvider.currentPage + 1,
        search: _currentSearch,
        active: _showActiveOnly ? true : null,
        customerType: _selectedType != 'all' ? _selectedType : null,
      );
    }
  }

  Future<void> _refreshCustomers() async {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    await customerProvider.fetchCustomers(
      search: _currentSearch,
      active: _showActiveOnly ? true : null,
      customerType: _selectedType != 'all' ? _selectedType : null,
    );
  }

  void _handleSearch(String value) {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

    if (value != _currentSearch) {
      _currentSearch = value;
      customerProvider.clearCustomers();
      customerProvider.fetchCustomers(
        search: value,
        active: _showActiveOnly ? true : null,
        customerType: _selectedType != 'all' ? _selectedType : null,
      );
    }
  }

  void _toggleActiveFilter() {
    setState(() {
      _showActiveOnly = !_showActiveOnly;
    });

    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    customerProvider.clearCustomers();
    customerProvider.fetchCustomers(
      search: _currentSearch,
      active: _showActiveOnly ? true : null,
      customerType: _selectedType != 'all' ? _selectedType : null,
    );
  }

  void _handleTypeFilter(String type) {
    setState(() {
      _selectedType = type;
    });

    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    customerProvider.clearCustomers();
    customerProvider.fetchCustomers(
      search: _currentSearch,
      active: _showActiveOnly ? true : null,
      customerType: type != 'all' ? type : null,
    );
  }

  void _navigateToReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomerBalanceReportScreen(),
      ),
    ).then((_) {
      // Refresh data when returning from reports
      _refreshCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerProvider>(
      builder: (context, customerProvider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          body: Column(
            children: [
              // Header Section
              _buildHeader(customerProvider),

              // Search and Filter Section
              _buildSearchFilterSection(),

              // Type Filter Chips
              _buildTypeFilter(),

              // Main Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshCustomers,
                  child: _buildCustomerList(customerProvider),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddCustomerDialog(),
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add),
            label: const Text('Add Customer'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(CustomerProvider customerProvider) {
    final activeCustomers =
        customerProvider.customers.where((c) => c.isActive).length;

    final customersWithBalance =
        customerProvider.customers.where((c) => c.balance > 0).length;

    final totalBalance = customerProvider.totalOutstandingBalance;

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF0F0F5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your customer relationships and balances',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              CustomButton(
                text: 'Reports',
                icon: Icons.assessment,
                onPressed: _navigateToReports, // Updated to navigate
                width: 120,
                height: 48,
                backgroundColor: Colors.white,
                textColor: const Color(0xFF7C3AED),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatCard(
                'Total Customers',
                customerProvider.totalItems.toString(),
                Icons.people,
                const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'Active',
                activeCustomers.toString(),
                Icons.check_circle,
                const Color(0xFF10B981),
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'With Balance',
                customersWithBalance.toString(),
                Icons.account_balance_wallet,
                Colors.orange,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'Total Owed',
                '${totalBalance.toStringAsFixed(2)}',
                Icons.money,
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F5), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => _handleSearch(value),
                decoration: InputDecoration(
                  hintText: 'Search customers by name, contact, email or address...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                  suffixIcon: _currentSearch.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _handleSearch('');
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          FilterChip(
            label: Text(
              'Active Only',
              style: TextStyle(
                color: _showActiveOnly ? Colors.white : const Color(0xFF7C3AED),
              ),
            ),
            selected: _showActiveOnly,
            onSelected: (_) => _toggleActiveFilter(),
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFF7C3AED),
            side: BorderSide(color: const Color(0xFF7C3AED)),
            checkmarkColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text('All'),
              selected: _selectedType == 'all',
              onSelected: (_) => _handleTypeFilter('all'),
              backgroundColor: _selectedType == 'all'
                  ? const Color(0xFF7C3AED)
                  : Colors.grey[100],
              selectedColor: const Color(0xFF7C3AED),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: _selectedType == 'all' ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Regular'),
              selected: _selectedType == 'regular',
              onSelected: (_) => _handleTypeFilter('regular'),
              backgroundColor: _selectedType == 'regular'
                  ? Colors.blue
                  : Colors.grey[100],
              selectedColor: Colors.blue,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: _selectedType == 'regular' ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Retail'),
              selected: _selectedType == 'retail',
              onSelected: (_) => _handleTypeFilter('retail'),
              backgroundColor: _selectedType == 'retail'
                  ? Colors.green
                  : Colors.grey[100],
              selectedColor: Colors.green,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: _selectedType == 'retail' ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Wholesale'),
              selected: _selectedType == 'wholesale',
              onSelected: (_) => _handleTypeFilter('wholesale'),
              backgroundColor: _selectedType == 'wholesale'
                  ? Colors.orange
                  : Colors.grey[100],
              selectedColor: Colors.orange,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: _selectedType == 'wholesale' ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerList(CustomerProvider customerProvider) {
    if (customerProvider.isLoading && customerProvider.customers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (customerProvider.customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 20),
            Text(
              _currentSearch.isEmpty
                  ? 'No customers found'
                  : 'No customers match your search',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentSearch.isEmpty
                  ? 'Add your first customer to get started'
                  : 'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 20),
            if (_currentSearch.isEmpty)
              CustomButton(
                text: 'Add Customer',
                icon: Icons.person_add,
                onPressed: () => _showAddCustomerDialog(),
                width: 160,
                height: 48,
                useGradient: true,
                gradientColors: const [Color(0xFF7C3AED), Color(0xFF6366F1)],
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      itemCount: customerProvider.customers.length + 1,
      itemBuilder: (context, index) {
        if (index < customerProvider.customers.length) {
          final customer = customerProvider.customers[index];
          return CustomerListItem(
            customer: customer,
            onTap: () => _showCustomerDetails(customer),
            onEdit: () => _showEditCustomerDialog(customer),
            onToggleStatus: () => _toggleCustomerStatus(customer),
            onDelete: () => _deleteCustomer(customer),
          );
        } else {
          return customerProvider.isLoading
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
              : customerProvider.hasMorePages
              ? const SizedBox(height: 20)
              : Container();
        }
      },
    );
  }

  Future<void> _showAddCustomerDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CustomerFormDialog(),
    );

    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showEditCustomerDialog(Customer customer) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CustomerFormDialog(customer: customer),
    );

    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showCustomerDetails(Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => CustomerDetailsSheet(
        customer: customer,
        onEdit: () {
          Navigator.pop(context);
          _showEditCustomerDialog(customer);
        },
        onToggleStatus: () {
          Navigator.pop(context);
          _toggleCustomerStatus(customer);
        },
        onViewLedger: () {
          Navigator.pop(context);
          _viewCustomerLedger(customer);
        },
        onViewPayments: () {
          Navigator.pop(context);
          _viewCustomerPayments(customer);
        },
        onReceivePayment: () {
          Navigator.pop(context);
          _receiveCustomerPayment(customer);
        },
        onAdjustBalance: () {
          Navigator.pop(context);
          _adjustCustomerBalance(customer);
        },
      ),
    );
  }

  void _viewCustomerLedger(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerLedgerScreen(customer: customer),
      ),
    );
  }

  void _viewCustomerPayments(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerPaymentsScreen(customer: customer),
      ),
    );
  }

  Future<void> _receiveCustomerPayment(Customer customer) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerInvoicePaymentScreen(customer: customer),
      ),
    );

    if (result == true) {
      _refreshCustomers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment recorded successfully'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _adjustCustomerBalance(Customer customer) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CustomerAdjustmentDialog(customer: customer),
    );

    if (result == true) {
      _refreshCustomers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Balance adjusted successfully'),
          backgroundColor: Color(0xFF7C3AED),
        ),
      );
    }
  }

  Future<void> _toggleCustomerStatus(Customer customer) async {
    final confirm = await showConfirmationDialog(
      context,
      title: customer.isActive ? 'Deactivate Customer' : 'Activate Customer',
      message: customer.isActive
          ? 'Are you sure you want to deactivate ${customer.name}?'
          : 'Are you sure you want to activate ${customer.name}?',
      confirmText: customer.isActive ? 'Deactivate' : 'Activate',
      confirmColor: customer.isActive ? Colors.red : Colors.green,
    );

    if (confirm == true) {
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
      final result = await customerProvider.toggleCustomerStatus(customer.id);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
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

  Future<void> _deleteCustomer(Customer customer) async {
    final confirm = await showConfirmationDialog(
      context,
      title: 'Delete Customer',
      message: 'Are you sure you want to delete ${customer.name}? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (confirm == true) {
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
      final result = await customerProvider.deleteCustomer(customer.id);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
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
}

class CustomerDetailsSheet extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onViewLedger;
  final VoidCallback onViewPayments;
  final VoidCallback onReceivePayment;
  final VoidCallback onAdjustBalance;

  const CustomerDetailsSheet({
    Key? key,
    required this.customer,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onViewLedger,
    required this.onViewPayments,
    required this.onReceivePayment,
    required this.onAdjustBalance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isOutstanding = customer.balance > 0.01;
    final hasDiscount = customer.discountPercent > 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF7C3AED),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Customer Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Customer name and balance highlight
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C3AED).withOpacity(0.1),
                  const Color(0xFF6366F1).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.contact,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isOutstanding ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOutstanding ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isOutstanding ? 'OWING' : 'CLEAR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isOutstanding ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        customer.formattedBalance,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isOutstanding ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Details grid
          _buildDetailItem('Contact', customer.contact, Icons.phone),
          if (customer.email != null && customer.email!.isNotEmpty)
            _buildDetailItem('Email', customer.email!, Icons.email),
          if (customer.address != null && customer.address!.isNotEmpty)
            _buildDetailItem('Address', customer.address!, Icons.location_on),

          // Add Discount display here - show only if discount > 0
          if (hasDiscount)
            _buildDetailItem(
              'Default Discount',
              '${customer.discountPercent.toStringAsFixed(1)}%',
              Icons.local_offer,
              color: const Color(0xFF7C3AED),
            ),

          _buildDetailItem('Type', customer.typeLabel, Icons.category,
              color: _getTypeColor(customer.customerType)),
          _buildDetailItem('Status', customer.isActive ? 'Active' : 'Inactive',
              customer.isActive ? Icons.check_circle : Icons.cancel,
              color: customer.isActive ? Colors.green : Colors.red),
          _buildDetailItem('Created',
              '${customer.createdAt.day}/${customer.createdAt.month}/${customer.createdAt.year}',
              Icons.calendar_today),

          const SizedBox(height: 24),

          // Action buttons in two rows
          // First row - Quick Actions
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.receipt_long,
                  label: 'Ledger',
                  color: const Color(0xFF7C3AED),
                  onTap: onViewLedger,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.history,
                  label: 'Payments',
                  color: const Color(0xFF3B82F6),
                  onTap: onViewPayments,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Second row - Payment Actions
          if (isOutstanding)
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.payments,
                    label: 'Receive Payment',
                    color: const Color(0xFF10B981),
                    onTap: onReceivePayment,
                    isPrimary: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.swap_horiz,
                    label: 'Adjust',
                    color: Colors.orange,
                    onTap: onAdjustBalance,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit,
                    label: 'Edit',
                    color: const Color(0xFF7C3AED),
                    onTap: onEdit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionButton(
                    icon: customer.isActive ? Icons.pause : Icons.play_arrow,
                    label: customer.isActive ? 'Deactivate' : 'Activate',
                    color: customer.isActive ? Colors.red : Colors.green,
                    onTap: onToggleStatus,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'wholesale':
        return Colors.orange;
      case 'retail':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Widget _buildDetailItem(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color ?? const Color(0xFF6B7280), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color ?? const Color(0xFF2D3142),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isPrimary ? null : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? Colors.transparent : color.withOpacity(0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isPrimary ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}